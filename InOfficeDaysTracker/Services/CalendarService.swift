//
//  CalendarService.swift
//  InOfficeDaysTracker
//
//  Calendar event management for office visits and remote work days
//

import Foundation
import EventKit
import CoreLocation

// MARK: - Calendar Event Models

struct CalendarEventUpdate {
    let uid: String
    let type: CalendarEventType
    let operation: Operation
    let date: Date
    let data: CalendarEventData
    
    enum Operation {
        case create, update, delete
    }
}

struct CalendarEventData {
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String
    let uid: String
}

enum CalendarValidationResult {
    case valid
    case notFound
    case noWriteAccess
    case permissionDenied
}

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
            return "Calendar access permission is required to create events"
        case .calendarNotFound:
            return "Selected calendar is no longer available"
        case .noWriteAccess:
            return "Cannot write to the selected calendar"
        case .eventCreationFailed(let details):
            return "Failed to create calendar event: \(details)"
        case .eventUpdateFailed(let details):
            return "Failed to update calendar event: \(details)"
        case .eventNotFound(let uid):
            return "Calendar event not found: \(uid)"
        }
    }
}

// MARK: - Calendar Service

@MainActor
class CalendarService: ObservableObject {
    static let shared = CalendarService()
    
    private let adapter: EventStoreAdapterProtocol
    private let userDefaults = UserDefaults.standard
    private let eventMappingKey = "CalendarEventMapping"
    
    // Legacy compatibility - expose eventStore for existing code
    var eventStore: EKEventStore { adapter.eventStore }
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var selectedCalendar: EKCalendar?
    @Published var availableCalendars: [EKCalendar] = []
    
    // Batch processing
    private var pendingUpdates: [CalendarEventUpdate] = []
    private var batchTimer: Timer?
    private let batchDelay: TimeInterval = 10.0 // 10-second batching
    
    private init() {
        self.adapter = EventStoreAdapterFactory.shared
        updateAuthorizationStatus()
        print("🔧 [CalendarService] Initialized with \(type(of: adapter)) adapter")
    }
    
    // MARK: - Event ID Mapping Management
    
    private var eventMapping: [String: String] {
        get { userDefaults.object(forKey: eventMappingKey) as? [String: String] ?? [:] }
        set { userDefaults.set(newValue, forKey: eventMappingKey) }
    }
    
    private func storeEventMapping(uid: String, eventIdentifier: String) {
        var mapping = eventMapping
        mapping[uid] = eventIdentifier
        eventMapping = mapping
    }
    
    private func getEventIdentifier(for uid: String) -> String? {
        return eventMapping[uid]
    }
    
    private func removeEventMapping(for uid: String) {
        var mapping = eventMapping
        mapping.removeValue(forKey: uid)
        eventMapping = mapping
    }
    
    func eventExists(uid: String) async -> Bool {
        print("🔍 [CalendarService] Checking if event exists for UID: \(uid)")
        
        // First check the mapping
        if let eventId = getEventIdentifier(for: uid) {
            print("  ✅ Found in mapping: \(eventId)")
            
            // Validate that the mapped event actually still exists in the calendar
            if let actualEvent = eventStore.event(withIdentifier: eventId) {
                let title = actualEvent.title ?? "No title"
                print("  ✅ Validated: Event still exists in calendar: \(title)")
                return true
            } else {
                print("  ⚠️ Mapped event no longer exists in calendar - removing from mapping")
                removeEventMapping(for: uid)
                // Continue to search for the event by UID
            }
        }
        
        print("  🔍 Not in mapping, checking actual calendar events")
        
        // If not in mapping, check actual calendar events (in case mapping is out of sync)
        guard let calendar = selectedCalendar, hasCalendarAccess else {
            print("  ❌ No calendar access or selected calendar")
            return false
        }
        
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        
        print("  🔍 Searching events from \(startDate) to \(endDate) in calendar: \(calendar.title)")
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        
        print("  📊 Found \(events.count) events in date range")
        
        for event in events {
            if let notes = event.notes {
                let uidSearchString = "UID: \(uid)"
                if notes.contains(uidSearchString) {
                    let title = event.title ?? "No title"
                    let eventIdString = event.eventIdentifier ?? "Unknown"
                    print("  ✅ Found matching event: \(title) (ID: \(eventIdString))")
                    // Found the event, update mapping
                    storeEventMapping(uid: uid, eventIdentifier: event.eventIdentifier)
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Authorization & Permissions
    
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
            print("Calendar permission error: \(error)")
            await MainActor.run {
                updateAuthorizationStatus()
            }
            return false
        }
    }
    
    func updateAuthorizationStatus() {
        let previousStatus = authorizationStatus
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        
        if previousStatus != authorizationStatus {
            print("🔍 [CalendarService] Authorization status changed: \(previousStatus.rawValue) → \(authorizationStatus.rawValue)")
        }
    }
    
    var hasCalendarAccess: Bool {
        updateAuthorizationStatus()
        let hasAccess = adapter.hasCalendarAccess()
        print("🔍 [CalendarService] hasCalendarAccess via adapter: \(hasAccess)")
        return hasAccess
    }
    
    // MARK: - Calendar Management
    
    func loadAvailableCalendars() {
        print("🔍 [CalendarService] loadAvailableCalendars called - using adapter")
        availableCalendars = adapter.loadAvailableCalendars()
        print("🔍 [CalendarService] Loaded \(availableCalendars.count) calendars via adapter")
    }
    
    func setSelectedCalendar(_ calendar: EKCalendar?) {
        selectedCalendar = calendar
    }
    
    func validateCalendar(_ calendar: EKCalendar?, force: Bool = false) -> CalendarValidationResult {
        guard let calendar = calendar else {
            print("🔍 [CalendarService] validateCalendar: No calendar provided")
            return .notFound
        }
        
        print("🔍 [CalendarService] validateCalendar: Using adapter for '\(calendar.title)'")
        let result = adapter.validateCalendar(calendar)
        print("🔍 [CalendarService] Validation result via adapter: \(result)")
        return result
    }
    
    // MARK: - Event Creation & Management
    
    func createEvent(data: CalendarEventData, calendar: EKCalendar) throws -> String {
        print("🔍 [CalendarService] createEvent called for: \(data.title) - using adapter")
        
        guard hasCalendarAccess else {
            print("  ❌ No calendar access")
            throw CalendarError.permissionDenied
        }
        
        let validationResult = adapter.validateCalendar(calendar)
        if validationResult != .valid {
            print("  ❌ Calendar validation failed: \(validationResult)")
            throw CalendarError.calendarNotFound
        }
        
        let eventIdentifier = try adapter.createEvent(data, in: calendar)
        
        // Store mapping for future operations
        storeEventMapping(uid: data.uid, eventIdentifier: eventIdentifier)
        
        print("✅ [CalendarService] Created calendar event via adapter: \(data.title) - \(data.uid)")
        return eventIdentifier
    }
    
    func updateEvent(uid: String, data: CalendarEventData) throws {
        guard hasCalendarAccess else {
            throw CalendarError.permissionDenied
        }
        
        guard let eventIdentifier = getEventIdentifier(for: uid),
              let event = eventStore.event(withIdentifier: eventIdentifier) else {
            throw CalendarError.eventNotFound(uid)
        }
        
        // Check if event was manually modified (unmanaged)
        if isEventUnmanaged(event, expectedData: data) {
            print("⚠️ Event \(uid) is unmanaged, skipping update")
            return
        }
        
        // Update event properties
        event.title = data.title
        event.startDate = data.startDate
        event.endDate = data.endDate
        event.isAllDay = data.isAllDay
        event.location = data.location
        event.notes = createEventNotes(data: data)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ Updated calendar event: \(data.title) - \(uid)")
        } catch {
            throw CalendarError.eventUpdateFailed(error.localizedDescription)
        }
    }
    
    func deleteEvent(uid: String) throws {
        guard hasCalendarAccess else {
            throw CalendarError.permissionDenied
        }
        
        guard let eventIdentifier = getEventIdentifier(for: uid),
              let event = eventStore.event(withIdentifier: eventIdentifier) else {
            throw CalendarError.eventNotFound(uid)
        }
        
        do {
            try eventStore.remove(event, span: .thisEvent)
            removeEventMapping(for: uid)
            print("✅ Deleted calendar event: \(uid)")
        } catch {
            throw CalendarError.eventUpdateFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Event Notes & Checksum Management
    
    private func createEventNotes(data: CalendarEventData) -> String {
        let checksum = calculateEventChecksum(data: data)
        
        var notes = data.notes
        notes += "\n\n--- Managed by In Office Days ---"
        notes += "\nUID: \(data.uid)"
        notes += "\nChecksum: \(checksum)"
        
        return notes
    }
    
    private func calculateEventChecksum(data: CalendarEventData) -> String {
        let combined = "\(data.title)|\(data.startDate.timeIntervalSince1970)|\(data.endDate.timeIntervalSince1970)|\(data.location ?? "")|\(data.isAllDay)"
        return String(combined.hashValue)
    }
    
    private func isEventUnmanaged(_ event: EKEvent, expectedData: CalendarEventData) -> Bool {
        guard let notes = event.notes,
              let checksumRange = notes.range(of: "Checksum: "),
              let newlineRange = notes[checksumRange.upperBound...].range(of: "\n") else {
            return false
        }
        
        let storedChecksum = String(notes[checksumRange.upperBound..<newlineRange.lowerBound])
        let expectedChecksum = calculateEventChecksum(data: expectedData)
        
        return storedChecksum != expectedChecksum
    }
    
    // MARK: - Batch Processing
    
    func scheduleEventUpdate(_ update: CalendarEventUpdate, batchMode: BatchMode = .standard) {
        print("📤 [CalendarService] scheduleEventUpdate called")
        print("  - Update UID: \(update.uid)")
        print("  - Operation: \(update.operation)")
        print("  - Batch mode: \(batchMode)")
        
        pendingUpdates.append(update)
        print("  - Pending updates count: \(pendingUpdates.count)")
        
        switch batchMode {
        case .immediate:
            print("  - Processing immediately...")
            processBatch()
        case .standard:
            print("  - Starting batch timer...")
            startBatchTimer()
        case .endOfVisit:
            print("  - Waiting for end of visit...")
            // Processed when visit state changes - caller responsibility
            break
        }
    }
    
    enum BatchMode {
        case immediate, standard, endOfVisit
    }
    
    private func startBatchTimer() {
        print("⏰ [CalendarService] Starting batch timer (\(batchDelay) seconds)")
        batchTimer?.invalidate()
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchDelay, repeats: false) { _ in
            print("⏰ [CalendarService] Batch timer fired - processing batch")
            Task { @MainActor in
                self.processBatch()
            }
        }
        print("  ✅ Timer scheduled successfully")
    }
    
    func processBatch() {
        print("🔄 [CalendarService] processBatch called")
        print("  - Pending updates: \(pendingUpdates.count)")
        
        guard !pendingUpdates.isEmpty else { 
            print("  - No updates to process")
            return 
        }
        
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        batchTimer?.invalidate()
        
        print("  - Processing \(updates.count) updates...")
        
        Task {
            await processUpdates(updates)
        }
    }
    
    private func processUpdates(_ updates: [CalendarEventUpdate]) async {
        print("⚙️ [CalendarService] processUpdates called with \(updates.count) updates")
        
        guard let calendar = selectedCalendar else {
            print("⚠️ No calendar selected, skipping updates")
            return
        }
        
        print("  - Using calendar: \(calendar.title)")
        
        for update in updates {
            print("  - Processing update: \(update.uid) (\(update.operation))")
            do {
                switch update.operation {
                case .create:
                    // Check if event already exists before creating
                    if let existingEventId = getEventIdentifier(for: update.uid) {
                        print("  ⚠️ Event already exists: \(update.uid) (ID: \(existingEventId)) - skipping creation")
                    } else {
                        let eventId = try createEvent(data: update.data, calendar: calendar)
                        print("  ✅ Created event: \(update.data.title) (ID: \(eventId))")
                    }
                case .update:
                    try updateEvent(uid: update.uid, data: update.data)
                    print("  ✅ Updated event: \(update.data.title)")
                case .delete:
                    try deleteEvent(uid: update.uid)
                    print("  ✅ Deleted event: \(update.uid)")
                }
            } catch {
                print("❌ Calendar operation failed: \(error.localizedDescription)")
                // TODO: Add error reporting/banner system
            }
        }
    }
    
    // MARK: - Recovery & Sync
    
    func syncMappingWithExistingEvents(calendar: EKCalendar) async {
        guard hasCalendarAccess else { return }
        
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        
        var recoveredMappings: [String: String] = [:]
        
        for event in events {
            guard let notes = event.notes,
                  let uidRange = notes.range(of: "UID: "),
                  let newlineRange = notes[uidRange.upperBound...].range(of: "\n") else {
                continue
            }
            
            let uid = String(notes[uidRange.upperBound..<newlineRange.lowerBound])
            recoveredMappings[uid] = event.eventIdentifier
        }
        
        // Update mapping
        var currentMapping = eventMapping
        currentMapping.merge(recoveredMappings) { _, new in new }
        eventMapping = currentMapping
        
        print("Recovered \(recoveredMappings.count) event mappings")
    }
    
    // MARK: - Duplicate Detection & Cleanup
    
    func cleanupDuplicateEvents(calendar: EKCalendar) async {
        guard hasCalendarAccess else { return }
        
        print("🧹 [CalendarService] Starting duplicate cleanup for calendar: \(calendar.title)")
        
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        
        // Group events by UID found in notes
        var eventsByUID: [String: [EKEvent]] = [:]
        
        for event in events {
            // Only process our app's events (those with UID in notes)
            guard let notes = event.notes,
                  notes.contains("InOfficeDaysTracker"),
                  let uidRange = notes.range(of: "UID: "),
                  let newlineRange = notes[uidRange.upperBound...].range(of: "\n") else {
                continue
            }
            
            let uid = String(notes[uidRange.upperBound..<newlineRange.lowerBound])
            eventsByUID[uid, default: []].append(event)
        }
        
        // Find and remove duplicates
        var duplicatesRemoved = 0
        for (uid, duplicateEvents) in eventsByUID {
            if duplicateEvents.count > 1 {
                print("  🔍 Found \(duplicateEvents.count) duplicates for UID: \(uid)")
                
                // Keep the first event, remove the rest
                let eventsToRemove = Array(duplicateEvents.dropFirst())
                for event in eventsToRemove {
                    do {
                        try eventStore.remove(event, span: .thisEvent)
                        duplicatesRemoved += 1
                        print("    ❌ Removed duplicate event: \(event.title ?? "Unknown")")
                    } catch {
                        print("    ⚠️ Failed to remove duplicate: \(error)")
                    }
                }
                
                // Update mapping to point to the remaining event
                if let remainingEvent = duplicateEvents.first {
                    storeEventMapping(uid: uid, eventIdentifier: remainingEvent.eventIdentifier)
                }
            }
        }
        
        print("🧹 [CalendarService] Cleanup complete: removed \(duplicatesRemoved) duplicate events")
    }
}