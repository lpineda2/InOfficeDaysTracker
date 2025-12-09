//
//  CalendarService.swift
//  InOfficeDaysTracker
//
//  Simplified calendar service for event management
//

import Foundation
import EventKit

// MARK: - Calendar Event Data

struct CalendarEventData {
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String
    let uid: String
}

// MARK: - Calendar Validation

enum CalendarValidationResult {
    case valid
    case notFound
    case noWriteAccess
    case permissionDenied
}

// MARK: - Calendar Errors

enum CalendarError: Error, LocalizedError {
    case permissionDenied
    case calendarNotFound
    case noWriteAccess
    case eventCreationFailed(String)
    case eventUpdateFailed(String)
    case eventNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Calendar access permission required"
        case .calendarNotFound:
            return "Selected calendar not available"
        case .noWriteAccess:
            return "Cannot write to selected calendar"
        case .eventCreationFailed(let details):
            return "Failed to create event: \(details)"
        case .eventUpdateFailed(let details):
            return "Failed to update event: \(details)"
        case .eventNotFound(let uid):
            return "Event not found: \(uid)"
        }
    }
}

// MARK: - Calendar Service

@MainActor
class CalendarService: ObservableObject {
    static let shared = CalendarService()
    
    // Use var so we can recreate after permission is granted
    private(set) var eventStore = EKEventStore()
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var selectedCalendar: EKCalendar?
    @Published var availableCalendars: [EKCalendar] = []
    
    private init() {
        updateAuthorizationStatus()
    }
    
    /// Recreate the event store - needed after permission changes
    func refreshEventStore() {
        eventStore = EKEventStore()
        print("📅 [CalendarService] Event store refreshed")
    }
    
    // MARK: - Authorization
    
    func requestCalendarAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                updateAuthorizationStatus()
                if granted {
                    loadAvailableCalendars()
                }
            }
            return granted
        } catch {
            print("📅 [Calendar] Permission error: \(error.localizedDescription)")
            await MainActor.run {
                updateAuthorizationStatus()
            }
            return false
        }
    }
    
    func updateAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        // Only update if we're not already in a granted state
        // (prevents stale system queries from reverting our state)
        if authorizationStatus != .fullAccess && authorizationStatus != .writeOnly {
            authorizationStatus = status
        } else if status == .denied || status == .restricted {
            // Allow revocation to take effect
            authorizationStatus = status
        }
        print("📅 [CalendarService] Status: \(authorizationStatus.rawValue), hasAccess: \(hasCalendarAccess)")
    }
    
    var hasCalendarAccess: Bool {
        return authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
    }
    
    /// Call this after permission is granted to ensure state is correct
    func setAccessGranted() {
        authorizationStatus = .fullAccess
        // Recreate event store to pick up new permission
        refreshEventStore()
        print("📅 [CalendarService] Access granted, status set to fullAccess, event store refreshed")
    }
    
    // MARK: - Calendar Management
    
    func loadAvailableCalendars() {
        let allCalendars = eventStore.calendars(for: .event)
        print("📅 [Calendar] Total calendars found: \(allCalendars.count)")
        for cal in allCalendars {
            print("📅 [Calendar]   - '\(cal.title)' writable=\(cal.allowsContentModifications) type=\(cal.type.rawValue) source=\(cal.source.title)")
        }
        // Filter calendars:
        // 1. Exclude subscription and birthday types (always read-only)
        // 2. Must be writable (allowsContentModifications = true)
        availableCalendars = allCalendars.filter { 
            $0.type != .subscription && 
            $0.type != .birthday && 
            $0.allowsContentModifications
        }
        print("📅 [Calendar] Loaded \(availableCalendars.count) writable calendars")
        
        if availableCalendars.isEmpty && allCalendars.isEmpty {
            print("📅 [Calendar] ⚠️ No calendars found - this is normal on iOS Simulator")
            print("📅 [Calendar] ⚠️ To test, open Calendar app in simulator and add an event (this creates a local calendar)")
        }
    }
    
    func setSelectedCalendar(_ calendar: EKCalendar?) {
        selectedCalendar = calendar
    }
    
    // MARK: - Event Operations
    
    /// Create or update an event (finds existing by UID in notes)
    func createOrUpdateEvent(data: CalendarEventData, in calendar: EKCalendar) async {
        guard hasCalendarAccess else {
            print("📅 [Calendar] No access - cannot create/update event")
            return
        }
        
        print("📅 [Calendar] createOrUpdateEvent called with UID: \(data.uid)")
        print("📅 [Calendar] Notes preview: \(String(data.notes.prefix(100)))...")
        
        // Try to find existing event by UID
        if let existingEvent = findEvent(uid: data.uid, in: calendar) {
            // Update existing event
            print("📅 [Calendar] Found existing event, updating...")
            updateEvent(existingEvent, with: data)
            do {
                try eventStore.save(existingEvent, span: .thisEvent)
                print("📅 [Calendar] Updated event: \(data.title)")
            } catch {
                print("📅 [Calendar] Failed to update event: \(error.localizedDescription)")
            }
        } else {
            // Create new event
            print("📅 [Calendar] No existing event found, creating new...")
            let event = EKEvent(eventStore: eventStore)
            event.calendar = calendar
            updateEvent(event, with: data)
            
            do {
                try eventStore.save(event, span: .thisEvent)
                print("📅 [Calendar] Created event: \(data.title)")
            } catch {
                print("📅 [Calendar] Failed to create event: \(error.localizedDescription)")
            }
        }
    }
    
    /// Delete an event by UID
    func deleteEvent(uid: String, from calendar: EKCalendar) async {
        guard hasCalendarAccess else {
            print("📅 [Calendar] No access - cannot delete event")
            return
        }
        
        if let event = findEvent(uid: uid, in: calendar) {
            do {
                try eventStore.remove(event, span: .thisEvent)
                print("📅 [Calendar] Deleted event with UID: \(uid)")
            } catch {
                print("📅 [Calendar] Failed to delete event: \(error.localizedDescription)")
            }
        } else {
            print("📅 [Calendar] No event found with UID: \(uid)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func findEvent(uid: String, in calendar: EKCalendar) -> EKEvent? {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        
        // Find event by UID in notes
        let uidMarker = "UID: \(uid)"
        return events.first { event in
            event.notes?.contains(uidMarker) == true
        }
    }
    
    private func updateEvent(_ event: EKEvent, with data: CalendarEventData) {
        event.title = data.title
        event.startDate = data.startDate
        event.endDate = data.endDate
        event.isAllDay = data.isAllDay
        event.location = data.location
        event.availability = .free
        
        // Store UID in notes for future lookups
        var notes = data.notes
        notes += "\n--- Managed by In Office Days ---\n"
        notes += "UID: \(data.uid)\n"
        event.notes = notes
    }
}
