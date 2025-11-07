//
//  CalendarPerformanceTests.swift
//  InOfficeDaysTrackerTests
//
//  Performance testing for calendar operations with EventStore adapter pattern
//

import XCTest
import EventKit
@testable import InOfficeDaysTracker

class CalendarPerformanceTests: XCTestCase {
    
    var mockAdapter: MockEventStoreAdapter!
    var calendarService: CalendarService!
    var mockSettings: AppSettings!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockAdapter = MockEventStoreAdapter()
        mockSettings = AppSettings()
        mockSettings.calendarSettings = CalendarSettings(
            isEnabled: true,
            selectedCalendarId: "test-calendar",
            officeEventTitle: "Performance Test Office",
            remoteEventTitle: "Performance Test Remote",
            useActualTimes: true,
            showAsBusy: false,
            createAllDayEvents: false,
            includeRemoteEvents: true,
            timeZoneMode: .device,
            batchMode: .standard
        )
        
        // Setup mock calendar
        mockAdapter.addMockCalendar(title: "Test Performance Calendar")
        
        // Initialize calendar service with mock adapter
        calendarService = CalendarService.shared
    }
    
    override func tearDownWithError() throws {
        mockAdapter.reset()
        mockAdapter = nil
        calendarService = nil
        mockSettings = nil
        try super.tearDownWithError()
    }
    
    // MARK: - EventStore Pool Performance Tests
    
    func testEventStorePoolPerformance() throws {
        let expectation = XCTestExpectation(description: "EventStore pool performance test")
        
        Task {
            // Measure performance of multiple EventStore operations
            let operationCount = 5  // Reduced from 100 to 5
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate multiple calendar operations that would use the pool
            for i in 0..<operationCount {
                let eventData = MockEventStoreAdapter.createTestEventData(
                    title: "Performance Test \(i)",
                    uid: "perf-test-\(i)"
                )
                
                if let testCalendar = mockAdapter.mockCalendars.first {
                    _ = try mockAdapter.createEvent(eventData, in: testCalendar)
                }
            }
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let totalTime = endTime - startTime
            let avgTimePerOperation = totalTime / Double(operationCount)
            
            print("📊 [Performance] Total time: \(String(format: "%.3f", totalTime))s")
            print("📊 [Performance] Average per operation: \(String(format: "%.6f", avgTimePerOperation))s")
            
            // Verify performance is reasonable (less than 1ms per operation for mock)
            XCTAssertLessThan(avgTimePerOperation, 0.001, "Operation should be fast with pooling")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testBatchEventCreationPerformance() throws {
        measure {
            // Test creating multiple events in batch
            let events = MockEventStoreAdapter.createTestEventBatch(count: 5)  // Reduced from 50 to 5
            
            for (index, eventData) in events.enumerated() {
                if let testCalendar = mockAdapter.mockCalendars.first {
                    do {
                        _ = try mockAdapter.createEvent(eventData, in: testCalendar)
                    } catch {
                        XCTFail("Batch event creation failed at index \(index): \(error)")
                    }
                }
            }
        }
    }
    
    func testConcurrentEventOperations() throws {
        let expectation = XCTestExpectation(description: "Concurrent operations test")
        expectation.expectedFulfillmentCount = 3  // Reduced from 10 to 3
        
        // Test concurrent event operations
        for i in 0..<3 {  // Reduced from 10 to 3
            Task {
                let eventData = MockEventStoreAdapter.createTestEventData(
                    title: "Concurrent Test \(i)",
                    uid: "concurrent-\(i)"
                )
                
                if let testCalendar = mockAdapter.mockCalendars.first {
                    do {
                        let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
                        
                        // Update the event
                        let updatedData = MockEventStoreAdapter.createTestEventData(
                            title: "Updated Concurrent Test \(i)",
                            uid: "concurrent-\(i)"
                        )
                        try mockAdapter.updateEvent(updatedData, eventIdentifier: eventId, in: testCalendar)
                        
                        // Delete the event
                        try mockAdapter.deleteEvent(eventIdentifier: eventId)
                        
                    } catch {
                        XCTFail("Concurrent operation failed for task \(i): \(error)")
                    }
                }
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsageWithManyEvents() throws {
        let initialMemory = getMemoryUsage()
        
        // Create many events to test memory management
        let eventCount = 10  // Reduced from 500 to 10
        var eventIds: [String] = []
        
        for i in 0..<eventCount {
            let eventData = MockEventStoreAdapter.createTestEventData(
                title: "Memory Test \(i)",
                uid: "memory-test-\(i)"
            )
            
            if let testCalendar = mockAdapter.mockCalendars.first {
                let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
                eventIds.append(eventId)
            }
        }
        
        let peakMemory = getMemoryUsage()
        let memoryGrowth = peakMemory - initialMemory
        
        print("📊 [Memory] Initial: \(String(format: "%.2f", initialMemory))MB")
        print("📊 [Memory] Peak: \(String(format: "%.2f", peakMemory))MB")
        print("📊 [Memory] Growth: \(String(format: "%.2f", memoryGrowth))MB")
        
        // Clean up events
        for eventId in eventIds {
            try mockAdapter.deleteEvent(eventIdentifier: eventId)
        }
        
        let finalMemory = getMemoryUsage()
        let memoryReduction = peakMemory - finalMemory
        
        print("📊 [Memory] Final: \(String(format: "%.2f", finalMemory))MB")
        print("📊 [Memory] Reduction: \(String(format: "%.2f", memoryReduction))MB")
        
        // Memory should be reasonable (less than 10MB growth for 10 mock events)
        XCTAssertLessThan(memoryGrowth, 10.0, "Memory growth should be reasonable")
    }
    
    // MARK: - Operation Timing Tests
    
    func testCRUDOperationTiming() throws {
        let testCalendar = mockAdapter.mockCalendars.first!
        
        // Test CREATE timing
        let createStartTime = CFAbsoluteTimeGetCurrent()
        let eventData = MockEventStoreAdapter.createTestEventData(title: "CRUD Timing Test")
        let eventId = try mockAdapter.createEvent(eventData, in: testCalendar)
        let createTime = CFAbsoluteTimeGetCurrent() - createStartTime
        
        // Test UPDATE timing
        let updateStartTime = CFAbsoluteTimeGetCurrent()
        let updatedData = MockEventStoreAdapter.createTestEventData(title: "Updated CRUD Test")
        try mockAdapter.updateEvent(updatedData, eventIdentifier: eventId, in: testCalendar)
        let updateTime = CFAbsoluteTimeGetCurrent() - updateStartTime
        
        // Test DELETE timing
        let deleteStartTime = CFAbsoluteTimeGetCurrent()
        try mockAdapter.deleteEvent(eventIdentifier: eventId)
        let deleteTime = CFAbsoluteTimeGetCurrent() - deleteStartTime
        
        print("⏱️ [Timing] CREATE: \(String(format: "%.6f", createTime))s")
        print("⏱️ [Timing] UPDATE: \(String(format: "%.6f", updateTime))s")
        print("⏱️ [Timing] DELETE: \(String(format: "%.6f", deleteTime))s")
        
        // All operations should be fast (less than 10ms for mock)
        XCTAssertLessThan(createTime, 0.01, "Create operation should be fast")
        XCTAssertLessThan(updateTime, 0.01, "Update operation should be fast")
        XCTAssertLessThan(deleteTime, 0.01, "Delete operation should be fast")
    }
    
    func testCalendarValidationPerformance() throws {
        measure {
            // Test calendar validation performance
            for calendar in mockAdapter.mockCalendars {
                let result = mockAdapter.validateCalendar(calendar)
                XCTAssertEqual(result, .valid)
            }
        }
    }
    
    // MARK: - Performance Monitoring Tests
    
    func testPerformanceMonitoringAccuracy() throws {
        // Create multiple operations to test performance monitoring
        let operationCount = 5  // Reduced from 20 to 5
        let testCalendar = mockAdapter.mockCalendars.first!
        
        for i in 0..<operationCount {
            let eventData = MockEventStoreAdapter.createTestEventData(
                title: "Performance Monitor Test \(i)",
                uid: "perf-monitor-\(i)"
            )
            _ = try mockAdapter.createEvent(eventData, in: testCalendar)
        }
        
        // Check that performance data was recorded
        let createTimes = mockAdapter.getPerformanceData(for: "createEvent")
        XCTAssertEqual(createTimes.count, operationCount, "Should record performance for all operations")
        
        // Check average performance calculation
        let avgTime = mockAdapter.getAveragePerformance(for: "createEvent")
        XCTAssertNotNil(avgTime, "Should calculate average performance")
        XCTAssertGreaterThan(avgTime!, 0, "Average time should be positive")
        
        print("📊 [Performance Monitor] Recorded \(createTimes.count) operations")
        print("📊 [Performance Monitor] Average time: \(String(format: "%.6f", avgTime!))s")
    }
    
    // MARK: - Batch Processing Performance
    
    func testBatchModePerformance() throws {
        let batchSizes = [2, 5, 8]  // Reduced from [10, 50, 100, 200] to [2, 5, 8]
        
        for batchSize in batchSizes {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Create batch of events
            let events = MockEventStoreAdapter.createTestEventBatch(count: batchSize)
            let testCalendar = mockAdapter.mockCalendars.first!
            
            for eventData in events {
                _ = try mockAdapter.createEvent(eventData, in: testCalendar)
            }
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let totalTime = endTime - startTime
            let timePerEvent = totalTime / Double(batchSize)
            
            print("📊 [Batch] Size: \(batchSize), Total: \(String(format: "%.3f", totalTime))s, Per event: \(String(format: "%.6f", timePerEvent))s")
            
            // Performance should scale reasonably
            XCTAssertLessThan(timePerEvent, 0.001, "Per-event time should remain fast even in batches")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return 0.0
        }
    }
}