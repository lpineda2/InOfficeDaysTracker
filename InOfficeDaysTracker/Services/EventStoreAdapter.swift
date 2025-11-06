//
//  EventStoreAdapter.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 11/6/25.
//

import Foundation
import EventKit

/// Protocol for abstracting EventKit operations with platform-specific implementations
protocol EventStoreAdapterProtocol {
    var eventStore: EKEventStore { get }
    
    // Core operations
    func requestAccess() async throws -> Bool
    func loadAvailableCalendars() -> [EKCalendar]
    func createEvent(_ data: CalendarEventData, in calendar: EKCalendar) throws -> String
    func updateEvent(_ data: CalendarEventData, eventIdentifier: String, in calendar: EKCalendar) throws
    func deleteEvent(eventIdentifier: String) throws
    func validateCalendar(_ calendar: EKCalendar) -> CalendarValidationResult
    
    // Utility operations
    func hasCalendarAccess() -> Bool
    func getEventsPredicate(for calendar: EKCalendar, uid: String) -> NSPredicate?
}

/// Production implementation using standard EventKit behavior
class ProductionEventStoreAdapter: EventStoreAdapterProtocol {
    let eventStore = EKEventStore()
    
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestFullAccessToEvents()
    }
    
    func loadAvailableCalendars() -> [EKCalendar] {
        guard hasCalendarAccess() else { return [] }
        
        return eventStore.calendars(for: .event).filter { calendar in
            calendar.allowsContentModifications
        }
    }
    
    func createEvent(_ data: CalendarEventData, in calendar: EKCalendar) throws -> String {
        let event = EKEvent(eventStore: eventStore)
        event.title = data.title
        event.startDate = data.startDate
        event.endDate = data.endDate
        event.isAllDay = data.isAllDay
        event.calendar = calendar
        
        if let location = data.location, !location.isEmpty {
            event.location = location
        }
        
        event.notes = createEventNotes(data: data)
        
        try eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }
    
    func updateEvent(_ data: CalendarEventData, eventIdentifier: String, in calendar: EKCalendar) throws {
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            throw CalendarError.eventNotFound(eventIdentifier)
        }
        
        event.title = data.title
        event.startDate = data.startDate
        event.endDate = data.endDate
        event.isAllDay = data.isAllDay
        
        if let location = data.location, !location.isEmpty {
            event.location = location
        }
        
        event.notes = createEventNotes(data: data)
        
        try eventStore.save(event, span: .thisEvent)
    }
    
    func deleteEvent(eventIdentifier: String) throws {
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            throw CalendarError.eventNotFound(eventIdentifier)
        }
        
        try eventStore.remove(event, span: .thisEvent)
    }
    
    func validateCalendar(_ calendar: EKCalendar) -> CalendarValidationResult {
        guard hasCalendarAccess() else { return .permissionDenied }
        
        let availableCalendars = eventStore.calendars(for: .event)
        guard availableCalendars.contains(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) else {
            return .notFound
        }
        
        guard calendar.allowsContentModifications else { return .readOnly }
        
        return .valid
    }
    
    func hasCalendarAccess() -> Bool {
        return EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }
    
    func getEventsPredicate(for calendar: EKCalendar, uid: String) -> NSPredicate? {
        return eventStore.predicateForEvents(withStart: Date.distantPast, end: Date.distantFuture, calendars: [calendar])
    }
    
    private func createEventNotes(data: CalendarEventData) -> String {
        let checksum = calculateEventChecksum(data: data)
        
        var notes = data.notes
        notes += "\n\n--- Managed by In Office Days ---"
        notes += "\nUID: \(data.uid)"
        notes += "\nChecksum: \(checksum)"
        
        return notes
    }
    
    private func calculateEventChecksum(data: CalendarEventData) -> String {
        let content = "\(data.title)|\(data.startDate.timeIntervalSince1970)|\(data.endDate.timeIntervalSince1970)|\(data.isAllDay)|\(data.location ?? "")"
        return String(content.hashValue)
    }
}

/// iOS Simulator implementation with workarounds for EventKit limitations
class SimulatorEventStoreAdapter: EventStoreAdapterProtocol {
    let eventStore = EKEventStore()
    
    func requestAccess() async throws -> Bool {
        let granted = try await eventStore.requestFullAccessToEvents()
        print("🔧 [SimulatorAdapter] Permission request result: \(granted)")
        return granted
    }
    
    func loadAvailableCalendars() -> [EKCalendar] {
        print("🔧 [SimulatorAdapter] Loading calendars with simulator workarounds")
        
        // iOS Simulator: Use fresh EventStore since main eventStore often returns empty
        let freshEventStore = EKEventStore()
        let allCalendars = freshEventStore.calendars(for: .event)
        print("🔧 [SimulatorAdapter] Found \(allCalendars.count) total calendars with fresh EventStore")
        
        // iOS Simulator: Be more lenient with calendar filtering
        var availableCalendars = allCalendars.filter { calendar in
            // In simulator, some calendars may not properly report allowsContentModifications
            calendar.allowsContentModifications || calendar.type != .calDAV
        }
        print("🔧 [SimulatorAdapter] Found \(availableCalendars.count) writable calendars")
        
        // Fallback strategies for iOS Simulator
        if availableCalendars.isEmpty {
            availableCalendars = allCalendars.filter { $0.type == .local }
            print("🔧 [SimulatorAdapter] Fallback to local calendars: \(availableCalendars.count)")
        }
        
        // Final fallback: use any available calendar
        if availableCalendars.isEmpty && !allCalendars.isEmpty {
            availableCalendars = Array(allCalendars.prefix(3))
            print("🔧 [SimulatorAdapter] Final fallback: using first \(availableCalendars.count) calendars")
        }
        
        return availableCalendars
    }
    
    func createEvent(_ data: CalendarEventData, in calendar: EKCalendar) throws -> String {
        print("🔧 [SimulatorAdapter] Creating event with iOS Simulator workarounds")
        
        // iOS Simulator: Use fresh EventStore to avoid alarm-related issues
        let saveEventStore = EKEventStore()
        let saveEvent = EKEvent(eventStore: saveEventStore)
        saveEvent.title = data.title
        saveEvent.startDate = data.startDate
        saveEvent.endDate = data.endDate
        saveEvent.isAllDay = data.isAllDay
        
        // Try to add details - location and notes are usually safe in simulator
        if let location = data.location, !location.isEmpty {
            saveEvent.location = location
            print("🔧 [SimulatorAdapter] Added location: \(location)")
        }
        
        saveEvent.notes = createEventNotes(data: data)
        print("🔧 [SimulatorAdapter] Added notes and management metadata")
        
        // Find the calendar in the fresh event store
        let freshCalendars = saveEventStore.calendars(for: .event)
        if let freshCalendar = freshCalendars.first(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) {
            saveEvent.calendar = freshCalendar
            print("🔧 [SimulatorAdapter] Using matching calendar in fresh EventStore")
        } else {
            // Fallback to default calendar
            saveEvent.calendar = saveEventStore.defaultCalendarForNewEvents
            print("🔧 [SimulatorAdapter] Using default calendar in fresh EventStore")
        }
        
        do {
            try saveEventStore.save(saveEvent, span: .thisEvent)
            print("✅ [SimulatorAdapter] Created event with fresh EventStore: \(data.title)")
            return saveEvent.eventIdentifier
        } catch {
            print("❌ [SimulatorAdapter] Fresh EventStore creation failed: \(error)")
            
            // Final fallback: create minimal event
            let minimalEvent = EKEvent(eventStore: saveEventStore)
            minimalEvent.title = data.title
            minimalEvent.startDate = data.startDate
            minimalEvent.endDate = data.endDate
            minimalEvent.isAllDay = data.isAllDay
            minimalEvent.calendar = saveEvent.calendar
            
            try saveEventStore.save(minimalEvent, span: .thisEvent)
            print("✅ [SimulatorAdapter] Created minimal event as fallback")
            return minimalEvent.eventIdentifier
        }
    }
    
    func updateEvent(_ data: CalendarEventData, eventIdentifier: String, in calendar: EKCalendar) throws {
        // iOS Simulator: Use fresh EventStore for updates too
        let updateEventStore = EKEventStore()
        guard let event = updateEventStore.event(withIdentifier: eventIdentifier) else {
            throw CalendarError.eventNotFound(eventIdentifier)
        }
        
        event.title = data.title
        event.startDate = data.startDate
        event.endDate = data.endDate
        event.isAllDay = data.isAllDay
        
        if let location = data.location, !location.isEmpty {
            event.location = location
        }
        
        event.notes = createEventNotes(data: data)
        
        try updateEventStore.save(event, span: .thisEvent)
        print("✅ [SimulatorAdapter] Updated event with fresh EventStore")
    }
    
    func deleteEvent(eventIdentifier: String) throws {
        // iOS Simulator: Use fresh EventStore for deletion
        let deleteEventStore = EKEventStore()
        guard let event = deleteEventStore.event(withIdentifier: eventIdentifier) else {
            throw CalendarError.eventNotFound(eventIdentifier)
        }
        
        try deleteEventStore.remove(event, span: .thisEvent)
        print("✅ [SimulatorAdapter] Deleted event with fresh EventStore")
    }
    
    func validateCalendar(_ calendar: EKCalendar) -> CalendarValidationResult {
        print("🔧 [SimulatorAdapter] Validating calendar with simulator workarounds")
        
        // Use fresh EventStore for validation in simulator
        let validationEventStore = EKEventStore()
        let availableCalendars = validationEventStore.calendars(for: .event)
        
        guard availableCalendars.contains(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) else {
            return .notFound
        }
        
        // iOS Simulator: Be more lenient with modification check
        if let foundCalendar = availableCalendars.first(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) {
            if foundCalendar.allowsContentModifications || foundCalendar.type != .calDAV {
                return .valid
            }
        }
        
        return .readOnly
    }
    
    func hasCalendarAccess() -> Bool {
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        if authStatus == .fullAccess {
            return true
        }
        
        // iOS Simulator fallback: Try to access calendars directly
        let testEventStore = EKEventStore()
        let testCalendars = testEventStore.calendars(for: .event)
        let hasAccess = !testCalendars.isEmpty
        
        print("🔧 [SimulatorAdapter] Access check - Status: \(authStatus.rawValue), Calendars: \(testCalendars.count), HasAccess: \(hasAccess)")
        return hasAccess
    }
    
    func getEventsPredicate(for calendar: EKCalendar, uid: String) -> NSPredicate? {
        // iOS Simulator: Use fresh EventStore for predicate creation
        let predicateEventStore = EKEventStore()
        return predicateEventStore.predicateForEvents(withStart: Date.distantPast, end: Date.distantFuture, calendars: [calendar])
    }
    
    private func createEventNotes(data: CalendarEventData) -> String {
        let checksum = calculateEventChecksum(data: data)
        
        var notes = data.notes
        notes += "\n\n--- Managed by In Office Days ---"
        notes += "\nUID: \(data.uid)"
        notes += "\nChecksum: \(checksum)"
        
        return notes
    }
    
    private func calculateEventChecksum(data: CalendarEventData) -> String {
        let content = "\(data.title)|\(data.startDate.timeIntervalSince1970)|\(data.endDate.timeIntervalSince1970)|\(data.isAllDay)|\(data.location ?? "")"
        return String(content.hashValue)
    }
}

/// Factory for creating the appropriate EventStore adapter based on the current environment
struct EventStoreAdapterFactory {
    static func createAdapter() -> EventStoreAdapterProtocol {
        #if targetEnvironment(simulator)
        print("🔧 [AdapterFactory] Creating iOS Simulator adapter")
        return SimulatorEventStoreAdapter()
        #else
        print("🔧 [AdapterFactory] Creating production adapter")
        return ProductionEventStoreAdapter()
        #endif
    }
    
    static let shared: EventStoreAdapterProtocol = createAdapter()
}