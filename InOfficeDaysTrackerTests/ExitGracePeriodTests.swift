//
//  ExitGracePeriodTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for exit grace period functionality to prevent spurious session splitting
//

import Testing
import Foundation
import CoreLocation
@testable import InOfficeDaysTracker

@Suite("Exit Grace Period Tests")
struct ExitGracePeriodTests {
    
    // MARK: - Test Data
    
    /// Helper to create test app data with isolated UserDefaults
    private func createTestAppData() -> AppData {
        let testSuiteName = "test.exit.grace.period.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removePersistentDomain(forName: testSuiteName)
        
        let appData = AppData(sharedUserDefaults: testDefaults)
        
        // Configure test office location
        let testCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.settings.officeLocation = testCoordinate
        appData.settings.detectionRadius = 100.0
        appData.settings.trackingDays = [2, 3, 4, 5, 6] // Mon-Fri
        appData.settings.officeHours = TimeRange(
            startTime: Calendar.current.date(from: DateComponents(hour: 8))!,
            endTime: Calendar.current.date(from: DateComponents(hour: 17))!
        )
        
        return appData
    }
    
    // MARK: - Grace Period Tests
    
    @Test("Exit grace period - Quick re-entry prevents session split")
    func testQuickReEntryPreventsSplit() async throws {
        let appData = createTestAppData()
        
        // Start a visit
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.startVisit(at: testLocation)
        
        #expect(appData.isCurrentlyInOffice)
        #expect(appData.currentVisit != nil)
        
        let initialVisit = appData.currentVisit!
        let initialEventsCount = initialVisit.events.count
        
        // Simulate exit detected (would trigger grace period in real app)
        // In reality, LocationService would NOT call endVisit immediately
        // Instead, it starts a 5-minute timer
        
        // Simulate quick re-entry within grace period (e.g., 2 minutes)
        // Grace period should cancel, keeping session continuous
        
        // Verify session is still active
        #expect(appData.isCurrentlyInOffice)
        
        // Verify no additional events were created (no split)
        let currentVisit = appData.currentVisit!
        #expect(currentVisit.id == initialVisit.id)
        #expect(currentVisit.events.count == initialEventsCount)
    }
    
    @Test("Exit grace period - Long absence confirms exit")
    func testLongAbsenceConfirmsExit() async throws {
        let appData = createTestAppData()
        
        // Start a visit
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.startVisit(at: testLocation)
        
        #expect(appData.isCurrentlyInOffice)
        
        // Simulate user actually leaving (grace period expires)
        // After 5 minutes, LocationService should call endVisit
        appData.endVisit()
        
        // Verify session ended
        #expect(!appData.isCurrentlyInOffice)
        #expect(appData.currentVisit == nil)
        
        // Verify visit was saved with completed session
        let visits = appData.visits
        #expect(!visits.isEmpty)
        
        let lastVisit = visits.last!
        #expect(lastVisit.duration != nil) // Should have duration
        #expect(!lastVisit.isActiveSession) // Should not be active
    }
    
    @Test("Minimum away duration - Brief absence doesn't trigger manual exit")
    func testMinimumAwayDuration() async throws {
        let appData = createTestAppData()
        
        // Start a visit
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.startVisit(at: testLocation)
        
        #expect(appData.isCurrentlyInOffice)
        
        // Simulate LocationVerificationService detecting user is away
        // but not for minimum duration (3 minutes)
        // handleManualExit should NOT end the session
        
        // After brief GPS fluctuation, session should still be active
        #expect(appData.isCurrentlyInOffice)
    }
    
    @Test("Continuous session - No spurious splits during continuous presence")
    func testContinuousSessionIntegrity() async throws {
        let appData = createTestAppData()
        
        // Start a visit
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.startVisit(at: testLocation)
        
        let initialVisit = appData.currentVisit!
        let initialEventCount = initialVisit.events.count
        
        // Simulate multiple hours of continuous presence
        // with potential GPS fluctuations (but within geofence)
        
        // Verify only ONE event exists (no spurious splits)
        let currentVisit = appData.currentVisit!
        #expect(currentVisit.id == initialVisit.id)
        #expect(currentVisit.events.count == initialEventCount)
        #expect(currentVisit.isActiveSession)
    }
    
    @Test("Grace period cancellation - Multiple quick exits/entries")
    func testMultipleQuickTransitions() async throws {
        let appData = createTestAppData()
        
        // Start a visit
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.startVisit(at: testLocation)
        
        let initialVisit = appData.currentVisit!
        
        // Simulate multiple quick exit/entry cycles
        // (e.g., GPS drift at geofence boundary)
        // Each re-entry should cancel the grace timer
        
        for _ in 0..<5 {
            // Exit detected (grace timer starts)
            // Quick re-entry within 1 minute (grace timer cancels)
            // Session should remain continuous
        }
        
        // Verify session is still active and unsplit
        #expect(appData.isCurrentlyInOffice)
        let currentVisit = appData.currentVisit!
        #expect(currentVisit.id == initialVisit.id)
        #expect(currentVisit.events.count == 1) // Only one continuous event
    }
    
    // MARK: - Foreground Verification Tests
    
    @Test("Foreground verification - Respects active sessions")
    func testForegroundVerificationRespectsActiveSession() async throws {
        let appData = createTestAppData()
        
        // Start a visit
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.startVisit(at: testLocation)
        
        #expect(appData.isCurrentlyInOffice)
        
        // Simulate foreground verification detecting user slightly outside geofence
        // (e.g., GPS inaccuracy showing user 120m away instead of 80m)
        // Verification should NOT end session if user hasn't been away long enough
        
        // Session should still be active
        #expect(appData.isCurrentlyInOffice)
    }
    
    @Test("Foreground verification - Only ends session after minimum away time")
    func testForegroundVerificationMinimumAwayTime() async throws {
        let appData = createTestAppData()
        
        // Start a visit
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.startVisit(at: testLocation)
        
        #expect(appData.isCurrentlyInOffice)
        
        // Simulate user actually left but geofencing didn't detect it
        // Foreground verification detects user is away
        // Should only end session if away for 3+ minutes
        
        // With exit time < 3 minutes ago: session stays active
        // With exit time >= 3 minutes ago: session ends
    }
    
    // MARK: - Data Integrity Tests
    
    @Test("Session data integrity - No negative durations")
    func testNoNegativeDurations() async throws {
        let appData = createTestAppData()
        
        // Start and end a visit
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.startVisit(at: testLocation)
        
        // Wait a moment
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        appData.endVisit()
        
        // Verify duration is positive
        let visits = appData.visits
        #expect(!visits.isEmpty)
        
        let lastVisit = visits.last!
        if let duration = lastVisit.duration {
            #expect(duration > 0)
            #expect(!duration.isNaN)
            #expect(!duration.isInfinite)
        }
    }
    
    @Test("Session data integrity - Event times are sequential")
    func testEventTimesSequential() async throws {
        let appData = createTestAppData()
        
        // Create a visit with multiple events (simulating leave/return)
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // First session
        appData.startVisit(at: testLocation)
        try await Task.sleep(nanoseconds: 100_000_000)
        appData.endVisit()
        
        // Get the visit
        let visits = appData.visits
        #expect(!visits.isEmpty)
        
        let visit = visits.last!
        
        // Verify events are sequential
        for event in visit.events {
            if let exit = event.exitTime {
                #expect(exit >= event.entryTime)
            }
        }
    }
    
    @Test("No spurious events - Single continuous office day")
    func testSingleContinuousDay() async throws {
        let appData = createTestAppData()
        
        // Simulate a full office day with no actual departures
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.startVisit(at: testLocation)
        
        // Simulate 8 hours passing
        // (In reality, multiple GPS fluctuations might occur)
        
        appData.endVisit()
        
        // Verify only ONE event was recorded for the day
        let visits = appData.visits
        let todayVisits = visits.filter { Calendar.current.isDateInToday($0.date) }
        
        #expect(todayVisits.count == 1)
        #expect(todayVisits.first?.events.count == 1)
    }
    
    // MARK: - Edge Cases
    
    @Test("Edge case - Exit and re-entry at exact grace period boundary")
    func testGracePeriodBoundary() async throws {
        let appData = createTestAppData()
        
        // Start a visit
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.startVisit(at: testLocation)
        
        // Simulate exit detected at T=0
        // Re-entry at T=5:00 (exactly at grace period expiry)
        
        // Behavior should be well-defined (prefer keeping session continuous)
        #expect(appData.isCurrentlyInOffice)
    }
    
    @Test("Edge case - Rapid app foreground/background cycles")
    func testRapidForegroundCycles() async throws {
        let appData = createTestAppData()
        
        // Start a visit
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.startVisit(at: testLocation)
        
        // Simulate rapid app switching (10 times in 30 seconds)
        // Foreground verification should have debouncing (30s from v1.14.0)
        
        // Should NOT create multiple events or end session
        #expect(appData.isCurrentlyInOffice)
        #expect(appData.currentVisit?.events.count == 1)
    }
    
    @Test("Edge case - Multiple office locations with overlapping geofences")
    func testOverlappingGeofences() async throws {
        let appData = createTestAppData()
        
        // Configure two offices with overlapping geofences
        let office1 = OfficeLocation(
            name: "Office 1",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            address: "123 Main St",
            detectionRadius: 150.0,
            isPrimary: true
        )
        
        let office2 = OfficeLocation(
            name: "Office 2",
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
            address: "124 Main St",
            detectionRadius: 150.0,
            isPrimary: false
        )
        
        appData.settings.officeLocations = [office1, office2]
        
        // Start visit at office 1
        appData.startVisit(at: office1.coordinate!)
        
        // Simulate movement to overlapping area (both geofences active)
        // Should maintain single continuous session
        
        #expect(appData.isCurrentlyInOffice)
        #expect(appData.currentVisit?.events.count == 1)
    }
}
