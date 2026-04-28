//
//  HistoricalSessionRepairTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for historical session repair functionality
//

import Testing
import Foundation
import CoreLocation
@testable import InOfficeDaysTracker

@Suite("Historical Session Repair Tests")
struct HistoricalSessionRepairTests {
    
    /// Helper to create test app data with isolated UserDefaults
    @MainActor
    private func createTestAppData() -> AppData {
        let testSuiteName = "test.session.repair.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removePersistentDomain(forName: testSuiteName)
        
        return AppData(sharedUserDefaults: testDefaults)
    }
    
    // MARK: - Repair Tests
    
    @Test("Repair merges events with short gaps")
    @MainActor
    func testRepairMergesShortGaps() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Create a visit with spurious split (10-minute gap)
        let baseDate = Date()
        let event1 = OfficeEvent(
            entryTime: baseDate,
            exitTime: baseDate.addingTimeInterval(14400) // 4 hours
        )
        let event2 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(15000), // 10 minutes after event1 ends
            exitTime: baseDate.addingTimeInterval(28800) // 4 more hours
        )
        
        let visit = OfficeVisit(
            date: baseDate,
            events: [event1, event2],
            coordinate: testLocation
        )
        
        appData.visits = [visit]
        
        // Run repair
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 900) // 15 min threshold
        
        // Verify repair happened
        #expect(repairedCount == 1)
        #expect(appData.visits.count == 1)
        
        let repairedVisit = appData.visits[0]
        #expect(repairedVisit.events.count == 1) // Merged into 1 event
        
        // Verify the merged event spans the full time
        let mergedEvent = repairedVisit.events[0]
        #expect(mergedEvent.entryTime == baseDate)
        #expect(mergedEvent.exitTime == baseDate.addingTimeInterval(28800))
    }
    
    @Test("Repair preserves events with large gaps")
    @MainActor
    func testRepairPreservesLargeGaps() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Create a visit with legitimate lunch break (1-hour gap)
        let baseDate = Date()
        let event1 = OfficeEvent(
            entryTime: baseDate,
            exitTime: baseDate.addingTimeInterval(14400) // 4 hours (morning)
        )
        let event2 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(18000), // 1 hour after event1 ends (lunch)
            exitTime: baseDate.addingTimeInterval(32400) // 4 more hours (afternoon)
        )
        
        let visit = OfficeVisit(
            date: baseDate,
            events: [event1, event2],
            coordinate: testLocation
        )
        
        appData.visits = [visit]
        
        // Run repair
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 900) // 15 min threshold
        
        // Verify NO repair (gap too large)
        #expect(repairedCount == 0)
        #expect(appData.visits[0].events.count == 2) // Still 2 separate events
    }
    
    @Test("Repair merges multiple consecutive short gaps")
    @MainActor
    func testRepairMergesMultipleShortGaps() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Create a visit with 3 spurious splits (all < 15 min gaps)
        let baseDate = Date()
        let event1 = OfficeEvent(
            entryTime: baseDate,
            exitTime: baseDate.addingTimeInterval(3600) // 1 hour
        )
        let event2 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(4200), // 10 min gap
            exitTime: baseDate.addingTimeInterval(7200) // 1 hour
        )
        let event3 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(7800), // 10 min gap
            exitTime: baseDate.addingTimeInterval(10800) // 1 hour
        )
        
        let visit = OfficeVisit(
            date: baseDate,
            events: [event1, event2, event3],
            coordinate: testLocation
        )
        
        appData.visits = [visit]
        
        // Run repair
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 900)
        
        // Verify all merged into 1 event
        #expect(repairedCount == 1)
        #expect(appData.visits[0].events.count == 1)
        
        let mergedEvent = appData.visits[0].events[0]
        #expect(mergedEvent.entryTime == baseDate)
        #expect(mergedEvent.exitTime == baseDate.addingTimeInterval(10800))
    }
    
    @Test("Repair handles mixed gaps (some mergeable, some not)")
    @MainActor
    func testRepairHandlesMixedGaps() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Create visit with: short gap, long gap, short gap
        let baseDate = Date()
        let event1 = OfficeEvent(
            entryTime: baseDate,
            exitTime: baseDate.addingTimeInterval(3600) // 1 hour
        )
        let event2 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(4200), // 10 min gap (merge)
            exitTime: baseDate.addingTimeInterval(7200) // 1 hour
        )
        let event3 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(10800), // 1 hour gap (don't merge)
            exitTime: baseDate.addingTimeInterval(14400) // 1 hour
        )
        let event4 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(15000), // 10 min gap (merge)
            exitTime: baseDate.addingTimeInterval(18000) // 50 min
        )
        
        let visit = OfficeVisit(
            date: baseDate,
            events: [event1, event2, event3, event4],
            coordinate: testLocation
        )
        
        appData.visits = [visit]
        
        // Run repair
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 900)
        
        // Verify repair happened
        #expect(repairedCount == 1)
        
        // Should have 2 events: (event1+event2) and (event3+event4)
        let repairedVisit = appData.visits[0]
        #expect(repairedVisit.events.count == 2)
        
        // Verify first merged event
        #expect(repairedVisit.events[0].entryTime == baseDate)
        #expect(repairedVisit.events[0].exitTime == baseDate.addingTimeInterval(7200))
        
        // Verify second merged event
        #expect(repairedVisit.events[1].entryTime == baseDate.addingTimeInterval(10800))
        #expect(repairedVisit.events[1].exitTime == baseDate.addingTimeInterval(18000))
    }
    
    @Test("Repair skips active sessions")
    @MainActor
    func testRepairSkipsActiveSessions() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Create visit with active session (no exit time on last event)
        let baseDate = Date()
        let event1 = OfficeEvent(
            entryTime: baseDate,
            exitTime: baseDate.addingTimeInterval(3600)
        )
        let event2 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(4200),
            exitTime: nil // Active session
        )
        
        let visit = OfficeVisit(
            date: baseDate,
            events: [event1, event2],
            coordinate: testLocation
        )
        
        appData.visits = [visit]
        
        // Run repair
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 900)
        
        // Verify NO repair (active session should not be modified)
        #expect(repairedCount == 0)
        #expect(appData.visits[0].events.count == 2)
    }
    
    @Test("Repair handles empty visits gracefully")
    @MainActor
    func testRepairHandlesEmptyVisits() throws {
        let appData = createTestAppData()
        
        // No visits
        #expect(appData.visits.isEmpty)
        
        // Run repair
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 900)
        
        // Should complete without error
        #expect(repairedCount == 0)
        #expect(appData.visits.isEmpty)
    }
    
    @Test("Repair is idempotent")
    @MainActor
    func testRepairIsIdempotent() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Create a visit with spurious split
        let baseDate = Date()
        let event1 = OfficeEvent(
            entryTime: baseDate,
            exitTime: baseDate.addingTimeInterval(3600)
        )
        let event2 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(4200),
            exitTime: baseDate.addingTimeInterval(7200)
        )
        
        let visit = OfficeVisit(
            date: baseDate,
            events: [event1, event2],
            coordinate: testLocation
        )
        
        appData.visits = [visit]
        
        // Run repair first time
        let firstRepairCount = appData.repairHistoricalSessions(gapThreshold: 900)
        #expect(firstRepairCount == 1)
        #expect(appData.visits[0].events.count == 1)
        
        // Run repair again
        let secondRepairCount = appData.repairHistoricalSessions(gapThreshold: 900)
        
        // Should not modify anything (already repaired)
        #expect(secondRepairCount == 0)
        #expect(appData.visits[0].events.count == 1)
    }
    
    @Test("Repair correctly calculates duration after merge")
    @MainActor
    func testRepairDurationCalculation() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Create spuriously split visit
        let baseDate = Date()
        let event1 = OfficeEvent(
            entryTime: baseDate,
            exitTime: baseDate.addingTimeInterval(14400) // 4 hours
        )
        let event2 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(15000), // 10 min gap
            exitTime: baseDate.addingTimeInterval(28800) // 4 hours
        )
        
        let visit = OfficeVisit(
            date: baseDate,
            events: [event1, event2],
            coordinate: testLocation
        )
        
        appData.visits = [visit]
        
        // Duration before repair (excludes gap)
        let durationBefore = visit.duration! // 8 hours total work time
        
        // Run repair
        appData.repairHistoricalSessions(gapThreshold: 900)
        
        // Duration after repair (includes gap since it's now one session)
        let repairedVisit = appData.visits[0]
        let durationAfter = repairedVisit.duration!
        
        // After repair, duration should include the 10-minute gap
        let expectedDuration = TimeInterval(28800) // Full 8 hours from start to end
        #expect(durationAfter == expectedDuration)
        
        // Should be 10 minutes more than before
        #expect(durationAfter > durationBefore)
        #expect(abs(durationAfter - durationBefore - 600) < 1) // ~10 min difference
    }
}
