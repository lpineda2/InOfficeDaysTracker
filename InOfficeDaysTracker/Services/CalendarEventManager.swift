//
//  CalendarEventManager.swift
//  InOfficeDaysTracker
//
//  Simplified calendar event management for office visits
//

import Foundation
import EventKit

@MainActor
class CalendarEventManager: ObservableObject {
    private let calendarService = CalendarService.shared
    
    // MARK: - Office Visit Event Management
    
    /// Called when user enters the office geofence
    func handleVisitStart(_ visit: OfficeVisit, settings: AppSettings) async {
        guard settings.calendarSettings.isEnabled else {
            print("📅 [Calendar] Integration disabled - skipping event creation")
            return
        }
        
        guard let calendar = await getSelectedCalendar(settings: settings) else {
            print("📅 [Calendar] No calendar selected - skipping event creation")
            return
        }
        
        print("📅 [Calendar] Creating office event for \(visit.date)")
        
        let eventData = createEventData(for: visit, settings: settings, isOngoing: true)
        await calendarService.createOrUpdateEvent(data: eventData, in: calendar)
    }
    
    /// Called when visit is updated (e.g., duration changes)
    func handleVisitUpdate(_ visit: OfficeVisit, settings: AppSettings) async {
        guard settings.calendarSettings.isEnabled, visit.isActiveSession else {
            return
        }
        
        guard let calendar = await getSelectedCalendar(settings: settings) else {
            return
        }
        
        print("📅 [Calendar] Updating office event for \(visit.date)")
        
        let eventData = createEventData(for: visit, settings: settings, isOngoing: true)
        await calendarService.createOrUpdateEvent(data: eventData, in: calendar)
    }
    
    /// Called when user leaves the office geofence
    func handleVisitEnd(_ visit: OfficeVisit, settings: AppSettings) async {
        print("📅 [CalendarManager] handleVisitEnd called")
        print("📅 [CalendarManager] Visit details: date=\(visit.date), entry=\(visit.entryTime), exit=\(String(describing: visit.exitTime))")
        print("📅 [CalendarManager] Visit isValidVisit=\(visit.isValidVisit), duration=\(String(describing: visit.duration))")
        
        guard settings.calendarSettings.isEnabled else {
            print("📅 [CalendarManager] Calendar integration disabled")
            return
        }
        
        guard let calendar = await getSelectedCalendar(settings: settings) else {
            print("📅 [CalendarManager] No calendar selected")
            return
        }
        
        if visit.isValidVisit {
            // Finalize the event
            print("📅 [CalendarManager] Finalizing office event for \(visit.date)")
            let eventData = createEventData(for: visit, settings: settings, isOngoing: false)
            print("📅 [CalendarManager] Event notes: \(eventData.notes)")
            await calendarService.createOrUpdateEvent(data: eventData, in: calendar)
        } else {
            // Visit was too short - delete the event
            print("📅 [CalendarManager] Visit too short - deleting event for \(visit.date)")
            let uid = CalendarEventUID.generate(for: visit.date)
            await calendarService.deleteEvent(uid: uid, from: calendar)
        }
    }
    
    // MARK: - Event Data Creation
    
    private func createEventData(
        for visit: OfficeVisit,
        settings: AppSettings,
        isOngoing: Bool
    ) -> CalendarEventData {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: visit.date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let uid = CalendarEventUID.generate(for: visit.date)
        
        var notes = "Office Location: \(settings.officeAddress)\n"
        if isOngoing {
            notes += "Status: Currently in office\n"
            notes += "Entry Time: \(formatTime(visit.entryTime))\n"
        } else {
            notes += "Entry Time: \(formatTime(visit.entryTime))\n"
            if let exitTime = visit.exitTime {
                notes += "Exit Time: \(formatTime(exitTime))\n"
            }
            if let duration = visit.duration {
                notes += "Duration: \(formatDuration(duration))\n"
            }
        }
        
        return CalendarEventData(
            title: settings.calendarSettings.officeEventTitle,
            startDate: startOfDay,
            endDate: endOfDay,
            isAllDay: true,
            location: settings.officeAddress,
            notes: notes,
            uid: uid,
            showAsBusy: settings.calendarSettings.showAsBusy
        )
    }
    
    // MARK: - Helper Methods
    
    private func getSelectedCalendar(settings: AppSettings) async -> EKCalendar? {
        if let calendarId = settings.calendarSettings.selectedCalendarId {
            calendarService.loadAvailableCalendars()
            if let calendar = calendarService.availableCalendars.first(where: { $0.calendarIdentifier == calendarId }) {
                calendarService.setSelectedCalendar(calendar)
                return calendar
            }
        }
        
        // Fallback to default calendar
        let defaultCalendar = calendarService.eventStore.defaultCalendarForNewEvents
        if let calendar = defaultCalendar {
            calendarService.setSelectedCalendar(calendar)
        }
        return defaultCalendar
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}
