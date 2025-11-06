//
//  MockEventStoreAdapter.swift
//  InOfficeDaysTrackerTests
//
//  Mock implementation of EventStoreAdapter for comprehensive testing
//

import Foundation
import EventKit
@testable import InOfficeDaysTracker

/// Mock implementation of EventStoreAdapterProtocol for testing
final class MockEventStoreAdapter: EventStoreAdapterProtocol, @unchecked Sendable {
    let eventStore = EKEventStore()
    let performanceMonitor = EventStorePerformanceMonitor.shared
    
    // MARK: - Test Configuration
    
    /// Controls whether operations should succeed or fail
    var shouldFailOperations = false
    
    /// Simulates permission denied state
    var simulatePermissionDenied = false
    
    /// Simulates calendar not found scenarios
    var simulateCalendarNotFound = false
    
    /// Mock calendars available in the system
    var mockCalendars: [EKCalendar] = []
    
    /// Simulated events in the calendar
    private var _mockEvents: [String: MockEvent] = [:]
    private let eventsQueue = DispatchQueue(label: "MockEventStoreAdapter.events", attributes: .concurrent)
    
    /// Thread-safe accessor for mock events
    var mockEvents: [String: MockEvent] {
        get { return eventsQueue.sync { _mockEvents } }
        set { eventsQueue.async(flags: .barrier) { [weak self] in self?._mockEvents = newValue } }
    }
    
    /// Thread-safe methods for mock events manipulation
    private func setMockEvent(_ event: MockEvent, forKey key: String) {
        eventsQueue.async(flags: .barrier) { [weak self] in
            self?._mockEvents[key] = event
        }
    }
    
    private func removeMockEvent(forKey key: String) {
        eventsQueue.async(flags: .barrier) { [weak self] in
            self?._mockEvents.removeValue(forKey: key)
        }
    }
    
    private func getMockEvent(forKey key: String) -> MockEvent? {
        return eventsQueue.sync { _mockEvents[key] }
    }
    
    /// Delay to simulate real operations (in seconds)
    var operationDelay: TimeInterval = 0.0
    
    // MARK: - Call Tracking
    
    private var _createEventCalls: [(data: CalendarEventData, calendar: EKCalendar)] = []
    private var _updateEventCalls: [(eventId: String, data: CalendarEventData, calendar: EKCalendar)] = []
    private var _deleteEventCalls: [String] = []
    private var _validationCalls: [EKCalendar] = []
    private var _permissionRequestCount = 0
    private let trackingQueue = DispatchQueue(label: "MockEventStoreAdapter.tracking", attributes: .concurrent)
    
    /// Thread-safe accessors for call tracking
    var createEventCalls: [(data: CalendarEventData, calendar: EKCalendar)] {
        return trackingQueue.sync { _createEventCalls }
    }
    
    var updateEventCalls: [(eventId: String, data: CalendarEventData, calendar: EKCalendar)] {
        return trackingQueue.sync { _updateEventCalls }
    }
    
    var deleteEventCalls: [String] {
        return trackingQueue.sync { _deleteEventCalls }
    }
    
    var validationCalls: [EKCalendar] {
        return trackingQueue.sync { _validationCalls }
    }
    
    var permissionRequestCount: Int {
        return trackingQueue.sync { _permissionRequestCount }
    }
    
    // MARK: - Performance Tracking
    
    /// Tracks operation performance for testing
    private var _recordedOperations: [String: [TimeInterval]] = [:]
    private let operationsQueue = DispatchQueue(label: "MockEventStoreAdapter.operations", attributes: .concurrent)
    
    /// Thread-safe accessor for recorded operations
    var recordedOperations: [String: [TimeInterval]] {
        return operationsQueue.sync { _recordedOperations }
    }
    
    // MARK: - Mock Event Structure
    
    struct MockEvent {
        let id: String
        let title: String
        let startDate: Date
        let endDate: Date
        let isAllDay: Bool
        let location: String?
        let notes: String
        let calendar: EKCalendar
        
        init(id: String, data: CalendarEventData, calendar: EKCalendar) {
            self.id = id
            self.title = data.title
            self.startDate = data.startDate
            self.endDate = data.endDate
            self.isAllDay = data.isAllDay
            self.location = data.location
            self.notes = data.notes
            self.calendar = calendar
        }
    }
    
    // MARK: - EventStoreAdapterProtocol Implementation
    
    func requestAccess() async throws -> Bool {
        await simulateDelay()
        
        trackingQueue.async(flags: .barrier) { [weak self] in
            self?._permissionRequestCount += 1
        }
        
        if simulatePermissionDenied {
            return false
        }
        
        if shouldFailOperations {
            throw CalendarError.permissionDenied
        }
        
        return true
    }
    
    func loadAvailableCalendars() -> [EKCalendar] {
        if simulatePermissionDenied {
            return []
        }
        
        return mockCalendars
    }
    
    func createEvent(_ data: CalendarEventData, in calendar: EKCalendar) throws -> String {
        recordOperation("createEvent")
        
        trackingQueue.async(flags: .barrier) { [weak self] in
            self?._createEventCalls.append((data: data, calendar: calendar))
        }
        
        if shouldFailOperations {
            throw CalendarError.eventCreationFailed("Mock failure")
        }
        
        if simulateCalendarNotFound {
            throw CalendarError.calendarNotFound
        }
        
        let eventId = "mock-event-\(UUID().uuidString)"
        let mockEvent = MockEvent(id: eventId, data: data, calendar: calendar)
        setMockEvent(mockEvent, forKey: eventId)
        
        return eventId
    }
    
    func updateEvent(_ data: CalendarEventData, eventIdentifier: String, in calendar: EKCalendar) throws {
        recordOperation("updateEvent")
        
        trackingQueue.async(flags: .barrier) { [weak self] in
            self?._updateEventCalls.append((eventId: eventIdentifier, data: data, calendar: calendar))
        }
        
        if shouldFailOperations {
            throw CalendarError.eventUpdateFailed("Mock failure")
        }
        
        guard getMockEvent(forKey: eventIdentifier) != nil else {
            throw CalendarError.eventNotFound(eventIdentifier)
        }
        
        // Update the mock event
        let updatedEvent = MockEvent(id: eventIdentifier, data: data, calendar: calendar)
        setMockEvent(updatedEvent, forKey: eventIdentifier)
    }
    
    func deleteEvent(eventIdentifier: String) throws {
        recordOperation("deleteEvent")
        
        trackingQueue.async(flags: .barrier) { [weak self] in
            self?._deleteEventCalls.append(eventIdentifier)
        }
        
        if shouldFailOperations {
            throw CalendarError.eventNotFound(eventIdentifier)
        }
        
        guard getMockEvent(forKey: eventIdentifier) != nil else {
            throw CalendarError.eventNotFound(eventIdentifier)
        }
        
        removeMockEvent(forKey: eventIdentifier)
    }
    
    func validateCalendar(_ calendar: EKCalendar) -> CalendarValidationResult {
        recordOperation("validateCalendar")
        
        trackingQueue.async(flags: .barrier) { [weak self] in
            self?._validationCalls.append(calendar)
        }
        
        if simulatePermissionDenied {
            return .permissionDenied
        }
        
        if simulateCalendarNotFound {
            return .notFound
        }
        
        // Check if calendar exists in our mock calendars
        guard mockCalendars.contains(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) else {
            return .notFound
        }
        
        // Simulate write access check
        if calendar.allowsContentModifications {
            return .valid
        } else {
            return .noWriteAccess
        }
    }
    
    func hasCalendarAccess() -> Bool {
        return !simulatePermissionDenied
    }
    
    func getEventsPredicate(for calendar: EKCalendar, uid: String) -> NSPredicate? {
        recordOperation("getEventsPredicate")
        
        // Return a simple predicate for testing
        return NSPredicate(format: "calendarItemIdentifier == %@", calendar.calendarIdentifier)
    }
    
    // MARK: - Test Utilities
    
    /// Reset all tracking data
    func reset() {
        trackingQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self._createEventCalls.removeAll()
            self._updateEventCalls.removeAll()
            self._deleteEventCalls.removeAll()
            self._validationCalls.removeAll()
            self._permissionRequestCount = 0
        }
        
        eventsQueue.async(flags: .barrier) { [weak self] in
            self?._mockEvents.removeAll()
        }
        
        operationsQueue.async(flags: .barrier) { [weak self] in
            self?._recordedOperations.removeAll()
        }
        
        shouldFailOperations = false
        simulatePermissionDenied = false
        simulateCalendarNotFound = false
        operationDelay = 0.0
    }
    
    /// Create a mock calendar for testing
    static func createMockCalendar(title: String, allowsModifications: Bool = true) -> EKCalendar {
        let calendar = EKCalendar(for: .event, eventStore: EKEventStore())
        calendar.title = title
        calendar.source = EKSource()
        
        // Note: In real testing, we might need to use a different approach
        // since EKCalendar properties are read-only in practice
        return calendar
    }
    
    /// Add mock calendars for testing
    func addMockCalendar(title: String, allowsModifications: Bool = true) {
        let calendar = MockEventStoreAdapter.createMockCalendar(title: title, allowsModifications: allowsModifications)
        mockCalendars.append(calendar)
    }
    
    /// Get performance data for specific operation
    func getPerformanceData(for operation: String) -> [TimeInterval] {
        return recordedOperations[operation] ?? []
    }
    
    /// Get average performance for operation
    func getAveragePerformance(for operation: String) -> TimeInterval? {
        let times = recordedOperations[operation] ?? []
        guard !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }
    
    // MARK: - Private Helpers
    
    private func simulateDelay() async {
        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }
    }
    
    private func recordOperation(_ name: String) {
        let startTime = CFAbsoluteTimeGetCurrent()
        // Simulate some processing time
        let processingTime = Double.random(in: 0.001...0.010)
        let endTime = startTime + processingTime
        let duration = endTime - startTime
        
        operationsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if self._recordedOperations[name] == nil {
                self._recordedOperations[name] = []
            }
            self._recordedOperations[name]?.append(duration)
        }
    }
}

// MARK: - Test Data Factories

extension MockEventStoreAdapter {
    
    /// Create test calendar event data
    static func createTestEventData(
        title: String = "Test Office Day",
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(28800), // 8 hours
        isAllDay: Bool = false,
        location: String? = "Test Office",
        notes: String = "Test notes",
        uid: String = "test-uid"
    ) -> CalendarEventData {
        return CalendarEventData(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            uid: uid
        )
    }
    
    /// Create multiple test events for batch testing
    static func createTestEventBatch(count: Int) -> [CalendarEventData] {
        let baseDate = Date()
        return (0..<count).map { index in
            let startDate = Calendar.current.date(byAdding: .day, value: index, to: baseDate) ?? baseDate
            let endDate = Calendar.current.date(byAdding: .hour, value: 8, to: startDate) ?? startDate
            
            return CalendarEventData(
                title: "Office Day \(index + 1)",
                startDate: startDate,
                endDate: endDate,
                isAllDay: false,
                location: "Office Location \(index + 1)",
                notes: "Test notes for event \(index + 1)",
                uid: "test-uid-\(index)"
            )
        }
    }
}