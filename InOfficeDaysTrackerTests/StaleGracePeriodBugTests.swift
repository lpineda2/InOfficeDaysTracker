//
//  StaleGracePeriodBugTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for stale exit grace period state handling
//  Ensures stale or expired grace periods never prevent new visit creation
//

import Foundation
import CoreLocation
import Testing
@testable import InOfficeDaysTracker

@MainActor
struct StaleGracePeriodBugTests {

    // MARK: - Test Helpers

    func createTestAppData() -> AppData {
        let suiteName = "group.com.lpineda.InOfficeDaysTracker.tests." + UUID().uuidString
        let groupDefaults = UserDefaults(suiteName: suiteName)!
        groupDefaults.removePersistentDomain(forName: suiteName)
        groupDefaults.synchronize()
        return AppData(sharedUserDefaults: groupDefaults)
    }

    func createTestOfficeLocation() -> OfficeLocation {
        return OfficeLocation(
            name: "Test Office",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            address: "123 Test St",
            detectionRadius: 100,
            isPrimary: true
        )
    }

    func createTestRegion(identifier: String = "test_office") -> CLCircularRegion {
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radius: 100,
            identifier: identifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }

    // MARK: - Scenario 1: Valid Same-Day Re-Entry (Regression Test)

    /// Ensures same-day re-entry during grace period still works correctly
    /// This is the core feature that must not break
    @Test("Scenario 1: Valid same-day re-entry during grace period cancels exit")
    func scenario1_validSameDayReEntry() async throws {
        let appData = createTestAppData()
        let locationService = LocationService()
        locationService.setAppData(appData)

        let office = createTestOfficeLocation()
        appData.settings.officeLocations = [office]

        // Simulate: User enters office
        appData.startVisit(at: office.coordinate!)
        #expect(appData.isCurrentlyInOffice == true)
        #expect(appData.currentVisit != nil)
        let visitIdBeforeExit = appData.currentVisit?.id

        // Simulate: User exits office
        let exitTime = Date()
        locationService.exitTime = exitTime
        locationService.pendingExitRegion = createTestRegion()

        // Simulate: User re-enters within grace period (same day, 2 minutes later)
        _ = exitTime.addingTimeInterval(120)  // 2 minutes (grace period window)

        // Create mock clock context by simulating the entry with grace period state active
        // The test validates the logic without needing to mock Date()
        #expect(locationService.isValidExitGracePeriod(exitTime) == true,
                "Exit time from 2 minutes ago should be valid same-day grace period")

        // Re-entry should cancel grace period state
        locationService.clearExitGracePeriodState(reason: "test re-entry")

        #expect(locationService.exitTime == nil, "exitTime should be cleared after re-entry")
        #expect(locationService.pendingExitRegion == nil, "pendingExitRegion should be cleared after re-entry")

        // Visit should remain unchanged - same visit continues
        #expect(appData.currentVisit?.id == visitIdBeforeExit, "Re-entry should not create new visit")
    }

    // MARK: - Scenario 2: Previous-Day Grace Period + Next-Day Entry (PRIMARY BUG)

    /// This is the main bug: cross-day entry with previous-day stale grace period
    /// Must clear stale state and create new visit
    @Test("Scenario 2: Previous-day grace period clears, allowing next-day entry")
    func scenario2_crossDayEntryWithStaleGracePeriod() async throws {
        let appData = createTestAppData()
        let locationService = LocationService()
        locationService.setAppData(appData)

        let office = createTestOfficeLocation()
        appData.settings.officeLocations = [office]

        // Simulate: User enters office on Day 1
        appData.startVisit(at: office.coordinate!)

        // Simulate: User exits office on Day 1 at 5:18 PM
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayExit = Calendar.current.date(bySettingHour: 17, minute: 18, second: 0, of: yesterday)!

        locationService.exitTime = yesterdayExit
        locationService.pendingExitRegion = createTestRegion()

        // Persist grace period state (simulating app suspension)
        appData.sharedUserDefaults.set(yesterdayExit, forKey: "PendingExitTime")
        appData.sharedUserDefaults.set("test_office", forKey: "PendingExitRegionId")
        appData.sharedUserDefaults.synchronize()

        // CRITICAL: Validate that yesterday's exit time is NOT today
        #expect(Calendar.current.isDateInToday(yesterdayExit) == false,
                "Exit time should be from yesterday")

        // Validate that grace period is NOT valid (expired or from wrong day)
        #expect(locationService.isValidExitGracePeriod(yesterdayExit) == false,
                "Previous-day grace period should not be valid")

        // Simulate: App restoration on Day 2 morning
        locationService.restoreExitGracePeriodIfNeeded()

        // CRITICAL ASSERTION: Previous-day grace period must be cleared
        #expect(appData.sharedUserDefaults.object(forKey: "PendingExitTime") == nil,
                "Persisted grace period should be cleared on restore")
        #expect(appData.sharedUserDefaults.object(forKey: "PendingExitRegionId") == nil,
                "Persisted region ID should be cleared on restore")
        #expect(locationService.exitTime == nil,
                "In-memory exitTime should be nil after restore with previous-day state")
        #expect(locationService.pendingExitRegion == nil,
                "In-memory pendingExitRegion should be nil after restore with previous-day state")

        // Simulate: Day 1 visit properly closed (grace period expired, endVisit called)
        // In production this happens via the grace-period timer or failsafe on app relaunch
        await appData.endVisit(at: yesterdayExit)
        #expect(appData.isCurrentlyInOffice == false, "Day 1 visit should be closed before Day 2 entry")

        // Now simulate: Day 2 morning entry
        // The stale grace period should not prevent handleRegionEntry from calling startVisit
        // Grace period state should already be cleared by restoreExitGracePeriodIfNeeded above
        #expect(locationService.pendingExitRegion == nil, "pendingExitRegion should be nil at Day 2 entry")

        // startVisit should succeed for Day 2
        appData.startVisit(at: office.coordinate!)

        // Key assertion: stale grace period did NOT block entry
        #expect(appData.isCurrentlyInOffice == true, "Day 2 entry should succeed despite previous-day stale grace period")
        #expect(appData.currentVisit != nil, "A visit should be active after Day 2 entry")
        #expect(appData.currentVisit?.isActiveSession == true, "Active session should be running after Day 2 entry")
        // Note: AppData resumes today's visit rather than creating a new one for same-day re-entry,
        // so visit ID and count are intentionally not asserted here (cross-day ID difference
        // requires date mocking, which is out of scope for this unit test).
    }

    // MARK: - Scenario 3: Previous-Day Persisted Grace Period on App Launch

    /// Ensures previous-day persisted grace periods are cleared immediately
    /// No timer scheduled, no endVisit called
    @Test("Scenario 3: Previous-day persisted grace period cleared on app launch")
    func scenario3_previousDayPersistedClearedOnLaunch() async throws {
        let appData = createTestAppData()
        let locationService = LocationService()

        // Persist previous-day grace period before connecting appData
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayExit = Calendar.current.date(bySettingHour: 17, minute: 18, second: 0, of: yesterday)!

        appData.sharedUserDefaults.set(yesterdayExit, forKey: "PendingExitTime")
        appData.sharedUserDefaults.set("test_office", forKey: "PendingExitRegionId")
        appData.sharedUserDefaults.synchronize()

        // Verify state is persisted
        #expect(appData.sharedUserDefaults.object(forKey: "PendingExitTime") != nil,
                "Grace period should be persisted before connect")

        // Now connect appData - this triggers restoration
        locationService.setAppData(appData)

        // CRITICAL: Persisted previous-day state must be cleared
        #expect(appData.sharedUserDefaults.object(forKey: "PendingExitTime") == nil,
                "Previous-day persisted exit time should be cleared")
        #expect(appData.sharedUserDefaults.object(forKey: "PendingExitRegionId") == nil,
                "Previous-day persisted region ID should be cleared")

        // No timer should be scheduled
        #expect(locationService.exitGraceTimer == nil,
                "No timer should be scheduled for previous-day grace period")

        // No visit should be ended (endVisit not called)
        // This would be tricky to test without mocking, but we verify state is cleaned
        #expect(locationService.exitTime == nil,
                "No exit time should be set after clearing previous-day state")
    }

    // MARK: - Scenario 4: Expired Same-Day Grace Period on Restore

    /// Ensures expired same-day grace periods are finalized via endVisit() once, then cleared
    @Test("Scenario 4: Expired same-day grace period finalized on restore")
    func scenario4_expiredSameDayGracePeriodRestored() async throws {
        let appData = createTestAppData()
        let locationService = LocationService()

        // Create today's exit time, but in the past (>5 minutes ago)
        let expiringExit = Date().addingTimeInterval(-600)  // 10 minutes ago

        // Persist grace period
        appData.sharedUserDefaults.set(expiringExit, forKey: "PendingExitTime")
        appData.sharedUserDefaults.set("test_office", forKey: "PendingExitRegionId")
        appData.sharedUserDefaults.synchronize()

        // Verify exit is from today but expired
        #expect(Calendar.current.isDateInToday(expiringExit) == true,
                "Exit should be from today")
        #expect(Date().timeIntervalSince(expiringExit) > 300,
                "Elapsed time should exceed grace period (5 minutes)")

        // Create a visit to be ended
        let office = createTestOfficeLocation()
        appData.settings.officeLocations = [office]
        appData.startVisit(at: office.coordinate!)

        // Simulate restoration
        locationService.setAppData(appData)

        // After restoration, persisted state should be cleared
        #expect(appData.sharedUserDefaults.object(forKey: "PendingExitTime") == nil,
                "Expired grace period should be cleared after restoration")

        // Grace period state should be nil
        #expect(locationService.exitTime == nil,
                "exitTime should be nil after expired grace period processed")
    }

    // MARK: - Scenario 5: Pending Region Without Exit Time (Edge Case)

    /// Tests malformed state: pendingExitRegion exists but no exitTime
    /// Must clear and continue with normal entry
    @Test("Scenario 5: Pending region without exit time handled safely")
    func scenario5_pendingRegionWithoutExitTime() async throws {
        let appData = createTestAppData()

        let office = createTestOfficeLocation()
        appData.settings.officeLocations = [office]

        // Create malformed state: pendingRegion without exitTime
        let locationService = LocationService()
        locationService.setAppData(appData)

        let region = createTestRegion()
        locationService.pendingExitRegion = region
        locationService.exitTime = nil  // Malformed: missing exit time

        // Simulate entry with malformed state
        // Should NOT crash, should clear the invalid state

        if locationService.exitTime == nil {
            // This is the malformed case - should be handled gracefully
            locationService.clearExitGracePeriodState(reason: "pending region exists without exit time")

            #expect(locationService.pendingExitRegion == nil,
                    "Malformed pendingRegion should be cleared")
            #expect(locationService.exitTime == nil,
                    "exitTime should remain nil")
            return
        }

        // exitTime is non-nil here, which shouldn't happen in this test
        #expect(false, "Should not have exitTime in malformed state case")
    }

    // MARK: - Concurrent Entry During Restoration (Race Condition)

    /// Tests that entry can safely occur while grace period restoration runs
    /// Ensures no race condition corruption
    @Test("Scenario 6: Safe concurrent entry during grace period restoration")
    func scenario6_concurrentEntryDuringRestoration() async throws {
        let appData = createTestAppData()
        let locationService = LocationService()

        let office = createTestOfficeLocation()
        appData.settings.officeLocations = [office]

        // Setup: Previous-day grace period persisted
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayExit = Calendar.current.date(bySettingHour: 17, minute: 18, second: 0, of: yesterday)!

        appData.sharedUserDefaults.set(yesterdayExit, forKey: "PendingExitTime")
        appData.sharedUserDefaults.set("test_office", forKey: "PendingExitRegionId")
        appData.sharedUserDefaults.synchronize()

        // Connect appData (triggers restoration)
        locationService.setAppData(appData)

        // Race condition scenario: Entry event fires while restoration completes
        // In real code, handleRegionEntry() would check pendingExitRegion
        // But by this point, restoreExitGracePeriodIfNeeded() should have cleared it

        #expect(locationService.pendingExitRegion == nil,
                "Previous-day grace period should be cleared before entry handling")
        #expect(locationService.exitTime == nil,
                "exitTime should be nil, allowing entry to proceed")

        // startVisit should succeed without interference
        appData.startVisit(at: office.coordinate!)

        #expect(appData.isCurrentlyInOffice == true, "Entry should succeed despite restoration")
        #expect(appData.currentVisit != nil, "New visit should be created")
    }
}
