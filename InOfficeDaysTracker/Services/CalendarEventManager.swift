//
//  CalendarEventManager.swift
//  InOfficeDaysTracker
//
//  Simplified calendar event management for office visits
//

import Foundation
import EventKit
import CoreLocation

@MainActor
class CalendarEventManager: ObservableObject {
    private let calendarService = CalendarService.shared
    
    // MARK: - Office Visit Event Management
    
    /// Called when user enters the office geofence
    func handleVisitStart(_ visit: OfficeVisit, settings: AppSettings) async {
        guard settings.calendarSettings.isEnabled else {
            debugLog("📅", "[Calendar] Integration disabled - skipping event creation")
            return
        }
        
        guard let calendar = await getSelectedCalendar(settings: settings) else {
            debugLog("📅", "[Calendar] No calendar selected - skipping event creation")
            return
        }
        
        debugLog("📅", "[Calendar] Creating office event for \(visit.date)")
        
        let eventData = createEventData(for: visit, settings: settings, isOngoing: true)
        do {
            try await calendarService.createOrUpdateEvent(data: eventData, in: calendar)
        } catch {
            debugLog("📅", "[CalendarManager] Failed to create visit event: \(error.localizedDescription)")
            // For now, we log errors. Later we can bubble them up to UI
        }
    }
    
    /// Called when visit is updated (e.g., duration changes)
    func handleVisitUpdate(_ visit: OfficeVisit, settings: AppSettings) async {
        guard settings.calendarSettings.isEnabled, visit.isActiveSession else {
            return
        }
        
        guard let calendar = await getSelectedCalendar(settings: settings) else {
            return
        }
        
        debugLog("📅", "[Calendar] Updating office event for \(visit.date)")
        
        let eventData = createEventData(for: visit, settings: settings, isOngoing: true)
        do {
            try await calendarService.createOrUpdateEvent(data: eventData, in: calendar)
        } catch {
            debugLog("📅", "[CalendarManager] Failed to update visit event: \(error.localizedDescription)")
            // For now, we log errors. Later we can bubble them up to UI
        }
    }
    
    /// Called when user leaves the office geofence
    func handleVisitEnd(_ visit: OfficeVisit, settings: AppSettings) async {
        debugLog("📅", "[CalendarManager] handleVisitEnd called")
        debugLog("📅", "[CalendarManager] Visit details: date=\(visit.date), entry=\(visit.entryTime), exit=\(String(describing: visit.exitTime))")
        debugLog("📅", "[CalendarManager] Visit isValidVisit=\(visit.isValidVisit), duration=\(String(describing: visit.duration))")
        
        guard settings.calendarSettings.isEnabled else {
            debugLog("📅", "[CalendarManager] Calendar integration disabled")
            return
        }
        
        guard let calendar = await getSelectedCalendar(settings: settings) else {
            debugLog("📅", "[CalendarManager] No calendar selected")
            return
        }
        
        if visit.isValidVisit {
            // Finalize the event
            debugLog("📅", "[CalendarManager] Finalizing office event for \(visit.date)")
            let eventData = createEventData(for: visit, settings: settings, isOngoing: false)
            debugLog("📅", "[CalendarManager] Event notes: \(eventData.notes)")
            do {
                try await calendarService.createOrUpdateEvent(data: eventData, in: calendar)
            } catch {
                debugLog("📅", "[CalendarManager] Failed to finalize visit event: \(error.localizedDescription)")
                // For now, we log errors. Later we can bubble them up to UI
            }
        } else {
            // Visit was too short - delete the event
            debugLog("📅", "[CalendarManager] Visit too short - deleting event for \(visit.date)")
            let uid = CalendarEventUID.generate(for: visit.date)
            do {
                try await calendarService.deleteEvent(uid: uid, from: calendar)
            } catch {
                debugLog("📅", "[CalendarManager] Failed to delete short visit event: \(error.localizedDescription)")
                // For now, we log errors. Later we can bubble them up to UI
            }
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
        // For all-day events, use the same day for start and end to display as a single day
        let endOfDay = startOfDay
        
        let uid = CalendarEventUID.generate(for: visit.date)
        
        // Determine which office was visited based on coordinates
        let officeAddress = determineOfficeAddress(for: visit, settings: settings)
        
        var notes = "Office Location: \(officeAddress)\n"
        if isOngoing {
            notes += "Status: Currently in office\n"
            notes += "First Entry: \(formatTime(visit.entryTime))\n"
        } else {
            notes += "First Entry: \(formatTime(visit.entryTime))\n"
            if let exitTime = visit.exitTime {
                notes += "Last Exit: \(formatTime(exitTime))\n"
            }
            if let duration = visit.duration {
                notes += "Office Time (excluding breaks): \(formatDuration(duration))\n"
            }
        }
        
        return CalendarEventData(
            title: settings.calendarSettings.officeEventTitle,
            startDate: startOfDay,
            endDate: endOfDay,
            isAllDay: true,
            location: officeAddress,
            notes: notes,
            uid: uid
        )
    }
    
    private func determineOfficeAddress(for visit: OfficeVisit, settings: AppSettings) -> String {
        // Try to match visit coordinates to configured offices
        if !settings.officeLocations.isEmpty {
            let visitLocation = CLLocation(
                latitude: visit.coordinate.latitude,
                longitude: visit.coordinate.longitude
            )
            
            // Find closest office (should be very close if visit was triggered by geofence)
            var closestOffice: OfficeLocation?
            var closestDistance: CLLocationDistance = .infinity
            
            for office in settings.officeLocations {
                guard let coord = office.coordinate else { continue }
                let officeLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let distance = visitLocation.distance(from: officeLocation)
                
                if distance < closestDistance {
                    closestDistance = distance
                    closestOffice = office
                }
            }
            
            // If within reasonable range (1km), use that office's address
            if let office = closestOffice, closestDistance < 1000 {
                debugLog("📅", "[Calendar] Using \(office.name) address for event (\(Int(closestDistance))m away)")
                return office.address
            }
        }
        
        // Fallback to legacy single office address
        debugLog("📅", "[Calendar] Using legacy office address for event")
        return settings.officeAddress
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
