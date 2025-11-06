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
    
    private let eventStore = EKEventStore()
    private let userDefaults = UserDefaults.standard
    private let eventMappingKey = "CalendarEventMapping"
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var selectedCalendar: EKCalendar?
    @Published var availableCalendars: [EKCalendar] = []
    
    // Batch processing
    private var pendingUpdates: [CalendarEventUpdate] = []
    private var batchTimer: Timer?
    private let batchDelay: TimeInterval = 10.0 // 10-second batching
    
    private init() {
        updateAuthorizationStatus()
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
        // First, ensure we have the latest status
        updateAuthorizationStatus()
        
        // Check the authorization status first
        let hasFullAccess = authorizationStatus == .fullAccess
        
        print("🔍 [CalendarService] hasCalendarAccess check:")
        print("  - authorizationStatus: \(authorizationStatus.rawValue)")
        print("  - hasFullAccess: \(hasFullAccess)")
        
        // Simulator fallback: If status check fails, try more comprehensive checks
        if !hasFullAccess {
            print("  - Checking simulator fallbacks...")
            
            // iOS Simulator workaround: Try to create a new event store and check again
            let testEventStore = EKEventStore()
            let freshStatus = EKEventStore.authorizationStatus(for: .event)
            
            print("  - Fresh status check: \(freshStatus.rawValue)")
            
            if freshStatus == .fullAccess {
                print("🔍 [CalendarService] Simulator fallback - fresh status shows fullAccess")
                authorizationStatus = freshStatus  // Update our cached status
                return true
            }
            
            // Final fallback: Try to access calendars directly
            if authorizationStatus == .notDetermined || freshStatus == .notDetermined {
                let calendars = testEventStore.calendars(for: .event)
                if !calendars.isEmpty {
                    print("🔍 [CalendarService] Simulator fallback - can access calendars (\(calendars.count) found)")
                    return true
                }
            }
        }
        
        print("  - Final result: \(hasFullAccess)")
        return hasFullAccess
    }
    
    // MARK: - Calendar Management
    
    func loadAvailableCalendars() {
        print("🔍 [CalendarService] loadAvailableCalendars called")
        
        // Use the same access check logic as other functions
        if !hasCalendarAccess {
            print("  - Initial access check failed, trying iOS Simulator fallback...")
            
            // iOS Simulator fallback: Try to access calendars directly
            #if targetEnvironment(simulator)
            do {
                let testCalendars = eventStore.calendars(for: .event)
                if !testCalendars.isEmpty {
                    print("  - iOS Simulator fallback successful: found \(testCalendars.count) calendars")
                    availableCalendars = testCalendars.filter { $0.allowsContentModifications }
                    print("  - Writable calendars: \(availableCalendars.count)")
                    return
                }
            } catch {
                print("  - iOS Simulator fallback failed: \(error)")
            }
            
            // Try fresh EventStore for iOS Simulator
            let freshEventStore = EKEventStore()
            do {
                let freshCalendars = freshEventStore.calendars(for: .event)
                if !freshCalendars.isEmpty {
                    print("  - Fresh EventStore fallback successful: found \(freshCalendars.count) calendars")
                    availableCalendars = freshCalendars.filter { $0.allowsContentModifications }
                    print("  - Writable calendars: \(availableCalendars.count)")
                    return
                }
            } catch {
                print("  - Fresh EventStore fallback failed: \(error)")
            }
            #endif
            
            availableCalendars = []
            print("  - No calendars available")
            return
        }
        
        // Normal access case
        #if targetEnvironment(simulator)
        // iOS Simulator: Use fresh EventStore since main eventStore often returns empty
        let freshEventStore = EKEventStore()
        let allCalendars = freshEventStore.calendars(for: .event)
        print("  - iOS Simulator: using fresh EventStore, found \(allCalendars.count) total calendars")
        
        // iOS Simulator: Be more lenient with calendar filtering
        availableCalendars = allCalendars.filter { calendar in
            // In simulator, some calendars may not properly report allowsContentModifications
            // Include calendars that are not read-only or explicitly allow modifications
            calendar.allowsContentModifications || calendar.type != .calDAV
        }
        print("  - iOS Simulator access: found \(availableCalendars.count) writable calendars out of \(allCalendars.count) total")
        
        // If still no calendars, include all local calendars as fallback
        if availableCalendars.isEmpty {
            availableCalendars = allCalendars.filter { $0.type == .local }
            print("  - iOS Simulator fallback to local calendars: found \(availableCalendars.count)")
        }
        
        // Final fallback for iOS Simulator: use any available calendar
        if availableCalendars.isEmpty && !allCalendars.isEmpty {
            availableCalendars = Array(allCalendars.prefix(3)) // Limit to first 3 to avoid clutter
            print("  - iOS Simulator final fallback: using first \(availableCalendars.count) calendars")
        }
        #else
        // Physical device: Use main eventStore with standard filtering
        let allCalendars = eventStore.calendars(for: .event)
        availableCalendars = allCalendars.filter { calendar in
            calendar.allowsContentModifications
        }
        print("  - Normal access: found \(availableCalendars.count) writable calendars")
        #endif
    }
    
    func setSelectedCalendar(_ calendar: EKCalendar?) {
        selectedCalendar = calendar
    }
    
    func validateCalendar(_ calendar: EKCalendar?, force: Bool = false) -> CalendarValidationResult {
        guard hasCalendarAccess else {
            print("🔍 [CalendarService] validateCalendar: No calendar access")
            return .permissionDenied
        }
        
        guard let calendar = calendar else {
            print("🔍 [CalendarService] validateCalendar: No calendar provided")
            return .notFound
        }
        
        print("🔍 [CalendarService] validateCalendar: Checking calendar '\(calendar.title)' (ID: \(calendar.calendarIdentifier))")
        
        // Check if calendar still exists - try multiple approaches for iOS Simulator
        var currentCalendars: [EKCalendar] = []
        
        currentCalendars = eventStore.calendars(for: .event)
        print("  - Found \(currentCalendars.count) calendars via eventStore")
        
        // iOS Simulator fallback: If no calendars found but we have access, try fresh event store
        if currentCalendars.isEmpty && hasCalendarAccess {
            print("  - No calendars found via main eventStore, trying fresh eventStore...")
            let testEventStore = EKEventStore()
            currentCalendars = testEventStore.calendars(for: .event)
            print("  - Found \(currentCalendars.count) calendars via fresh eventStore")
            
            // Final fallback for simulator: assume calendar is valid if we have access
            if currentCalendars.isEmpty {
                print("  - No calendars found via any method, using force validation")
                if force {
                    print("  - Force validation - assuming calendar is valid")
                    return .valid
                } else {
                    // Try force validation anyway for iOS Simulator
                    print("  - iOS Simulator fallback - assuming calendar is valid despite not finding it in calendar list")
                    return .valid
                }
            }
        }
        
        let calendarExists = currentCalendars.contains(where: { $0.calendarIdentifier == calendar.calendarIdentifier })
        print("  - Calendar exists in available calendars: \(calendarExists)")
        
        guard calendarExists else {
            return .notFound
        }
        
        // Check write access
        let canModify = calendar.allowsContentModifications
        print("  - Calendar allows modifications: \(canModify)")
        
        guard canModify else {
            return .noWriteAccess
        }
        
        print("  ✅ Calendar validation passed")
        return .valid
    }
    
    // MARK: - Event Creation & Management
    
    func createEvent(data: CalendarEventData, calendar: EKCalendar) throws -> String {
        print("🔍 [CalendarService] createEvent called for: \(data.title)")
        
        guard hasCalendarAccess else {
            print("  ❌ No calendar access")
            throw CalendarError.permissionDenied
        }
        
        let validationResult = validateCalendar(calendar)
        if validationResult != .valid {
            print("  ❌ Calendar validation failed: \(validationResult)")
            // iOS Simulator fallback: Try force validation
            let forceResult = validateCalendar(calendar, force: true)
            if forceResult != .valid {
                throw CalendarError.calendarNotFound
            }
            print("  ✅ Force validation succeeded")
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = data.title
        event.startDate = data.startDate
        event.endDate = data.endDate
        event.isAllDay = data.isAllDay
        event.location = data.location
        event.notes = createEventNotes(data: data)
        event.calendar = calendar
        
        // iOS Simulator fix: Multiple approaches to prevent alarm-related errors
        #if targetEnvironment(simulator)
        print("🔧 iOS Simulator detected - applying alarm workarounds")
        
        // Approach 1: Clear any existing alarms
        event.alarms = []
        
        // Approach 2: Ensure no alarms are set (iOS Simulator compatibility)
        print("  - Ensuring no alarms are set for iOS Simulator compatibility")
        #else
        // On physical devices, allow normal alarm behavior
        event.alarms = []
        #endif
        
        print("📅 Saving calendar event with title: '\(data.title)' to calendar: '\(calendar.title)'")
        print("  - Event alarms count: \(event.alarms?.count ?? 0)")
        
        // iOS Simulator: Use fresh EventStore to avoid alarm-related issues
        #if targetEnvironment(simulator)
        let saveEventStore = EKEventStore()
        let saveEvent = EKEvent(eventStore: saveEventStore)
        saveEvent.title = data.title
        saveEvent.startDate = data.startDate
        saveEvent.endDate = data.endDate
        saveEvent.isAllDay = data.isAllDay
        
        // Try to add details - location and notes are usually safe
        if let location = data.location, !location.isEmpty {
            saveEvent.location = location
            print("🔧 Added location: \(location)")
        }
        
        // Add notes with management info
        saveEvent.notes = createEventNotes(data: data)
        print("🔧 Added notes and management metadata")
        
        // Find the calendar in the fresh event store
        let freshCalendars = saveEventStore.calendars(for: .event)
        if let freshCalendar = freshCalendars.first(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) {
            saveEvent.calendar = freshCalendar
            print("🔧 Using fresh EventStore and calendar for iOS Simulator")
        } else {
            // Fallback to default calendar
            saveEvent.calendar = saveEventStore.defaultCalendarForNewEvents
            print("🔧 Using default calendar in fresh EventStore for iOS Simulator")
        }
        
        do {
            try saveEventStore.save(saveEvent, span: .thisEvent)
            storeEventMapping(uid: data.uid, eventIdentifier: saveEvent.eventIdentifier)
            print("✅ Created calendar event with fresh EventStore (iOS Simulator): \(data.title) - \(data.uid)")
            print("  📍 Location: \(saveEvent.location ?? "none")")
            print("  📝 Notes: \(saveEvent.notes?.count ?? 0) characters")
            return saveEvent.eventIdentifier
        } catch {
            print("❌ Fresh EventStore with details failed: \(error)")
            
            // If adding details caused issues, try minimal event as fallback
            let minimalEvent = EKEvent(eventStore: saveEventStore)
            minimalEvent.title = data.title
            minimalEvent.startDate = data.startDate
            minimalEvent.endDate = data.endDate
            minimalEvent.isAllDay = data.isAllDay
            minimalEvent.calendar = saveEvent.calendar
            
            do {
                try saveEventStore.save(minimalEvent, span: .thisEvent)
                storeEventMapping(uid: data.uid, eventIdentifier: minimalEvent.eventIdentifier)
                print("✅ Created minimal calendar event (iOS Simulator fallback): \(data.title) - \(data.uid)")
                return minimalEvent.eventIdentifier
            } catch {
                print("❌ Even minimal fresh EventStore creation failed: \(error)")
                // Continue to original attempt
            }
        }
        #endif
        
        do {
            try eventStore.save(event, span: .thisEvent)
            
            // Store mapping
            storeEventMapping(uid: data.uid, eventIdentifier: event.eventIdentifier)
            
            print("✅ Created calendar event: \(data.title) - \(data.uid)")
            return event.eventIdentifier
        } catch {
            // iOS Simulator specific error handling
            if let ekError = error as? EKError, ekError.code == EKError.alarmGreaterThanRecurrence {
                print("🔧 iOS Simulator alarm error detected - attempting workaround")
                
                // Try creating event without any alarms or properties that might trigger alarm issues
                let simpleEvent = EKEvent(eventStore: eventStore)
                simpleEvent.title = data.title
                simpleEvent.startDate = data.startDate
                simpleEvent.endDate = data.endDate
                simpleEvent.isAllDay = data.isAllDay
                simpleEvent.calendar = calendar
                // Minimal event - no location, notes, or alarms
                
                do {
                    try eventStore.save(simpleEvent, span: .thisEvent)
                    storeEventMapping(uid: data.uid, eventIdentifier: simpleEvent.eventIdentifier)
                    print("✅ Created simplified calendar event (iOS Simulator workaround): \(data.title) - \(data.uid)")
                    return simpleEvent.eventIdentifier
                } catch {
                    print("❌ Even simplified event creation failed: \(error)")
                    throw CalendarError.eventCreationFailed("iOS Simulator event creation failed: \(error.localizedDescription)")
                }
            } else if error.localizedDescription.contains("Alarms cannot be changed") {
                print("🔧 iOS Simulator 'Alarms cannot be changed' error - attempting minimal event creation")
                
                // Create the most minimal event possible
                let minimalEvent = EKEvent(eventStore: eventStore)
                minimalEvent.title = data.title
                minimalEvent.startDate = data.startDate
                minimalEvent.endDate = data.endDate
                minimalEvent.calendar = calendar
                
                do {
                    try eventStore.save(minimalEvent, span: .thisEvent)
                    storeEventMapping(uid: data.uid, eventIdentifier: minimalEvent.eventIdentifier)
                    print("✅ Created minimal calendar event (iOS Simulator alarm workaround): \(data.title) - \(data.uid)")
                    return minimalEvent.eventIdentifier
                } catch {
                    print("❌ Minimal event creation also failed: \(error)")
                    throw CalendarError.eventCreationFailed("iOS Simulator minimal event creation failed: \(error.localizedDescription)")
                }
            } else {
                throw CalendarError.eventCreationFailed(error.localizedDescription)
            }
        }
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