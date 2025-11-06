//
//  CalendarServiceIntegrationTests.swift
//  InOfficeDaysTrackerTests
//
//  Comprehensive integration tests using MockEventStoreAdapter
//

import XCTest
import EventKit
@testable import InOfficeDaysTracker

class CalendarServiceIntegrationTests: XCTestCase {
    
    var mockAdapter: MockEventStoreAdapter!
    var calendarService: CalendarService!
    var mockSettings: AppSettings!
    var testCalendar: EKCalendar!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Setup mock adapter
        mockAdapter = MockEventStoreAdapter()
        mockAdapter.addMockCalendar(title: "Test Work Calendar", allowsModifications: true)
        testCalendar = mockAdapter.mockCalendars.first!
        
        // Setup mock settings
        mockSettings = AppSettings()
        mockSettings.calendarSettings = CalendarSettings(
            isEnabled: true,
            selectedCalendarId: testCalendar.calendarIdentifier,
            officeEventTitle: "Test Office Day",
            remoteEventTitle: "Test Remote Work",
            useActualTimes: true,
            showAsBusy: false,
            createAllDayEvents: false,
            includeRemoteEvents: true,
            timeZoneMode: .device,
            batchMode: .standard
        )
        
        // Initialize calendar service
        calendarService = CalendarService.shared
    }
    
    override func tearDownWithError() throws {
        mockAdapter.reset()
        mockAdapter = nil
        calendarService = nil
        mockSettings = nil
        testCalendar = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Calendar Selection Tests
    
    func testCalendarSelection() async throws {
        // Test loading available calendars
        let calendars = mockAdapter.loadAvailableCalendars()
        XCTAssertEqual(calendars.count, 1, "Should have one test calendar")
        XCTAssertEqual(calendars.first?.title, "Test Work Calendar")
        
        // Test calendar validation
        let validationResult = mockAdapter.validateCalendar(testCalendar)
        XCTAssertEqual(validationResult, .valid, "Test calendar should be valid")
    }
    
    func testCalendarSettingsValidation() {
        let settings = mockSettings.calendarSettings
        XCTAssertTrue(settings.isValidConfiguration, "Settings should be valid")
        XCTAssertEqual(settings.officeEventTitle, "Test Office Day")
        XCTAssertEqual(settings.remoteEventTitle, "Test Remote Work")
    }
    
    // MARK: - Event Creation Tests
    
    func testOfficeEventCreation() throws {
        let eventData = CalendarEventData(
            title: "Test Office Day",
            startDate: Date(),
            endDate: Date().addingTimeInterval(28800), // 8 hours
            isAllDay: false,
            location: "Test Office",
            notes: "Created by test",
            uid: "test-office-event"
        )
        
        let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
        XCTAssertFalse(eventId.isEmpty, "Should return valid event ID")
        
        // Verify event was created
        XCTAssertTrue(mockAdapter.mockEvents.keys.contains(eventId), "Event should exist in mock store")
        
        let createdEvent = mockAdapter.mockEvents[eventId]!
        XCTAssertEqual(createdEvent.title, "Test Office Day")
        XCTAssertEqual(createdEvent.location, "Test Office")
        XCTAssertFalse(createdEvent.isAllDay)
    }
    
    func testRemoteEventCreation() throws {
        let eventData = CalendarEventData(
            title: "Test Remote Work",
            startDate: Date(),
            endDate: Date().addingTimeInterval(28800),
            isAllDay: false,
            location: "Home Office",
            notes: "Remote work session",
            uid: "test-remote-event"
        )
        
        let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
        let createdEvent = mockAdapter.mockEvents[eventId]!
        
        XCTAssertEqual(createdEvent.title, "Test Remote Work")
        XCTAssertEqual(createdEvent.location, "Home Office")
    }
    
    func testAllDayEventCreation() throws {
        let eventData = CalendarEventData(
            title: "All Day Office",
            startDate: Calendar.current.startOfDay(for: Date()),
            endDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)),
            isAllDay: true,
            location: "Office",
            notes: "All day event",
            uid: "test-allday-event"
        )
        
        let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
        let createdEvent = mockAdapter.mockEvents[eventId]!
        
        XCTAssertTrue(createdEvent.isAllDay, "Should be all day event")
    }
    
    // MARK: - Event Update Tests
    
    func testEventUpdate() throws {
        // Create initial event
        let initialData = CalendarEventData(
            title: "Initial Title",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            location: "Initial Location",
            notes: "Initial notes",
            uid: "update-test-event"
        )
        
        let eventId = try mockAdapter.createEvent(initialData, in: testCalendar)
        
        // Update the event
        let updatedData = CalendarEventData(
            title: "Updated Title",
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            isAllDay: false,
            location: "Updated Location",
            notes: "Updated notes",
            uid: "update-test-event"
        )
        
        try mockAdapter.updateEvent(updatedData, eventIdentifier: eventId, in: testCalendar)
        
        // Verify update
        let updatedEvent = mockAdapter.mockEvents[eventId]!
        XCTAssertEqual(updatedEvent.title, "Updated Title")
        XCTAssertEqual(updatedEvent.location, "Updated Location")
        XCTAssertEqual(updatedEvent.notes, "Updated notes")
    }
    
    func testEventUpdateToAllDay() throws {
        // Create timed event
        let timedData = CalendarEventData(
            title: "Timed Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            location: "Office",
            notes: "Timed event",
            uid: "allday-conversion-test"
        )
        
        let eventId = try mockAdapter.createEvent(timedData, in: testCalendar)
        
        // Convert to all-day
        let allDayData = CalendarEventData(
            title: "All Day Event",
            startDate: Calendar.current.startOfDay(for: Date()),
            endDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)),
            isAllDay: true,
            location: "Office",
            notes: "Now all day",
            uid: "allday-conversion-test"
        )
        
        try mockAdapter.updateEvent(allDayData, eventIdentifier: eventId, in: testCalendar)
        
        let updatedEvent = mockAdapter.mockEvents[eventId]!
        XCTAssertTrue(updatedEvent.isAllDay, "Should be converted to all day")
        XCTAssertEqual(updatedEvent.title, "All Day Event")
    }
    
    // MARK: - Event Deletion Tests
    
    func testEventDeletion() throws {
        // Create event
        let eventData = CalendarEventData(
            title: "Delete Test",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            location: "Office",
            notes: "To be deleted",
            uid: "delete-test-event"
        )
        
        let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
        XCTAssertTrue(mockAdapter.mockEvents.keys.contains(eventId), "Event should exist before deletion")
        
        // Delete event
        try mockAdapter.deleteEvent(eventIdentifier: eventId)
        XCTAssertFalse(mockAdapter.mockEvents.keys.contains(eventId), "Event should not exist after deletion")
    }
    
    // MARK: - Batch Operations Tests
    
    func testBatchEventCreation() throws {
        let eventCount = 10
        let events = MockEventStoreAdapter.createTestEventBatch(count: eventCount)
        var createdEventIds: [String] = []
        
        for eventData in events {
            let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
            createdEventIds.append(eventId)
        }
        
        XCTAssertEqual(createdEventIds.count, eventCount, "Should create all events")
        XCTAssertEqual(mockAdapter.mockEvents.count, eventCount, "Should have all events in store")
        
        // Verify all events were recorded
        XCTAssertEqual(mockAdapter.createEventCalls.count, eventCount, "Should track all create calls")
    }
    
    func testBatchEventDeletion() throws {
        // Create multiple events
        let events = MockEventStoreAdapter.createTestEventBatch(count: 5)
        var eventIds: [String] = []
        
        for eventData in events {
            let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
            eventIds.append(eventId)
        }
        
        // Delete all events
        for eventId in eventIds {
            try mockAdapter.deleteEvent(eventIdentifier: eventId)
        }
        
        XCTAssertTrue(mockAdapter.mockEvents.isEmpty, "All events should be deleted")
        XCTAssertEqual(mockAdapter.deleteEventCalls.count, 5, "Should track all delete calls")
    }
    
    // MARK: - UID Generation Tests
    
    func testUniqueUIDGeneration() {
        let baseDate = Date()
        let workHours = (
            start: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: baseDate)!,
            end: Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: baseDate)!
        )
        
        // Generate UIDs for same date with same work hours
        let uid1 = CalendarEventUID.generate(date: baseDate, type: .office, workHours: workHours)
        let uid2 = CalendarEventUID.generate(date: baseDate, type: .office, workHours: workHours)
        
        XCTAssertEqual(uid1, uid2, "UIDs should be deterministic for same parameters")
        
        // Generate UID for different type
        let remoteUID = CalendarEventUID.generate(date: baseDate, type: .remote, workHours: workHours)
        XCTAssertNotEqual(uid1, remoteUID, "UIDs should differ for different event types")
        
        // Generate UID for different date
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: baseDate)!
        let nextDayUID = CalendarEventUID.generate(date: nextDay, type: .office, workHours: workHours)
        XCTAssertNotEqual(uid1, nextDayUID, "UIDs should differ for different dates")
    }
    
    func testUIDCollisionHandling() throws {
        let baseDate = Date()
        let workHours = (
            start: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: baseDate)!,
            end: Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: baseDate)!
        )
        
        let uid = CalendarEventUID.generate(date: baseDate, type: .office, workHours: workHours)
        
        // Create first event with this UID
        let eventData1 = CalendarEventData(
            title: "First Event",
            startDate: workHours.start,
            endDate: workHours.end,
            isAllDay: false,
            location: "Office",
            notes: "First event with this UID",
            uid: uid
        )
        
        let eventId1 = try mockAdapter.createEvent(eventData1, in: testCalendar)
        
        // Create second event with same UID (simulating collision)
        let eventData2 = CalendarEventData(
            title: "Second Event",
            startDate: workHours.start,
            endDate: workHours.end,
            isAllDay: false,
            location: "Office",
            notes: "Second event with same UID",
            uid: uid
        )
        
        let eventId2 = try mockAdapter.createEvent(eventData2, in: testCalendar)
        
        // Both events should be created (mock doesn't enforce UID uniqueness)
        XCTAssertNotEqual(eventId1, eventId2, "Events should have different IDs even with same UID")
        XCTAssertEqual(mockAdapter.mockEvents.count, 2, "Both events should exist")
    }
    
    // MARK: - Time Zone Tests
    
    func testTimeZoneHandling() {
        let settings = CalendarSettings(
            isEnabled: true,
            selectedCalendarId: "test",
            timeZoneMode: .device
        )
        
        XCTAssertEqual(settings.effectiveTimeZone, TimeZone.current, "Should use device time zone")
        
        // Test with custom time zone
        var homeOfficeSettings = settings
        homeOfficeSettings.timeZoneMode = .homeOffice
        homeOfficeSettings.homeOfficeTimeZoneId = "America/New_York"
        
        let expectedTimeZone = TimeZone(identifier: "America/New_York")!
        XCTAssertEqual(homeOfficeSettings.effectiveTimeZone, expectedTimeZone, "Should use home office time zone")
    }
    
    // MARK: - Calendar Access Pattern Tests
    
    func testProductionAdapterBehavior() {
        // Test that we can create both adapter types
        let productionAdapter = ProductionEventStoreAdapter()
        let simulatorAdapter = SimulatorEventStoreAdapter()
        
        XCTAssertNotNil(productionAdapter.eventStore, "Production adapter should have EventStore")
        XCTAssertNotNil(simulatorAdapter.eventStore, "Simulator adapter should have EventStore")
        
        // Both should have performance monitor
        XCTAssertNotNil(productionAdapter.performanceMonitor, "Production adapter should have performance monitor")
        XCTAssertNotNil(simulatorAdapter.performanceMonitor, "Simulator adapter should have performance monitor")
    }
    
    func testAdapterFactoryBehavior() {
        let adapter = EventStoreAdapterFactory.createAdapter()
        XCTAssertNotNil(adapter, "Factory should create adapter")
        XCTAssertNotNil(adapter.eventStore, "Created adapter should have EventStore")
        
        // Test shared instance
        let sharedAdapter = EventStoreAdapterFactory.shared
        XCTAssertNotNil(sharedAdapter, "Shared adapter should exist")
    }
    
    // MARK: - Performance Validation Tests
    
    func testEventStorePoolIntegration() {
        // Test that EventStore pool is working
        let pool = EventStorePool.shared
        
        let eventStore1 = pool.borrowEventStore()
        let eventStore2 = pool.borrowEventStore()
        let eventStore3 = pool.borrowEventStore()
        
        XCTAssertNotNil(eventStore1, "Should borrow first EventStore")
        XCTAssertNotNil(eventStore2, "Should borrow second EventStore")
        XCTAssertNotNil(eventStore3, "Should borrow third EventStore")
        
        // Return EventStores
        pool.returnEventStore(eventStore1)
        pool.returnEventStore(eventStore2)
        pool.returnEventStore(eventStore3)
        
        // Should be able to borrow again
        let eventStore4 = pool.borrowEventStore()
        XCTAssertNotNil(eventStore4, "Should be able to borrow after returning")
        pool.returnEventStore(eventStore4)
    }
    
    func testPerformanceMonitorIntegration() {
        let monitor = EventStorePerformanceMonitor.shared
        
        // Test operation measurement
        let result = monitor.measureOperation("test_operation") {
            return "test_result"
        }
        
        XCTAssertEqual(result, "test_result", "Should return operation result")
        
        // Test async operation measurement
        let asyncExpectation = expectation(description: "Async operation")
        
        Task {
            let asyncResult = await monitor.measureAsyncOperation("test_async_operation") {
                return "async_result"
            }
            
            XCTAssertEqual(asyncResult, "async_result", "Should return async operation result")
            asyncExpectation.fulfill()
        }
        
        wait(for: [asyncExpectation], timeout: 5.0)
    }
    
    // MARK: - Settings Persistence Tests
    
    func testCalendarSettingsPersistence() {
        var settings = CalendarSettings.default
        
        // Modify settings
        settings.officeEventTitle = "Modified Office"
        settings.remoteEventTitle = "Modified Remote"
        settings.useActualTimes = false
        settings.createAllDayEvents = true
        settings.timeZoneMode = .homeOffice
        settings.homeOfficeTimeZoneId = "Europe/London"
        settings.batchMode = .endOfVisit
        
        // Test validation
        XCTAssertTrue(settings.isValidConfiguration, "Modified settings should be valid")
        
        // Test reset
        settings.resetToDefaults()
        XCTAssertEqual(settings.officeEventTitle, "In Office Day")
        XCTAssertEqual(settings.remoteEventTitle, "Remote Work")
        XCTAssertTrue(settings.useActualTimes)
        XCTAssertFalse(settings.createAllDayEvents)
        XCTAssertEqual(settings.timeZoneMode, .device)
        XCTAssertEqual(settings.batchMode, .standard)
    }
}