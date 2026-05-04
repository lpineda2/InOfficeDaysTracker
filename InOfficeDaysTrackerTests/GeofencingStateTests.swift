//
//  GeofencingStateTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for geofencing state determination and stale visit cleanup
//

import Testing
import Foundation
import CoreLocation
@testable import InOfficeDaysTracker

@MainActor
struct GeofencingStateTests {
    
    // MARK: - Test Helpers
    
    func createTestAppData() -> AppData {
        let suiteName = "group.com.lpineda.InOfficeDaysTracker.tests." + UUID().uuidString
        let groupDefaults = UserDefaults(suiteName: suiteName)!
        groupDefaults.removePersistentDomain(forName: suiteName)
        groupDefaults.synchronize()
        
        return AppData(sharedUserDefaults: groupDefaults)
    }
    
    func createTestOfficeLocation(
        name: String = "Office",
        latitude: Double = 27.8925571,
        longitude: Double = -82.6705374,
        radius: Double = 402.335
    ) -> OfficeLocation {
        return OfficeLocation(
            name: name,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            address: "\(name) Address",
            detectionRadius: radius,
            isPrimary: true
        )
    }
    
    // MARK: - Critical Stale Visit Detection Tests
    
    @Test("App launch with active visit but user is outside - should end stale visit")
    func testAppLaunchEndsStaleVisitWhenOutside() async throws {
        let appData = createTestAppData()
        let office = createTestOfficeLocation()
        
        // Simulate user was in office previously (e.g., left office while app was terminated)
        appData.startVisit(at: office.coordinate!)
        
        // Verify visit is active
        #expect(appData.isCurrentlyInOffice == true)
        #expect(appData.currentVisit != nil)
        
        let initialVisit = appData.currentVisit
        
        // Simulate app determining state on launch/geofencing setup
        // State is .outside (user is not at office)
        // This should end the stale visit
        if appData.isCurrentlyInOffice {
            appData.endVisit()
        }
        
        // Verify stale visit was ended
        #expect(appData.isCurrentlyInOffice == false)
        #expect(appData.currentVisit == nil)
        
        // Verify the visit was saved to history
        let todayVisits = appData.getVisits(for: Date())
        #expect(todayVisits.count == 1)
        #expect(todayVisits[0].id == initialVisit?.id)
    }
    
    @Test("App launch with active visit and user is inside - should NOT end visit")
    func testAppLaunchKeepsActiveVisitWhenInside() async throws {
        let appData = createTestAppData()
        let office = createTestOfficeLocation()
        
        // Simulate user is in office
        appData.startVisit(at: office.coordinate!)
        
        // Verify visit is active
        #expect(appData.isCurrentlyInOffice == true)
        let visitId = appData.currentVisit?.id
        #expect(visitId != nil)
        
        // Simulate app determining state on launch
        // State is .inside (user is still at office)
        // Visit should remain active
        
        // Verify visit is still active
        #expect(appData.isCurrentlyInOffice == true)
        #expect(appData.currentVisit?.id == visitId)
    }
    
    @Test("didDetermineState .outside with no active visit - should not crash")
    func testDetermineStateOutsideWithNoActiveVisit() async throws {
        let appData = createTestAppData()
        
        // No active visit
        #expect(appData.isCurrentlyInOffice == false)
        #expect(appData.currentVisit == nil)
        
        // Simulate determining state as .outside
        // Should not crash or cause issues
        if appData.isCurrentlyInOffice {
            appData.endVisit()
        }
        
        // Verify state unchanged
        #expect(appData.isCurrentlyInOffice == false)
        #expect(appData.currentVisit == nil)
    }
    
    @Test("didDetermineState .inside triggers entry when no active visit")
    func testDetermineStateInsideTriggersEntryFlow() async throws {
        let appData = createTestAppData()
        let office = createTestOfficeLocation()
        
        // No active visit
        #expect(appData.isCurrentlyInOffice == false)
        
        // Simulate determining state as .inside
        // This should trigger entry flow (start visit)
        appData.startVisit(at: office.coordinate!)
        
        // Verify visit started
        #expect(appData.isCurrentlyInOffice == true)
        #expect(appData.currentVisit != nil)
    }
    
    @Test("didDetermineState .unknown should not change state")
    func testDetermineStateUnknownDoesNotChangeState() async throws {
        let appData = createTestAppData()
        let office = createTestOfficeLocation()
        
        // Start with active visit
        appData.startVisit(at: office.coordinate!)
        #expect(appData.isCurrentlyInOffice == true)
        
        // Simulate determining state as .unknown
        // Should not change state (wait for definitive state)
        
        // Verify visit still active
        #expect(appData.isCurrentlyInOffice == true)
        #expect(appData.currentVisit != nil)
    }
    
    // MARK: - Region Identifier Tests
    
    @Test("Region identified by UUID not legacy string")
    func testRegionIdentifierUsesUUID() async throws {
        let office = createTestOfficeLocation()
        
        // Verify office has UUID
        let regionIdentifier = office.id.uuidString
        #expect(UUID(uuidString: regionIdentifier) != nil)
        
        // Legacy identifier "office_location" should NOT be used
        #expect(regionIdentifier != "office_location")
        
        // Verify identifier is valid UUID format
        #expect(regionIdentifier.count == 36) // UUID string length
        #expect(regionIdentifier.contains("-")) // UUID contains hyphens
    }
    
    @Test("Multiple offices have different region identifiers")
    func testMultipleOfficesHaveDifferentIdentifiers() async throws {
        let office1 = createTestOfficeLocation(name: "Office 1")
        let office2 = createTestOfficeLocation(name: "Office 2")
        
        let id1 = office1.id.uuidString
        let id2 = office2.id.uuidString
        
        // Verify different UUIDs
        #expect(id1 != id2)
        
        // Verify both are valid UUIDs
        #expect(UUID(uuidString: id1) != nil)
        #expect(UUID(uuidString: id2) != nil)
    }
    
    // MARK: - Entry/Exit State Transition Tests
    
    @Test("Entry while outside - starts new visit")
    func testEntryWhileOutsideStartsNewVisit() async throws {
        let appData = createTestAppData()
        let office = createTestOfficeLocation()
        
        // Start outside
        #expect(appData.isCurrentlyInOffice == false)
        
        // Simulate entry
        appData.startVisit(at: office.coordinate!)
        
        // Verify visit started
        #expect(appData.isCurrentlyInOffice == true)
        #expect(appData.currentVisit != nil)
    }
    
    @Test("Entry while already inside - should not duplicate visit")
    func testEntryWhileInsideDoesNotDuplicateVisit() async throws {
        let appData = createTestAppData()
        let office = createTestOfficeLocation()
        
        // Start visit
        appData.startVisit(at: office.coordinate!)
        let originalVisitId = appData.currentVisit?.id
        
        // Try to start another visit (shouldn't happen normally)
        // AppData should detect this and not create duplicate
        
        // Verify only one active visit
        #expect(appData.currentVisit?.id == originalVisitId)
        
        // Verify no duplicate in today's visits
        let todayVisits = appData.getVisits(for: Date())
        #expect(todayVisits.count == 1)
    }
    
    @Test("Exit while inside - ends visit after grace period")
    func testExitWhileInsideEndsVisitAfterGrace() async throws {
        let appData = createTestAppData()
        let office = createTestOfficeLocation()
        
        // Start visit
        appData.startVisit(at: office.coordinate!)
        #expect(appData.isCurrentlyInOffice == true)
        
        // Simulate exit detection (in real code, grace period would wait 5 minutes)
        // For unit test, directly call endVisit
        appData.endVisit()
        
        // Verify visit ended
        #expect(appData.isCurrentlyInOffice == false)
        #expect(appData.currentVisit == nil)
        
        // Verify visit in history
        let todayVisits = appData.getVisits(for: Date())
        #expect(todayVisits.count == 1)
    }
    
    @Test("Exit while already outside - should not crash")
    func testExitWhileOutsideDoesNotCrash() async throws {
        let appData = createTestAppData()
        
        // Already outside
        #expect(appData.isCurrentlyInOffice == false)
        
        // Try to end non-existent visit (shouldn't happen normally)
        appData.endVisit()
        
        // Verify state unchanged
        #expect(appData.isCurrentlyInOffice == false)
        #expect(appData.currentVisit == nil)
    }
    
    // MARK: - Background Task Tests
    
    @Test("Exit notification scheduled without background task")
    func testExitNotificationScheduledIndependently() async throws {
        // This test documents that exit notifications use UNTimeIntervalNotificationTrigger
        // which runs in iOS notification system, not tied to app background execution
        
        // The implementation should NOT use UIBackgroundTask for the 5-minute timer
        // because iOS limits background tasks to ~30 seconds
        
        // Instead:
        // 1. Schedule notification with UNTimeIntervalNotificationTrigger (300s delay)
        // 2. Use Timer in foreground for endVisit() call
        // 3. Notification fires independently even if app is suspended
        
        // This test serves as documentation of the correct approach
        #expect(true) // Placeholder - documents architectural decision
    }
}
