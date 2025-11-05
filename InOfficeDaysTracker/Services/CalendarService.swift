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
    
    private func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    var hasCalendarAccess: Bool {
        return authorizationStatus == .fullAccess
    }
    
    // MARK: - Calendar Management
    
    func loadAvailableCalendars() {
        guard hasCalendarAccess else {
            availableCalendars = []
            return
        }
        
        // Get all writable calendars
        availableCalendars = eventStore.calendars(for: .event).filter { calendar in
            calendar.allowsContentModifications
        }
    }
    
    func setSelectedCalendar(_ calendar: EKCalendar?) {
        selectedCalendar = calendar
    }
    
    func validateCalendar(_ calendar: EKCalendar?, force: Bool = false) -> CalendarValidationResult {
        guard hasCalendarAccess else {
            return .permissionDenied
        }
        
        guard let calendar = calendar else {
            return .notFound
        }
        
        // Check if calendar still exists
        let currentCalendars = eventStore.calendars(for: .event)
        guard currentCalendars.contains(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) else {
            return .notFound
        }
        
        // Check write access
        guard calendar.allowsContentModifications else {
            return .noWriteAccess
        }
        
        return .valid
    }
    
    // MARK: - Event Creation & Management
    
    func createEvent(data: CalendarEventData, calendar: EKCalendar) throws -> String {
        guard hasCalendarAccess else {
            throw CalendarError.permissionDenied
        }
        
        guard validateCalendar(calendar) == .valid else {
            throw CalendarError.calendarNotFound
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = data.title
        event.startDate = data.startDate
        event.endDate = data.endDate
        event.isAllDay = data.isAllDay
        event.location = data.location
        event.notes = createEventNotes(data: data)
        event.calendar = calendar
        
        do {
            try eventStore.save(event, span: .thisEvent)
            
            // Store mapping
            storeEventMapping(uid: data.uid, eventIdentifier: event.eventIdentifier)
            
            print("✅ Created calendar event: \(data.title) - \(data.uid)")
            return event.eventIdentifier
        } catch {
            throw CalendarError.eventCreationFailed(error.localizedDescription)
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
        pendingUpdates.append(update)
        
        switch batchMode {
        case .immediate:
            processBatch()
        case .standard:
            startBatchTimer()
        case .endOfVisit:
            // Processed when visit state changes - caller responsibility
            break
        }
    }
    
    enum BatchMode {
        case immediate, standard, endOfVisit
    }
    
    private func startBatchTimer() {
        batchTimer?.invalidate()
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchDelay, repeats: false) { _ in
            Task { @MainActor in
                self.processBatch()
            }
        }
    }
    
    func processBatch() {
        guard !pendingUpdates.isEmpty else { return }
        
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        batchTimer?.invalidate()
        
        Task {
            await processUpdates(updates)
        }
    }
    
    private func processUpdates(_ updates: [CalendarEventUpdate]) async {
        guard let calendar = selectedCalendar else {
            print("⚠️ No calendar selected, skipping updates")
            return
        }
        
        for update in updates {
            do {
                switch update.operation {
                case .create:
                    _ = try createEvent(data: update.data, calendar: calendar)
                case .update:
                    try updateEvent(uid: update.uid, data: update.data)
                case .delete:
                    try deleteEvent(uid: update.uid)
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
        
        print("✅ Recovered \(recoveredMappings.count) event mappings")
    }
}