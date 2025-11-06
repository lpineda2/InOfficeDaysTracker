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
    var performanceMonitor: EventStorePerformanceMonitor { get }
    
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
    let performanceMonitor = EventStorePerformanceMonitor.shared
    
    func requestAccess() async throws -> Bool {
        return try await performanceMonitor.measureAsyncOperation("requestAccess_production") {
            try await eventStore.requestFullAccessToEvents()
        }
    }
    
    func loadAvailableCalendars() -> [EKCalendar] {
        return performanceMonitor.measureOperation("loadAvailableCalendars_production") {
            guard hasCalendarAccess() else { return [] }
            
            return eventStore.calendars(for: .event).filter { calendar in
                calendar.allowsContentModifications
            }
        }
    }
    
    func createEvent(_ data: CalendarEventData, in calendar: EKCalendar) throws -> String {
        return try performanceMonitor.measureOperation("createEvent_production") {
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
        
        guard calendar.allowsContentModifications else { return .noWriteAccess }
        
        return .valid
    }
    
    func hasCalendarAccess() -> Bool {
        return EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }
    
    func getEventsPredicate(for calendar: EKCalendar, uid: String) -> NSPredicate? {
        return eventStore.predicateForEvents(withStart: Date.distantPast, end: Date.distantFuture, calendars: [calendar])
    }
}

/// iOS Simulator implementation with workarounds for EventKit limitations
class SimulatorEventStoreAdapter: EventStoreAdapterProtocol {
    let eventStore = EKEventStore()
    let performanceMonitor = EventStorePerformanceMonitor.shared
    
    func requestAccess() async throws -> Bool {
        let granted = try await eventStore.requestFullAccessToEvents()
        print("🔧 [SimulatorAdapter] Permission request result: \(granted)")
        return granted
    }
    
    func loadAvailableCalendars() -> [EKCalendar] {
        return performanceMonitor.measureOperation("loadAvailableCalendars_simulator") {
            print("🔧 [SimulatorAdapter] Loading calendars with pooled EventStore")
            
            // iOS Simulator: Use pooled EventStore for better performance
            let pooledStore = EventStorePool.shared.borrowEventStore()
            let allCalendars = pooledStore.calendars(for: .event)
            EventStorePool.shared.returnEventStore(pooledStore)
            
            print("🔧 [SimulatorAdapter] Found \(allCalendars.count) total calendars with pooled EventStore")
        
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
    }
    
    func createEvent(_ data: CalendarEventData, in calendar: EKCalendar) throws -> String {
        return try performanceMonitor.measureOperation("createEvent_simulator") {
            print("🔧 [SimulatorAdapter] Creating event with pooled EventStore")
            
            // iOS Simulator: Use pooled EventStore for better performance and consistency
            let pooledStore = EventStorePool.shared.borrowEventStore()
            defer { EventStorePool.shared.returnEventStore(pooledStore) }
            
            let saveEvent = EKEvent(eventStore: pooledStore)
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
            
            // Find the calendar in the pooled event store
            let availableCalendars = pooledStore.calendars(for: .event)
            if let matchingCalendar = availableCalendars.first(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) {
                saveEvent.calendar = matchingCalendar
                print("🔧 [SimulatorAdapter] Using matching calendar in pooled EventStore")
            } else {
                // Fallback to default calendar
                saveEvent.calendar = pooledStore.defaultCalendarForNewEvents
                print("🔧 [SimulatorAdapter] Using default calendar in pooled EventStore")
            }
            
            do {
                try pooledStore.save(saveEvent, span: .thisEvent)
                print("✅ [SimulatorAdapter] Created event with pooled EventStore: \(data.title)")
                return saveEvent.eventIdentifier
            } catch {
                print("❌ [SimulatorAdapter] Pooled EventStore creation failed: \(error)")
                
                // Final fallback: create minimal event with same pooled store
                let minimalEvent = EKEvent(eventStore: pooledStore)
                minimalEvent.title = data.title
                minimalEvent.startDate = data.startDate
                minimalEvent.endDate = data.endDate
                minimalEvent.isAllDay = data.isAllDay
                minimalEvent.calendar = saveEvent.calendar
                
                try pooledStore.save(minimalEvent, span: .thisEvent)
                print("✅ [SimulatorAdapter] Created minimal event as fallback")
                return minimalEvent.eventIdentifier
            }
        }
    }
    
    func updateEvent(_ data: CalendarEventData, eventIdentifier: String, in calendar: EKCalendar) throws {
        try performanceMonitor.measureOperation("updateEvent_simulator") {
            print("🔧 [SimulatorAdapter] Updating event with pooled EventStore")
            
            // iOS Simulator: Use pooled EventStore for updates
            let pooledStore = EventStorePool.shared.borrowEventStore()
            defer { EventStorePool.shared.returnEventStore(pooledStore) }
            
            guard let event = pooledStore.event(withIdentifier: eventIdentifier) else {
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
            
            try pooledStore.save(event, span: .thisEvent)
            print("✅ [SimulatorAdapter] Updated event with pooled EventStore")
        }
    }
    
    func deleteEvent(eventIdentifier: String) throws {
        try performanceMonitor.measureOperation("deleteEvent_simulator") {
            print("🔧 [SimulatorAdapter] Deleting event with pooled EventStore")
            
            // iOS Simulator: Use pooled EventStore for deletion
            let pooledStore = EventStorePool.shared.borrowEventStore()
            defer { EventStorePool.shared.returnEventStore(pooledStore) }
            
            guard let event = pooledStore.event(withIdentifier: eventIdentifier) else {
                throw CalendarError.eventNotFound(eventIdentifier)
            }
            
            try pooledStore.remove(event, span: .thisEvent)
            print("✅ [SimulatorAdapter] Deleted event with pooled EventStore")
        }
    }
    
    func validateCalendar(_ calendar: EKCalendar) -> CalendarValidationResult {
        return performanceMonitor.measureOperation("validateCalendar_simulator") {
            print("🔧 [SimulatorAdapter] Validating calendar with pooled EventStore")
            
            // Use pooled EventStore for validation
            let pooledStore = EventStorePool.shared.borrowEventStore()
            defer { EventStorePool.shared.returnEventStore(pooledStore) }
            
            let availableCalendars = pooledStore.calendars(for: .event)
            
            guard availableCalendars.contains(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) else {
                return .notFound
            }
            
            // iOS Simulator: Be more lenient with modification check
            if let foundCalendar = availableCalendars.first(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) {
                if foundCalendar.allowsContentModifications || foundCalendar.type != .calDAV {
                    return .valid
                }
            }
            
            return .noWriteAccess
        }
    }
    
    func hasCalendarAccess() -> Bool {
        return performanceMonitor.measureOperation("hasCalendarAccess_simulator") {
            let authStatus = EKEventStore.authorizationStatus(for: .event)
            if authStatus == .fullAccess {
                return true
            }
            
            // iOS Simulator fallback: Try to access calendars directly with pooled store
            let pooledStore = EventStorePool.shared.borrowEventStore()
            defer { EventStorePool.shared.returnEventStore(pooledStore) }
            
            let testCalendars = pooledStore.calendars(for: .event)
            let hasAccess = !testCalendars.isEmpty
            
            print("🔧 [SimulatorAdapter] Access check - Status: \(authStatus.rawValue), Calendars: \(testCalendars.count), HasAccess: \(hasAccess)")
            return hasAccess
        }
    }
    
    func getEventsPredicate(for calendar: EKCalendar, uid: String) -> NSPredicate? {
        return performanceMonitor.measureOperation("getEventsPredicate_simulator") {
            // iOS Simulator: Use pooled EventStore for predicate creation
            let pooledStore = EventStorePool.shared.borrowEventStore()
            defer { EventStorePool.shared.returnEventStore(pooledStore) }
            
            return pooledStore.predicateForEvents(withStart: Date.distantPast, end: Date.distantFuture, calendars: [calendar])
        }
    }
}

// MARK: - Shared utility methods for both adapters

extension EventStoreAdapterProtocol {
    func createEventNotes(data: CalendarEventData) -> String {
        let checksum = calculateEventChecksum(data: data)
        
        var notes = data.notes
        notes += "\n\n--- Managed by In Office Days ---"
        notes += "\nUID: \(data.uid)"
        notes += "\nChecksum: \(checksum)"
        
        return notes
    }
    
    func calculateEventChecksum(data: CalendarEventData) -> String {
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