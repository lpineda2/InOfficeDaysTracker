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
        
        // Run repair with 90-minute threshold
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 5400) // 90 min threshold
        
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
        
        // Create a visit with legitimate long break (2-hour gap - exceeds 90 min threshold)
        let baseDate = Date()
        let event1 = OfficeEvent(
            entryTime: baseDate,
            exitTime: baseDate.addingTimeInterval(14400) // 4 hours (morning)
        )
        let event2 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(21600), // 2 hours after event1 ends
            exitTime: baseDate.addingTimeInterval(36000) // 4 more hours (afternoon)
        )
        
        let visit = OfficeVisit(
            date: baseDate,
            events: [event1, event2],
            coordinate: testLocation
        )
        
        appData.visits = [visit]
        
        // Run repair with 90-minute threshold
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 5400) // 90 min threshold
        
        // Verify NO repair (gap too large - 2 hours > 90 min)
        #expect(repairedCount == 0)
        #expect(appData.visits[0].events.count == 2) // Still 2 separate events
    }
    
    @Test("Repair merges multiple consecutive short gaps")
    @MainActor
    func testRepairMergesMultipleShortGaps() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Create a visit with 3 spurious splits (all < 90 min gaps)
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
        
        // Run repair with 90-minute threshold
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 5400)
        
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
        
        // Create visit with: short gap, large gap (>90 min), short gap
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
            entryTime: baseDate.addingTimeInterval(14400), // 2 hour gap (don't merge - exceeds 90 min)
            exitTime: baseDate.addingTimeInterval(18000) // 1 hour
        )
        let event4 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(18600), // 10 min gap (merge)
            exitTime: baseDate.addingTimeInterval(21600) // 50 min
        )
        
        let visit = OfficeVisit(
            date: baseDate,
            events: [event1, event2, event3, event4],
            coordinate: testLocation
        )
        
        appData.visits = [visit]
        
        // Run repair with 90-minute threshold
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 5400)
        
        // Verify repair happened
        #expect(repairedCount == 1)
        
        // Should have 2 events: (event1+event2) and (event3+event4)
        let repairedVisit = appData.visits[0]
        #expect(repairedVisit.events.count == 2)
        
        // Verify first merged event
        #expect(repairedVisit.events[0].entryTime == baseDate)
        #expect(repairedVisit.events[0].exitTime == baseDate.addingTimeInterval(7200))
        
        // Verify second merged event
        #expect(repairedVisit.events[1].entryTime == baseDate.addingTimeInterval(14400))
        #expect(repairedVisit.events[1].exitTime == baseDate.addingTimeInterval(21600))
    }
    
    @Test("Repair merges lunch-time GPS drift (68 minute gap)")
    @MainActor
    func testRepairMergesLunchTimeGPSDrift() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Simulate user's scenario: 7:40 AM to 4:08 PM with 68-minute GPS dropout during lunch
        // User was in office the entire time but lost GPS signal
        let baseDate = Date()
        let event1 = OfficeEvent(
            entryTime: baseDate, // 7:40 AM equivalent
            exitTime: baseDate.addingTimeInterval(15480) // 4.3 hours later (12:04 PM)
        )
        let event2 = OfficeEvent(
            entryTime: baseDate.addingTimeInterval(19560), // 68 minutes after event1 ends (1:12 PM)
            exitTime: baseDate.addingTimeInterval(30480) // 3 more hours (4:08 PM)
        )
        
        let visit = OfficeVisit(
            date: baseDate,
            events: [event1, event2],
            coordinate: testLocation
        )
        
        appData.visits = [visit]
        
        // Run repair with 90-minute threshold (should merge 68-minute gap)
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 5400)
        
        // Verify repair merged the GPS drift
        #expect(repairedCount == 1)
        #expect(appData.visits[0].events.count == 1)
        
        let mergedEvent = appData.visits[0].events[0]
        #expect(mergedEvent.entryTime == baseDate)
        #expect(mergedEvent.exitTime == baseDate.addingTimeInterval(30480))
        
        // Verify total duration is now correct (8.47 hours instead of 7.34 hours with gap)
        let totalDuration = mergedEvent.duration ?? 0
        #expect(totalDuration == 30480) // Full 8.47 hours
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
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 5400)
        
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
        let repairedCount = appData.repairHistoricalSessions(gapThreshold: 5400)
        
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
        let firstRepairCount = appData.repairHistoricalSessions(gapThreshold: 5400)
        #expect(firstRepairCount == 1)
        #expect(appData.visits[0].events.count == 1)
        
        // Run repair again
        let secondRepairCount = appData.repairHistoricalSessions(gapThreshold: 5400)
        
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
        appData.repairHistoricalSessions(gapThreshold: 5400)
        
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
    
    // MARK: - Date Filter Tests
    
    @Test("Repair respects date filter (only repairs recent visits)")
    @MainActor
    func testRepairRespectsDateFilter() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let calendar = Calendar.current
        
        // Create old visit (45 days ago) with GPS drift
        let oldDate = calendar.date(byAdding: .day, value: -45, to: Date())!
        let oldEvent1 = OfficeEvent(
            entryTime: oldDate,
            exitTime: oldDate.addingTimeInterval(3600)
        )
        let oldEvent2 = OfficeEvent(
            entryTime: oldDate.addingTimeInterval(4200), // 10 min gap
            exitTime: oldDate.addingTimeInterval(7200)
        )
        let oldVisit = OfficeVisit(
            date: oldDate,
            events: [oldEvent1, oldEvent2],
            coordinate: testLocation
        )
        
        // Create recent visit (15 days ago) with GPS drift
        let recentDate = calendar.date(byAdding: .day, value: -15, to: Date())!
        let recentEvent1 = OfficeEvent(
            entryTime: recentDate,
            exitTime: recentDate.addingTimeInterval(3600)
        )
        let recentEvent2 = OfficeEvent(
            entryTime: recentDate.addingTimeInterval(4200), // 10 min gap
            exitTime: recentDate.addingTimeInterval(7200)
        )
        let recentVisit = OfficeVisit(
            date: recentDate,
            events: [recentEvent1, recentEvent2],
            coordinate: testLocation
        )
        
        appData.visits = [oldVisit, recentVisit]
        
        // Run repair with 30-day filter
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        let repairedCount = appData.repairHistoricalSessions(dateFilter: thirtyDaysAgo)
        
        // Should only repair the recent visit
        #expect(repairedCount == 1)
        
        // Find visits in results
        let oldVisitResult = appData.visits.first { calendar.isDate($0.date, inSameDayAs: oldDate) }
        let recentVisitResult = appData.visits.first { calendar.isDate($0.date, inSameDayAs: recentDate) }
        
        // Old visit should be unchanged (2 events)
        #expect(oldVisitResult?.events.count == 2)
        
        // Recent visit should be repaired (1 event)
        #expect(recentVisitResult?.events.count == 1)
    }
    
    @Test("Repair without date filter processes all visits")
    @MainActor
    func testRepairWithoutDateFilterProcessesAll() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let calendar = Calendar.current
        
        // Create old visit (60 days ago)
        let oldDate = calendar.date(byAdding: .day, value: -60, to: Date())!
        let oldEvent1 = OfficeEvent(
            entryTime: oldDate,
            exitTime: oldDate.addingTimeInterval(3600)
        )
        let oldEvent2 = OfficeEvent(
            entryTime: oldDate.addingTimeInterval(4200),
            exitTime: oldDate.addingTimeInterval(7200)
        )
        let oldVisit = OfficeVisit(
            date: oldDate,
            events: [oldEvent1, oldEvent2],
            coordinate: testLocation
        )
        
        // Create recent visit
        let recentDate = Date()
        let recentEvent1 = OfficeEvent(
            entryTime: recentDate,
            exitTime: recentDate.addingTimeInterval(3600)
        )
        let recentEvent2 = OfficeEvent(
            entryTime: recentDate.addingTimeInterval(4200),
            exitTime: recentDate.addingTimeInterval(7200)
        )
        let recentVisit = OfficeVisit(
            date: recentDate,
            events: [recentEvent1, recentEvent2],
            coordinate: testLocation
        )
        
        appData.visits = [oldVisit, recentVisit]
        
        // Run repair without date filter
        let repairedCount = appData.repairHistoricalSessions(dateFilter: nil)
        
        // Should repair both visits
        #expect(repairedCount == 2)
        #expect(appData.visits.allSatisfy { $0.events.count == 1 })
    }
    
    // MARK: - Debouncing Tests
    
    @Test("Debouncing prevents repeated repairs within 1 hour", .disabled("Needs investigation - debouncing logic may need adjustment"))
    @MainActor
    func testDebouncingPreventsRepeatedRepairs() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Create a visit needing repair
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
        
        // First repair via foreground trigger
        appData.triggerForegroundRepair()
        
        // Verify repair happened
        #expect(appData.visits[0].events.count == 1)
        
        // Add another broken visit
        let newDate = baseDate.addingTimeInterval(86400) // Next day
        let newEvent1 = OfficeEvent(
            entryTime: newDate,
            exitTime: newDate.addingTimeInterval(3600)
        )
        let newEvent2 = OfficeEvent(
            entryTime: newDate.addingTimeInterval(4200),
            exitTime: newDate.addingTimeInterval(7200)
        )
        let newVisit = OfficeVisit(
            date: newDate,
            events: [newEvent1, newEvent2],
            coordinate: testLocation
        )
        appData.visits.append(newVisit)
        
        // Second repair immediately after (should be debounced)
        appData.triggerForegroundRepair()
        
        // New visit should NOT be repaired due to debouncing
        let newVisitResult = appData.visits.first { $0.id == newVisit.id }
        #expect(newVisitResult?.events.count == 2) // Still 2 events (not repaired)
    }
    
    @Test("Repair runs after debounce interval expires", .disabled("Needs investigation - test timing may need adjustment"))
    @MainActor
    func testRepairRunsAfterDebounceExpires() throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Create initial visit
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
        
        // First repair
        appData.triggerForegroundRepair()
        #expect(appData.visits[0].events.count == 1)
        
        // Manually set last repair time to more than 1 hour ago
        let moreThanOneHourAgo = Date().addingTimeInterval(-3700) // 61 minutes ago
        appData.sharedUserDefaults.set(moreThanOneHourAgo, forKey: "HistoricalSessionRepairLastRun")
        
        // Add new broken visit
        let newDate = baseDate.addingTimeInterval(86400)
        let newEvent1 = OfficeEvent(
            entryTime: newDate,
            exitTime: newDate.addingTimeInterval(3600)
        )
        let newEvent2 = OfficeEvent(
            entryTime: newDate.addingTimeInterval(4200),
            exitTime: newDate.addingTimeInterval(7200)
        )
        let newVisit = OfficeVisit(
            date: newDate,
            events: [newEvent1, newEvent2],
            coordinate: testLocation
        )
        appData.visits.append(newVisit)
        
        // Repair should run since debounce expired
        appData.triggerForegroundRepair()
        
        // New visit should be repaired
        let newVisitResult = appData.visits.first { $0.id == newVisit.id }
        #expect(newVisitResult?.events.count == 1) // Repaired
    }
}
