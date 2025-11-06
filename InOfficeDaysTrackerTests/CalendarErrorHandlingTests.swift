//
//  CalendarErrorHandlingTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for comprehensive calendar error handling and recovery mechanisms
//

import XCTest
import EventKit
@testable import InOfficeDaysTracker

class CalendarErrorHandlingTests: XCTestCase {
    
    var mockAdapter: MockEventStoreAdapter!
    var errorNotificationCenter: CalendarErrorNotificationCenter!
    var mockSettings: AppSettings!
    var receivedNotifications: [CalendarOperationError] = []
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockAdapter = MockEventStoreAdapter()
        errorNotificationCenter = CalendarErrorNotificationCenter.shared
        mockSettings = AppSettings()
        
        // Setup notification observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleErrorNotification(_:)),
            name: CalendarErrorNotificationCenter.errorNotification,
            object: nil
        )
        
        receivedNotifications.removeAll()
        
        // Setup mock calendar
        mockAdapter.addMockCalendar(title: "Test Error Calendar")
    }
    
    override func tearDownWithError() throws {
        NotificationCenter.default.removeObserver(self)
        mockAdapter.reset()
        mockAdapter = nil
        errorNotificationCenter = nil
        mockSettings = nil
        receivedNotifications.removeAll()
        try super.tearDownWithError()
    }
    
    @objc private func handleErrorNotification(_ notification: Notification) {
        if let error = notification.object as? CalendarOperationError {
            receivedNotifications.append(error)
        }
    }
    
    // MARK: - Permission Error Tests
    
    func testPermissionDeniedHandling() async throws {
        // Configure mock to simulate permission denied
        mockAdapter.simulatePermissionDenied = true
        
        // Test permission request
        let hasAccess = try await mockAdapter.requestAccess()
        XCTAssertFalse(hasAccess, "Should report no access when permission denied")
        
        // Test calendar loading with permission denied
        let calendars = mockAdapter.loadAvailableCalendars()
        XCTAssertTrue(calendars.isEmpty, "Should return empty calendars when permission denied")
        
        // Test calendar validation with permission denied
        let testCalendar = mockAdapter.mockCalendars.first!
        let validationResult = mockAdapter.validateCalendar(testCalendar)
        XCTAssertEqual(validationResult, .permissionDenied, "Should report permission denied")
    }
    
    func testPermissionRevokedDuringOperation() throws {
        // Start with permission granted
        mockAdapter.simulatePermissionDenied = false
        
        let testCalendar = mockAdapter.mockCalendars.first!
        let eventData = MockEventStoreAdapter.createTestEventData(title: "Permission Test")
        
        // Create event successfully
        let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
        XCTAssertFalse(eventId.isEmpty, "Should create event when permission granted")
        
        // Revoke permission mid-operation
        mockAdapter.simulatePermissionDenied = true
        
        // Try to update event - should fail
        XCTAssertThrowsError(try mockAdapter.updateEvent(eventData, eventIdentifier: eventId, in: testCalendar)) { error in
            // Note: This would be CalendarError.permissionDenied in real implementation
            print("Expected permission error: \(error)")
        }
    }
    
    // MARK: - Calendar Not Found Tests
    
    func testCalendarNotFoundHandling() throws {
        mockAdapter.simulateCalendarNotFound = true
        
        let testCalendar = mockAdapter.mockCalendars.first!
        let eventData = MockEventStoreAdapter.createTestEventData(title: "Calendar Not Found Test")
        
        // Test calendar validation
        let validationResult = mockAdapter.validateCalendar(testCalendar)
        XCTAssertEqual(validationResult, .notFound, "Should report calendar not found")
        
        // Test event creation with missing calendar
        XCTAssertThrowsError(try mockAdapter.createEvent(eventData, in: testCalendar)) { error in
            XCTAssertTrue(error is CalendarError, "Should throw CalendarError")
            if case .calendarNotFound = error as? CalendarError {
                // Expected error type
            } else {
                XCTFail("Should throw CalendarError.calendarNotFound")
            }
        }
    }
    
    // MARK: - Event Operation Errors
    
    func testEventNotFoundError() throws {
        let testCalendar = mockAdapter.mockCalendars.first!
        let nonExistentEventId = "non-existent-event-id"
        
        // Test updating non-existent event
        let eventData = MockEventStoreAdapter.createTestEventData(title: "Update Test")
        XCTAssertThrowsError(try mockAdapter.updateEvent(eventData, eventIdentifier: nonExistentEventId, in: testCalendar)) { error in
            if case .eventNotFound(let id) = error as? CalendarError {
                XCTAssertEqual(id, nonExistentEventId)
            } else {
                XCTFail("Should throw CalendarError.eventNotFound")
            }
        }
        
        // Test deleting non-existent event
        XCTAssertThrowsError(try mockAdapter.deleteEvent(eventIdentifier: nonExistentEventId)) { error in
            if case .eventNotFound(let id) = error as? CalendarError {
                XCTAssertEqual(id, nonExistentEventId)
            } else {
                XCTFail("Should throw CalendarError.eventNotFound")
            }
        }
    }
    
    func testEventCreationFailure() throws {
        mockAdapter.shouldFailOperations = true
        
        let testCalendar = mockAdapter.mockCalendars.first!
        let eventData = MockEventStoreAdapter.createTestEventData(title: "Creation Failure Test")
        
        XCTAssertThrowsError(try mockAdapter.createEvent(eventData, in: testCalendar)) { error in
            if case .eventCreationFailed(let details) = error as? CalendarError {
                XCTAssertEqual(details, "Mock failure")
            } else {
                XCTFail("Should throw CalendarError.eventCreationFailed")
            }
        }
    }
    
    func testEventUpdateFailure() throws {
        // First create an event successfully
        let testCalendar = mockAdapter.mockCalendars.first!
        let eventData = MockEventStoreAdapter.createTestEventData(title: "Update Failure Test")
        let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
        
        // Now simulate update failure
        mockAdapter.shouldFailOperations = true
        
        XCTAssertThrowsError(try mockAdapter.updateEvent(eventData, eventIdentifier: eventId, in: testCalendar)) { error in
            if case .eventUpdateFailed(let details) = error as? CalendarError {
                XCTAssertEqual(details, "Mock failure")
            } else {
                XCTFail("Should throw CalendarError.eventUpdateFailed")
            }
        }
    }
    
    // MARK: - Error Notification Center Tests
    
    func testErrorNotificationPosting() {
        let testError = CalendarError.permissionDenied
        
        // Post error through notification center
        errorNotificationCenter.reportError(
            type: testError,
            operation: "createEvent",
            context: [
                "calendarId": "test-calendar",
                "eventTitle": "Test Event"
            ],
            suggestedAction: .checkPermissions
        )
        
        // Wait briefly for notification
        let expectation = XCTestExpectation(description: "Error notification")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify notification was received
        XCTAssertEqual(receivedNotifications.count, 1, "Should receive one error notification")
        
        let receivedError = receivedNotifications.first!
        XCTAssertEqual(receivedError.operation, "createEvent")
        XCTAssertEqual(receivedError.context["calendarId"] as? String, "test-calendar")
        XCTAssertEqual(receivedError.context["eventTitle"] as? String, "Test Event")
    }
    
    func testErrorRecoveryStrategies() {
        let permissionError = CalendarError.permissionDenied
        let calendarNotFoundError = CalendarError.calendarNotFound
        let eventCreationError = CalendarError.eventCreationFailed("Test failure")
        
        // Test permission error recovery
        errorNotificationCenter.reportError(
            type: permissionError,
            operation: "createEvent",
            suggestedAction: .checkPermissions
        )
        let permissionNotification = receivedNotifications.last!
        XCTAssertEqual(permissionNotification.suggestedAction, .checkPermissions)
        
        // Test calendar not found recovery
        errorNotificationCenter.reportError(
            type: calendarNotFoundError,
            operation: "createEvent",
            suggestedAction: .selectDifferentCalendar
        )
        let calendarNotification = receivedNotifications.last!
        XCTAssertEqual(calendarNotification.suggestedAction, .selectDifferentCalendar)
        
        // Test event creation error recovery
        errorNotificationCenter.reportError(
            type: eventCreationError,
            operation: "createEvent",
            suggestedAction: .retryOperation
        )
        let creationNotification = receivedNotifications.last!
        XCTAssertEqual(creationNotification.suggestedAction, .retryOperation)
    }
    
    // MARK: - Batch Operation Error Handling
    
    func testBatchOperationErrorRecovery() throws {
        let testCalendar = mockAdapter.mockCalendars.first!
        let events = MockEventStoreAdapter.createTestEventBatch(count: 5)
        
        var successCount = 0
        var errorCount = 0
        
        for (index, eventData) in events.enumerated() {
            // Simulate failure for middle event
            mockAdapter.shouldFailOperations = (index == 2)
            
            do {
                _ = try mockAdapter.createEvent(eventData, in: testCalendar)
                successCount += 1
            } catch {
                errorCount += 1
                
                // Report error through notification center
                errorNotificationCenter.reportError(
                    type: error as! CalendarError,
                    operation: "createEvent",
                    context: [
                        "calendarId": testCalendar.calendarIdentifier,
                        "eventTitle": eventData.title
                    ]
                )
            }
        }
        
        XCTAssertEqual(successCount, 4, "Should succeed for 4 out of 5 events")
        XCTAssertEqual(errorCount, 1, "Should fail for 1 out of 5 events")
        XCTAssertGreaterThan(receivedNotifications.count, 0, "Should receive error notifications")
    }
    
    // MARK: - Error Recovery Integration Tests
    
    func testRetryMechanism() throws {
        let testCalendar = mockAdapter.mockCalendars.first!
        let eventData = MockEventStoreAdapter.createTestEventData(title: "Retry Test")
        
        // First attempt fails
        mockAdapter.shouldFailOperations = true
        XCTAssertThrowsError(try mockAdapter.createEvent(eventData, in: testCalendar))
        
        // Retry succeeds
        mockAdapter.shouldFailOperations = false
        let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
        XCTAssertFalse(eventId.isEmpty, "Retry should succeed")
    }
    
    func testCascadingErrorRecovery() throws {
        let testCalendar = mockAdapter.mockCalendars.first!
        let eventData = MockEventStoreAdapter.createTestEventData(title: "Cascading Error Test")
        
        // Create event successfully
        let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
        
        // Calendar becomes unavailable
        mockAdapter.simulateCalendarNotFound = true
        
        // Update fails due to calendar not found
        XCTAssertThrowsError(try mockAdapter.updateEvent(eventData, eventIdentifier: eventId, in: testCalendar))
        
        // Recovery: calendar becomes available again
        mockAdapter.simulateCalendarNotFound = false
        
        // Update now succeeds
        XCTAssertNoThrow(try mockAdapter.updateEvent(eventData, eventIdentifier: eventId, in: testCalendar))
    }
    
    // MARK: - Network and System Error Simulation
    
    func testNetworkTimeoutSimulation() async throws {
        // Simulate slow network by adding delay
        mockAdapter.operationDelay = 2.0
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // This should complete even with delay
        let hasAccess = try await mockAdapter.requestAccess()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        XCTAssertTrue(hasAccess, "Should eventually succeed")
        XCTAssertGreaterThanOrEqual(duration, 2.0, "Should respect the delay")
        XCTAssertLessThan(duration, 3.0, "Should not take too long")
    }
    
    func testSystemResourceExhaustion() throws {
        // Simulate system under heavy load
        let testCalendar = mockAdapter.mockCalendars.first!
        let largeEventCount = 1000
        
        var createdEvents: [String] = []
        var failureCount = 0
        
        for i in 0..<largeEventCount {
            // Simulate occasional failures under load
            mockAdapter.shouldFailOperations = (i % 100 == 99)
            
            let eventData = MockEventStoreAdapter.createTestEventData(
                title: "Load Test \(i)",
                uid: "load-test-\(i)"
            )
            
            do {
                let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
                createdEvents.append(eventId)
            } catch {
                failureCount += 1
            }
        }
        
        print("📊 [Load Test] Created: \(createdEvents.count), Failed: \(failureCount)")
        
        // Should create most events successfully
        XCTAssertGreaterThan(createdEvents.count, largeEventCount * 9 / 10, "Should create most events")
        XCTAssertEqual(failureCount, largeEventCount / 100, "Should have expected failure count")
        
        // Clean up
        for eventId in createdEvents {
            try? mockAdapter.deleteEvent(eventIdentifier: eventId)
        }
    }
    
    // MARK: - Error Message Validation
    
    func testErrorMessageLocalization() {
        let errors: [CalendarError] = [
            .permissionDenied,
            .calendarNotFound,
            .noWriteAccess,
            .eventCreationFailed("Test failure"),
            .eventUpdateFailed("Update failure"),
            .eventNotFound("test-event-id")
        ]
        
        for error in errors {
            let message = error.localizedDescription
            XCTAssertFalse(message.isEmpty, "Error message should not be empty")
            XCTAssertGreaterThan(message.count, 10, "Error message should be descriptive")
            
            print("📝 [Error Message] \(error): \(message)")
        }
    }
}

// MARK: - Test Extensions

extension CalendarErrorHandlingTests {
    /// Helper to create test context
    func createTestContext(
        operation: String = "createEvent",
        calendarId: String = "test-calendar",
        eventTitle: String = "Test Event"
    ) -> [String: Any] {
        return [
            "operation": operation,
            "calendarId": calendarId,
            "eventTitle": eventTitle
        ]
    }
}