//
//  CalendarEventManager.swift
//  InOfficeDaysTracker
//
//  Manages calendar event creation and updates based on office visits
//

import Foundation
import EventKit
import CoreLocation

@MainActor
class CalendarEventManager: ObservableObject {
    private let calendarService = CalendarService.shared
    private let userDefaults = UserDefaults.standard
    private let lastSyncKey = "LastCalendarSync"
    
    // Background processing
    private var remoteWorkTimer: Timer?
    
    init() {
        setupDailyRemoteWorkCheck()
    }
    
    // MARK: - Office Visit Event Management
    
    func handleVisitStart(_ visit: OfficeVisit, settings: AppSettings) async {
        print("🔍 [CalendarEventManager] handleVisitStart called")
        print("  - Calendar enabled: \(settings.calendarSettings.isEnabled)")
        print("  - Selected calendar ID: \(settings.calendarSettings.selectedCalendarId ?? "none")")
        print("  - Visit active: \(visit.isActiveSession)")
        print("  - Visit date: \(visit.date)")
        
        guard settings.calendarSettings.isEnabled else {
            print("  ❌ Calendar integration disabled - no event will be created")
            return
        }
        
        let selectedCalendar = await getSelectedCalendar(settings: settings)
        guard let calendar = selectedCalendar else {
            print("  ❌ No calendar found - no event will be created")
            return
        }
        
        print("  ✅ All guards passed - proceeding with event creation")
        
        // Run duplicate cleanup to prevent issues
        await calendarService.cleanupDuplicateEvents(calendar: calendar)
        
        // Create tentative office event
        let eventData = createOfficeEventData(
            visit: visit,
            settings: settings,
            isOngoing: true
        )
        
        print("  📅 Event data created: \(eventData.title) - \(eventData.uid)")
        
        let update = CalendarEventUpdate(
            uid: eventData.uid,
            type: .office,
            operation: .create,
            date: visit.date,
            data: eventData
        )
        
        print("  📤 Scheduling calendar update with immediate processing for location triggers")

        calendarService.scheduleEventUpdate(
            update,
            batchMode: .immediate  // Force immediate for location-triggered events
        )        print("  ✅ Calendar update scheduled successfully")
    }
    
    func handleVisitUpdate(_ visit: OfficeVisit, settings: AppSettings) async {
        print("🔍 [CalendarEventManager] handleVisitUpdate called")
        print("  - Calendar enabled: \(settings.calendarSettings.isEnabled)")
        print("  - Visit active: \(visit.isActiveSession)")
        
        guard settings.calendarSettings.isEnabled,
              visit.isActiveSession else {
            print("  ❌ Calendar integration disabled or visit not active - no event will be updated")
            return
        }
        
        let eventData = createOfficeEventData(
            visit: visit,
            settings: settings,
            isOngoing: true
        )
        
        print("  📅 Event UID: \(eventData.uid)")
        
        // Check if event exists before trying to update
        let eventExists = await calendarService.eventExists(uid: eventData.uid)
        let operation: CalendarEventUpdate.Operation = eventExists ? .update : .create
        
        print("  📋 Event exists: \(eventExists) - Operation: \(operation)")
        
        let update = CalendarEventUpdate(
            uid: eventData.uid,
            type: .office,
            operation: operation,
            date: visit.date,
            data: eventData
        )
        
        print("  📤 Scheduling calendar \(operation) with immediate processing")
        
        calendarService.scheduleEventUpdate(
            update,
            batchMode: .immediate  // Force immediate update for visit updates
        )
        
        print("  ✅ Calendar \(operation) scheduled successfully")
    }
    
    func handleVisitEnd(_ visit: OfficeVisit, settings: AppSettings) async {
        print("🔍 [CalendarEventManager] handleVisitEnd called")
        print("  - Calendar enabled: \(settings.calendarSettings.isEnabled)")
        print("  - Visit valid: \(visit.isValidVisit)")
        
        guard settings.calendarSettings.isEnabled else {
            print("  ❌ Calendar integration disabled - no event will be updated")
            return
        }
        
        if visit.isValidVisit {
            // Finalize office event with actual end time
            let eventData = createOfficeEventData(
                visit: visit,
                settings: settings,
                isOngoing: false
            )
            
            print("  📅 Finalizing office event: \(eventData.uid)")
            
            let update = CalendarEventUpdate(
                uid: eventData.uid,
                type: .office,
                operation: .update,
                date: visit.date,
                data: eventData
            )
            
            print("  📤 Scheduling office event finalization")
            
            calendarService.scheduleEventUpdate(
                update,
                batchMode: settings.calendarSettings.batchMode == .endOfVisit ? .immediate : .standard
            )
        } else {
            // Visit was too short, remove office event and potentially create remote event
            await handleShortVisit(visit, settings: settings)
        }
    }
    
    private func handleShortVisit(_ visit: OfficeVisit, settings: AppSettings) async {
        let uid = CalendarEventUID.generate(
            date: visit.date,
            type: .office,
            workHours: (settings.officeHours.startTime, settings.officeHours.endTime)
        )
        
        // Remove office event
        let deleteUpdate = CalendarEventUpdate(
            uid: uid,
            type: .office,
            operation: .delete,
            date: visit.date,
            data: CalendarEventData(
                title: "",
                startDate: Date(),
                endDate: Date(),
                isAllDay: false,
                location: nil,
                notes: "",
                uid: uid
            )
        )
        
        calendarService.scheduleEventUpdate(deleteUpdate, batchMode: .immediate)
        
        // Create remote event if applicable
        if shouldCreateRemoteEvent(for: visit.date, settings: settings) {
            await createRemoteWorkEvent(for: visit.date, settings: settings)
        }
    }
    
    // MARK: - Remote Work Event Management
    
    private func setupDailyRemoteWorkCheck() {
        // Schedule daily check at 11:59 PM
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let checkTime = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: tomorrow) ?? tomorrow
        
        remoteWorkTimer = Timer.scheduledTimer(withTimeInterval: checkTime.timeIntervalSince(Date()), repeats: false) { _ in
            Task { @MainActor in
                await self.performDailyRemoteWorkCheck()
                self.setupDailyRemoteWorkCheck() // Reschedule for next day
            }
        }
    }
    
    func performDailyRemoteWorkCheck() async {
        // This will be called from AppData when settings are loaded
        guard let appData = AppDataAccess.shared.appData else { return }
        
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        
        await evaluateRemoteWorkEvent(for: yesterday, settings: appData.settings, visits: appData.visits)
    }
    
    private func evaluateRemoteWorkEvent(for date: Date, settings: AppSettings, visits: [OfficeVisit]) async {
        guard settings.calendarSettings.isEnabled,
              settings.calendarSettings.includeRemoteEvents,
              shouldCreateRemoteEvent(for: date, settings: settings) else {
            return
        }
        
        // Check if there was a valid office visit on this date
        let hasValidOfficeVisit = visits.contains { visit in
            Calendar.current.isDate(visit.date, inSameDayAs: date) && visit.isValidVisit
        }
        
        if !hasValidOfficeVisit {
            await createRemoteWorkEvent(for: date, settings: settings)
        }
    }
    
    private func shouldCreateRemoteEvent(for date: Date, settings: AppSettings) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // Check if it's a tracking day
        return settings.trackingDays.contains(weekday)
    }
    
    private func createRemoteWorkEvent(for date: Date, settings: AppSettings) async {
        guard await getSelectedCalendar(settings: settings) != nil else {
            return
        }
        
        let eventData = createRemoteEventData(date: date, settings: settings)
        
        // Check if event already exists before creating
        let eventExists = await calendarService.eventExists(uid: eventData.uid)
        if eventExists {
            print("  ⚠️ Remote work event already exists for \(eventData.uid) - skipping")
            return
        }
        
        print("  📅 Creating remote work event for \(eventData.uid)")
        
        let update = CalendarEventUpdate(
            uid: eventData.uid,
            type: .remote,
            operation: .create,
            date: date,
            data: eventData
        )
        
        calendarService.scheduleEventUpdate(update, batchMode: .immediate)
    }
    
    // MARK: - Event Data Creation
    
    private func createOfficeEventData(
        visit: OfficeVisit,
        settings: AppSettings,
        isOngoing: Bool
    ) -> CalendarEventData {
        let calendar = Calendar.current
        let timeZone = settings.calendarSettings.effectiveTimeZone
        
        var startDate: Date
        var endDate: Date
        
        if settings.calendarSettings.useActualTimes {
            // Use actual visit times
            startDate = visit.entryTime
            
            if isOngoing {
                // For ongoing visits, extend to expected end time (office hours end)
                // This makes the event appear active in calendar widgets
                let dayStart = calendar.startOfDay(for: visit.date)
                endDate = calendar.date(
                    byAdding: calendar.dateComponents([.hour, .minute], from: settings.officeHours.endTime),
                    to: dayStart
                ) ?? startDate.addingTimeInterval(8 * 3600) // 8 hours fallback
                print("  📅 [CalendarEventManager] Ongoing visit: extending end time to office hours end (\(endDate))")
            } else {
                // For completed visits, use actual exit time
                endDate = visit.exitTime ?? Date()
                print("  📅 [CalendarEventManager] Completed visit: using actual exit time (\(endDate))")
            }
        } else {
            // Use standard work hours
            let dayStart = calendar.startOfDay(for: visit.date)
            startDate = calendar.date(
                byAdding: calendar.dateComponents([.hour, .minute], from: settings.officeHours.startTime),
                to: dayStart
            ) ?? visit.entryTime
            endDate = calendar.date(
                byAdding: calendar.dateComponents([.hour, .minute], from: settings.officeHours.endTime),
                to: dayStart
            ) ?? visit.entryTime.addingTimeInterval(8 * 3600) // 8 hours fallback
        }
        
        // Convert to selected time zone if different from device
        if timeZone != TimeZone.current {
            let offset = timeZone.secondsFromGMT(for: startDate) - TimeZone.current.secondsFromGMT(for: startDate)
            startDate = startDate.addingTimeInterval(TimeInterval(offset))
            endDate = endDate.addingTimeInterval(TimeInterval(offset))
        }
        
        let uid = CalendarEventUID.generate(
            date: visit.date,
            type: .office,
            workHours: (settings.officeHours.startTime, settings.officeHours.endTime)
        )
        
        let notes = createOfficeEventNotes(
            visit: visit,
            settings: settings,
            isOngoing: isOngoing
        )
        
        return CalendarEventData(
            title: settings.calendarSettings.officeEventTitle,
            startDate: startDate,
            endDate: endDate,
            isAllDay: settings.calendarSettings.createAllDayEvents,
            location: settings.officeAddress,
            notes: notes,
            uid: uid
        )
    }
    
    private func createRemoteEventData(date: Date, settings: AppSettings) -> CalendarEventData {
        let calendar = Calendar.current
        let timeZone = settings.calendarSettings.effectiveTimeZone
        
        let dayStart = calendar.startOfDay(for: date)
        var startDate = calendar.date(
            byAdding: calendar.dateComponents([.hour, .minute], from: settings.officeHours.startTime),
            to: dayStart
        ) ?? dayStart.addingTimeInterval(9 * 3600) // 9 AM fallback
        
        var endDate = calendar.date(
            byAdding: calendar.dateComponents([.hour, .minute], from: settings.officeHours.endTime),
            to: dayStart
        ) ?? startDate.addingTimeInterval(8 * 3600) // 8 hours fallback
        
        // Convert to selected time zone if different from device
        if timeZone != TimeZone.current {
            let offset = timeZone.secondsFromGMT(for: startDate) - TimeZone.current.secondsFromGMT(for: startDate)
            startDate = startDate.addingTimeInterval(TimeInterval(offset))
            endDate = endDate.addingTimeInterval(TimeInterval(offset))
        }
        
        let uid = CalendarEventUID.generate(
            date: date,
            type: .remote,
            workHours: (settings.officeHours.startTime, settings.officeHours.endTime)
        )
        
        let notes = createRemoteEventNotes(date: date, settings: settings)
        
        return CalendarEventData(
            title: settings.calendarSettings.remoteEventTitle,
            startDate: startDate,
            endDate: endDate,
            isAllDay: settings.calendarSettings.createAllDayEvents,
            location: nil,
            notes: notes,
            uid: uid
        )
    }
    
    private func createOfficeEventNotes(
        visit: OfficeVisit,
        settings: AppSettings,
        isOngoing: Bool
    ) -> String {
        var notes = ""
        
        if isOngoing {
            notes += "Entry Time: \(formatTime(visit.entryTime))\n"
            notes += "Status: Currently in office\n"
        } else {
            notes += "Entry Time: \(formatTime(visit.entryTime))\n"
            if let exitTime = visit.exitTime {
                notes += "Exit Time: \(formatTime(exitTime))\n"
            }
            if let duration = visit.duration {
                notes += "Duration: \(formatDuration(duration))\n"
            }
        }
        
        notes += "Office Location: \(settings.officeAddress)\n"
        
        // Add monthly progress context
        // This will be populated by the calling code with current progress
        
        return notes
    }
    
    private func createRemoteEventNotes(date: Date, settings: AppSettings) -> String {
        let startTime = formatTime(settings.officeHours.startTime)
        let endTime = formatTime(settings.officeHours.endTime)
        
        var notes = ""
        notes += "Work Hours: \(startTime) - \(endTime)\n"
        notes += "Status: Working Remotely\n"
        
        return notes
    }
    
    // MARK: - Helper Methods
    
    private func getSelectedCalendar(settings: AppSettings) async -> EKCalendar? {
        if let calendarId = settings.calendarSettings.selectedCalendarId {
            // User has selected a specific calendar
            if calendarService.selectedCalendar?.calendarIdentifier != calendarId {
                // Load available calendars and find the selected one
                calendarService.loadAvailableCalendars()
                let calendar = calendarService.availableCalendars.first { cal in
                    cal.calendarIdentifier == calendarId
                }
                calendarService.setSelectedCalendar(calendar)
            }
            return calendarService.selectedCalendar
        } else {
            // No specific calendar selected - try to use default calendar as fallback
            print("  🔍 No specific calendar selected, attempting to use default calendar")
            
            // Create event store to access default calendar
            let eventStore = EKEventStore()
            let defaultCalendar = eventStore.defaultCalendarForNewEvents
            
            print("  - Default calendar available: \(defaultCalendar != nil)")
            if let calendar = defaultCalendar {
                print("  - Default calendar: \(calendar.title) (ID: \(calendar.calendarIdentifier))")
                print("  - Setting as selected calendar in CalendarService")
                calendarService.setSelectedCalendar(calendar)
            }
            
            return defaultCalendar
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours) hours \(minutes) minutes"
    }
    
    // MARK: - Catch-up Sync
    
    func performCatchUpSync(since lastSyncDate: Date, visits: [OfficeVisit], settings: AppSettings) async {
        print("🔄 [CalendarEventManager] Starting catch-up sync")
        
        // Run duplicate cleanup before catch-up sync
        if let selectedCalendar = await getSelectedCalendar(settings: settings) {
            await calendarService.cleanupDuplicateEvents(calendar: selectedCalendar)
        }
        
        let calendar = Calendar.current
        let today = Date()
        let daysSince = today.timeIntervalSince(lastSyncDate)
        let daysToProcess = min(Int(daysSince / 86400), 7) // Max 7 days catch-up
        
        print("  📅 Processing \(daysToProcess) days of catch-up sync")
        
        for i in 1...daysToProcess {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                await evaluateRemoteWorkEvent(for: date, settings: settings, visits: visits)
            }
        }
        
        // Update last sync date
        userDefaults.set(today, forKey: lastSyncKey)
    }
}

// MARK: - App Data Access Helper

class AppDataAccess {
    static let shared = AppDataAccess()
    weak var appData: AppData?
    
    private init() {}
}