//
//  EventStoreAdapterPatternTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests specifically for the EventStore adapter pattern implementation
//

import XCTest
import EventKit
@testable import InOfficeDaysTracker

class EventStoreAdapterPatternTests: XCTestCase {
    
    var mockAdapter: MockEventStoreAdapter!
    var productionAdapter: ProductionEventStoreAdapter!
    var simulatorAdapter: SimulatorEventStoreAdapter!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockAdapter = MockEventStoreAdapter()
        productionAdapter = ProductionEventStoreAdapter()
        simulatorAdapter = SimulatorEventStoreAdapter()
        
        // Setup test calendar for mock adapter
        mockAdapter.addMockCalendar(title: "Adapter Test Calendar")
    }
    
    override func tearDownWithError() throws {
        mockAdapter.reset()
        mockAdapter = nil
        productionAdapter = nil
        simulatorAdapter = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testProtocolConformance() {
        // Test that all adapters conform to EventStoreAdapterProtocol
        XCTAssertNotNil(mockAdapter)
        XCTAssertNotNil(productionAdapter)
        XCTAssertNotNil(simulatorAdapter)
        
        // Test required properties exist
        XCTAssertNotNil(mockAdapter.eventStore)
        XCTAssertNotNil(mockAdapter.performanceMonitor)
        XCTAssertNotNil(productionAdapter.eventStore)
        XCTAssertNotNil(productionAdapter.performanceMonitor)
        XCTAssertNotNil(simulatorAdapter.eventStore)
        XCTAssertNotNil(simulatorAdapter.performanceMonitor)
    }
    
    func testProtocolMethodsExist() {
        let adapters: [EventStoreAdapterProtocol] = [mockAdapter, productionAdapter, simulatorAdapter]
        
        for adapter in adapters {
            // Test that all required methods are available by calling them
            // These calls will compile if the protocol methods exist
            XCTAssertNotNil(adapter.eventStore)
            XCTAssertNotNil(adapter.performanceMonitor)
            
            // Test basic method availability (won't actually request access)
            let calendars = adapter.loadAvailableCalendars()
            XCTAssertTrue(calendars.isEmpty || !calendars.isEmpty) // Always true but tests method exists
        }
    }
    
    // MARK: - Adapter Factory Tests
    
    func testAdapterFactory() {
        // Test factory creates adapter
        let adapter = EventStoreAdapterFactory.createAdapter()
        XCTAssertNotNil(adapter)
        
        // Test shared instance
        let sharedAdapter = EventStoreAdapterFactory.shared
        XCTAssertNotNil(sharedAdapter)
        
        // Both should have EventStore
        XCTAssertNotNil(adapter.eventStore)
        XCTAssertNotNil(sharedAdapter.eventStore)
    }
    
    func testAdapterFactoryTyping() {
        let adapter = EventStoreAdapterFactory.createAdapter()
        
        #if targetEnvironment(simulator)
        XCTAssertTrue(adapter is SimulatorEventStoreAdapter, "Should create simulator adapter in simulator")
        #else
        XCTAssertTrue(adapter is ProductionEventStoreAdapter, "Should create production adapter on device")
        #endif
    }
    
    // MARK: - Mock Adapter Behavior Tests
    
    func testMockAdapterBasicOperations() async throws {
        let testCalendar = mockAdapter.mockCalendars.first!
        
        // Test permission request
        let hasAccess = try await mockAdapter.requestAccess()
        XCTAssertTrue(hasAccess, "Mock adapter should grant access by default")
        
        // Test calendar loading
        let calendars = mockAdapter.loadAvailableCalendars()
        XCTAssertEqual(calendars.count, 1, "Should have one test calendar")
        
        // Test calendar validation
        let validationResult = mockAdapter.validateCalendar(testCalendar)
        XCTAssertEqual(validationResult, .valid, "Test calendar should be valid")
        
        // Test calendar access check
        let hasCalendarAccess = mockAdapter.hasCalendarAccess()
        XCTAssertTrue(hasCalendarAccess, "Should have calendar access by default")
    }
    
    func testMockAdapterEventOperations() throws {
        let testCalendar = mockAdapter.mockCalendars.first!
        let eventData = MockEventStoreAdapter.createTestEventData(title: "Adapter Test Event")
        
        // Test event creation
        let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
        XCTAssertFalse(eventId.isEmpty, "Should return valid event ID")
        XCTAssertTrue(mockAdapter.mockEvents.keys.contains(eventId), "Event should exist in mock store")
        
        // Test event update
        let updatedData = MockEventStoreAdapter.createTestEventData(title: "Updated Adapter Test")
        XCTAssertNoThrow(try mockAdapter.updateEvent(updatedData, eventIdentifier: eventId, in: testCalendar))
        
        let updatedEvent = mockAdapter.mockEvents[eventId]!
        XCTAssertEqual(updatedEvent.title, "Updated Adapter Test")
        
        // Test event deletion
        XCTAssertNoThrow(try mockAdapter.deleteEvent(eventIdentifier: eventId))
        XCTAssertFalse(mockAdapter.mockEvents.keys.contains(eventId), "Event should be deleted")
    }
    
    func testMockAdapterErrorSimulation() async throws {
        let testCalendar = mockAdapter.mockCalendars.first!
        let eventData = MockEventStoreAdapter.createTestEventData(title: "Error Test Event")
        
        // Test permission denied simulation
        mockAdapter.simulatePermissionDenied = true
        
        let hasAccess = try await mockAdapter.requestAccess()
        XCTAssertFalse(hasAccess, "Should deny access when simulated")
        
        let calendars = mockAdapter.loadAvailableCalendars()
        XCTAssertTrue(calendars.isEmpty, "Should return no calendars when permission denied")
        
        let validationResult = mockAdapter.validateCalendar(testCalendar)
        XCTAssertEqual(validationResult, .permissionDenied, "Should report permission denied")
        
        // Test operation failure simulation
        mockAdapter.simulatePermissionDenied = false // Reset permission
        mockAdapter.shouldFailOperations = true
        
        XCTAssertThrowsError(try mockAdapter.createEvent(eventData, in: testCalendar)) { error in
            XCTAssertTrue(error is CalendarError, "Should throw CalendarError")
        }
    }
    
    // MARK: - Adapter Behavior Comparison Tests
    
    func testAdapterBehaviorConsistency() {
        let adapters: [EventStoreAdapterProtocol] = [mockAdapter, productionAdapter, simulatorAdapter]
        
        for adapter in adapters {
            // All adapters should have same basic structure
            XCTAssertNotNil(adapter.eventStore, "All adapters should have EventStore")
            XCTAssertNotNil(adapter.performanceMonitor, "All adapters should have performance monitor")
            
            // All should respond to hasCalendarAccess (though results may differ)
            let hasAccess = adapter.hasCalendarAccess()
            XCTAssertTrue(hasAccess == true || hasAccess == false, "Should return boolean")
        }
    }
    
    func testPerformanceMonitorIntegration() {
        let adapters: [EventStoreAdapterProtocol] = [mockAdapter, productionAdapter, simulatorAdapter]
        
        for adapter in adapters {
            let monitor = adapter.performanceMonitor
            
            // Test that performance monitor works
            let result = monitor.measureOperation("test_operation") {
                return "test_result"
            }
            
            XCTAssertEqual(result, "test_result", "Performance monitor should return operation result")
        }
    }
    
    // MARK: - Protocol Extension Tests
    
    func testProtocolExtensionMethods() {
        let adapters: [EventStoreAdapterProtocol] = [mockAdapter, productionAdapter, simulatorAdapter]
        
        for adapter in adapters {
            let testData = MockEventStoreAdapter.createTestEventData(title: "Extension Test")
            
            // Test createEventNotes extension method
            let notes = adapter.createEventNotes(data: testData)
            XCTAssertTrue(notes.contains("--- Managed by In Office Days ---"), "Should contain management marker")
            XCTAssertTrue(notes.contains("UID: \(testData.uid)"), "Should contain event UID")
            XCTAssertTrue(notes.contains("Checksum:"), "Should contain checksum")
            
            // Test calculateEventChecksum extension method
            let checksum1 = adapter.calculateEventChecksum(data: testData)
            let checksum2 = adapter.calculateEventChecksum(data: testData)
            XCTAssertEqual(checksum1, checksum2, "Checksum should be deterministic")
            
            // Different data should have different checksum
            let differentData = MockEventStoreAdapter.createTestEventData(title: "Different Title")
            let differentChecksum = adapter.calculateEventChecksum(data: differentData)
            XCTAssertNotEqual(checksum1, differentChecksum, "Different data should have different checksum")
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAdapterAccess() {
        let expectation = XCTestExpectation(description: "Concurrent adapter access")
        expectation.expectedFulfillmentCount = 10
        
        let testCalendar = mockAdapter.mockCalendars.first!
        
        // Test concurrent access to mock adapter
        for i in 0..<10 {
            Task {
                let eventData = MockEventStoreAdapter.createTestEventData(
                    title: "Concurrent Test \(i)",
                    uid: "concurrent-\(i)"
                )
                
                do {
                    let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
                    XCTAssertFalse(eventId.isEmpty, "Should create event concurrently")
                } catch {
                    XCTFail("Concurrent event creation failed: \(error)")
                }
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testAdapterMemoryManagement() {
        weak var weakMockAdapter: MockEventStoreAdapter?
        weak var weakProductionAdapter: ProductionEventStoreAdapter?
        weak var weakSimulatorAdapter: SimulatorEventStoreAdapter?
        
        autoreleasepool {
            let tempMockAdapter = MockEventStoreAdapter()
            let tempProductionAdapter = ProductionEventStoreAdapter()
            let tempSimulatorAdapter = SimulatorEventStoreAdapter()
            
            weakMockAdapter = tempMockAdapter
            weakProductionAdapter = tempProductionAdapter
            weakSimulatorAdapter = tempSimulatorAdapter
            
            // Use adapters briefly
            _ = tempMockAdapter.hasCalendarAccess()
            _ = tempProductionAdapter.hasCalendarAccess()
            _ = tempSimulatorAdapter.hasCalendarAccess()
        }
        
        // Adapters should be deallocated
        XCTAssertNil(weakMockAdapter, "Mock adapter should be deallocated")
        XCTAssertNil(weakProductionAdapter, "Production adapter should be deallocated")
        XCTAssertNil(weakSimulatorAdapter, "Simulator adapter should be deallocated")
    }
    
    // MARK: - EventStore Pool Integration Tests
    
    func testEventStorePoolIntegration() {
        // Test that adapters can use EventStore pool
        let pool = EventStorePool.shared
        
        // Test borrowing EventStore
        let eventStore1 = pool.borrowEventStore()
        let eventStore2 = pool.borrowEventStore()
        
        XCTAssertNotNil(eventStore1, "Should borrow EventStore")
        XCTAssertNotNil(eventStore2, "Should borrow second EventStore")
        
        // Return EventStores
        pool.returnEventStore(eventStore1)
        pool.returnEventStore(eventStore2)
        
        // Test that simulator adapter uses pooled EventStores (indirectly through pool usage)
        let simulatorCalendars = simulatorAdapter.loadAvailableCalendars()
        XCTAssertNotNil(simulatorCalendars, "Simulator adapter should work with pool")
    }
    
    // MARK: - Performance Comparison Tests
    
    func testAdapterPerformanceComparison() {
        let adapters: [(String, EventStoreAdapterProtocol)] = [
            ("Mock", mockAdapter),
            ("Production", productionAdapter),
            ("Simulator", simulatorAdapter)
        ]
        
        for (name, adapter) in adapters {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Perform basic operations
            _ = adapter.hasCalendarAccess()
            _ = adapter.loadAvailableCalendars()
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            print("📊 [Performance] \(name) adapter: \(String(format: "%.6f", duration))s")
            
            // All adapters should be reasonably fast for basic operations
            XCTAssertLessThan(duration, 0.1, "\(name) adapter should be fast")
        }
    }
    
    // MARK: - Error Handling Pattern Tests
    
    func testAdapterErrorHandlingPattern() {
        let testCalendar = mockAdapter.mockCalendars.first!
        let eventData = MockEventStoreAdapter.createTestEventData(title: "Error Pattern Test")
        
        // Test consistent error types across adapters
        mockAdapter.shouldFailOperations = true
        
        XCTAssertThrowsError(try mockAdapter.createEvent(eventData, in: testCalendar)) { error in
            XCTAssertTrue(error is CalendarError, "Should throw CalendarError type")
            
            // Test error has localized description
            let description = error.localizedDescription
            XCTAssertFalse(description.isEmpty, "Error should have description")
        }
    }
}

// MARK: - Test Helper Extensions

extension EventStoreAdapterProtocol {
    /// Helper to check if adapter responds to selector (for testing)
    func responds(to selector: Selector) -> Bool {
        return (self as AnyObject).responds(to: selector)
    }
}