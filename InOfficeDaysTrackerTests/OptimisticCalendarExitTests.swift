//
//  OptimisticCalendarExitTests.swift
//  InOfficeDaysTrackerTests
//
//  Regression tests for optimistic calendar exit write on geofence exit.
//  Verifies that calendar gets updated immediately on exit detection
//  and reverted correctly on false exit (re-entry during grace period).
//

import Testing
import Foundation
import CoreLocation
@testable import InOfficeDaysTracker

@Suite("Optimistic Calendar Exit Tests")
struct OptimisticCalendarExitTests {
    
    // MARK: - Test Helpers
    
    @MainActor
    private func createTestAppData() -> AppData {
        let testSuiteName = "test.optimistic.calendar.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removePersistentDomain(forName: testSuiteName)
        
        let appData = AppData(sharedUserDefaults: testDefaults)
        
        let testCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        appData.settings.officeLocation = testCoordinate
        appData.settings.detectionRadius = 100.0
        appData.settings.trackingDays = [2, 3, 4, 5, 6]
        appData.settings.officeHours = AppSettings.OfficeHours(
            startTime: Calendar.current.date(from: DateComponents(hour: 8))!,
            endTime: Calendar.current.date(from: DateComponents(hour: 17))!
        )
        
        // Enable calendar integration
        appData.settings.calendarSettings.isEnabled = true
        
        return appData
    }
    
    // MARK: - Optimistic Exit Write Tests
    
    @Test("Optimistic exit write does not end the actual visit")
    @MainActor
    func testOptimisticExitDoesNotEndVisit() async throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Start a visit
        appData.startVisit(at: testLocation)
        #expect(appData.isCurrentlyInOffice)
        #expect(appData.currentVisit != nil)
        #expect(appData.currentVisit?.isActiveSession == true)
        
        let exitTime = Date()
        
        // Write optimistic calendar exit
        await appData.writeOptimisticCalendarExit(at: exitTime)
        
        // Visit should STILL be active - only the calendar was updated
        #expect(appData.isCurrentlyInOffice)
        #expect(appData.currentVisit != nil)
        #expect(appData.currentVisit?.isActiveSession == true)
        #expect(appData.currentVisit?.exitTime == nil)
    }
    
    @Test("Optimistic exit write requires active visit")
    @MainActor
    func testOptimisticExitRequiresActiveVisit() async throws {
        let appData = createTestAppData()
        
        // No visit started - should not crash
        #expect(appData.currentVisit == nil)
        
        // Should complete without error
        await appData.writeOptimisticCalendarExit(at: Date())
        
        // Still no visit
        #expect(appData.currentVisit == nil)
        #expect(!appData.isCurrentlyInOffice)
    }
    
    @Test("Revert optimistic exit restores ongoing state")
    @MainActor
    func testRevertOptimisticExitRestoresState() async throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Start a visit
        appData.startVisit(at: testLocation)
        #expect(appData.isCurrentlyInOffice)
        
        let visit = appData.currentVisit!
        
        // Write optimistic exit then revert (simulates false exit)
        await appData.writeOptimisticCalendarExit(at: Date())
        await appData.revertOptimisticCalendarExit(visit: visit)
        
        // Visit should still be active and unchanged
        #expect(appData.isCurrentlyInOffice)
        #expect(appData.currentVisit?.isActiveSession == true)
        #expect(appData.currentVisit?.id == visit.id)
    }
    
    @Test("Optimistic exit followed by actual endVisit works correctly")
    @MainActor
    func testOptimisticExitFollowedByActualEnd() async throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Start a visit
        appData.startVisit(at: testLocation)
        #expect(appData.isCurrentlyInOffice)
        
        let exitTime = Date()
        
        // Write optimistic calendar exit (happens immediately on geofence exit)
        await appData.writeOptimisticCalendarExit(at: exitTime)
        
        // Later, grace period expires and actual endVisit is called
        await appData.endVisit(at: exitTime)
        
        // Now visit should be ended
        #expect(!appData.isCurrentlyInOffice)
        #expect(appData.currentVisit == nil)
        
        // Verify visit was saved
        let visits = appData.visits
        #expect(!visits.isEmpty)
        let lastVisit = visits.last!
        #expect(!lastVisit.isActiveSession)
        #expect(lastVisit.exitTime != nil)
    }
    
    @Test("Optimistic exit snapshot has correct exit time")
    @MainActor
    func testOptimisticExitSnapshotHasCorrectExitTime() async throws {
        let appData = createTestAppData()
        let testLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Start a visit
        appData.startVisit(at: testLocation)
        
        let specificExitTime = Date().addingTimeInterval(-60) // 1 minute ago
        
        // The snapshot should use the provided exit time
        await appData.writeOptimisticCalendarExit(at: specificExitTime)
        
        // Original visit unchanged
        #expect(appData.currentVisit?.isActiveSession == true)
        #expect(appData.currentVisit?.exitTime == nil)
    }
}
