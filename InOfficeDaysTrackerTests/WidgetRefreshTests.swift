//
//  WidgetRefreshTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests to verify widget refresh functionality and prevent sync issues
//

import Testing
import Foundation
import CoreLocation
@testable import InOfficeDaysTracker

@MainActor
struct WidgetRefreshTests {
    
    // MARK: - Test Setup Helper
    
    /// Creates a clean AppData instance for testing
    func createTestAppData() async -> AppData {
        // Create an isolated UserDefaults suite for this test run to avoid cross-test races
        let suiteName = "group.com.lpineda.InOfficeDaysTracker.tests." + UUID().uuidString
        let groupDefaults = UserDefaults(suiteName: suiteName)!

        // Remove any existing data in the suite just in case
        groupDefaults.removePersistentDomain(forName: suiteName)

        // Force synchronization and allow a short propagation window
        groupDefaults.synchronize()
        try? await Task.sleep(nanoseconds: 20_000_000) // 20ms

        let appData = AppData(sharedUserDefaults: groupDefaults)
        appData.visits = [] // Clear any existing visits
        appData.currentVisit = nil
        appData.isCurrentlyInOffice = false
        
        // Ensure the AppData's shared defaults are also synchronized
        appData.sharedUserDefaults.synchronize()
        
        return appData
    }
    
    /// Creates a test coordinate for San Francisco
    func testCoordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
    
    // MARK: - Widget Data Synchronization Tests
    
    @Test("Widget Sync - Office status persistence after entry")
    func testOfficeStatusPersistenceAfterEntry() async throws {
        let appData = await createTestAppData()
        let testCoord = testCoordinate()
        
        // Verify initial state
        #expect(appData.isCurrentlyInOffice == false)
        #expect(appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice") == false)
        
        // Start office visit
        appData.startVisit(at: testCoord)
        
        // Force synchronization (simulating what LocationService does)
        appData.sharedUserDefaults.synchronize()
        
        // Verify both in-memory and persisted state are updated
        #expect(appData.isCurrentlyInOffice == true)
        #expect(appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice") == true)
    }
    
    @Test("Widget Sync - Office status persistence after exit")
    func testOfficeStatusPersistenceAfterExit() async throws {
        let appData = await createTestAppData()
        let testCoord = testCoordinate()
        
        // Start office visit
        appData.startVisit(at: testCoord)
        #expect(appData.isCurrentlyInOffice == true)
        
        // End office visit  
        await appData.endVisit()
        
        // Force synchronization (simulating what LocationService does)
        appData.sharedUserDefaults.synchronize()
        
        // Verify both in-memory and persisted state are updated
        #expect(appData.isCurrentlyInOffice == false)
        #expect(appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice") == false)
    }
    
    @Test("Widget Sync - UserDefaults synchronization timing")
    func testUserDefaultsSynchronizationTiming() async throws {
        let appData = await createTestAppData()
        let testCoord = testCoordinate()
        
        // Test rapid state changes (like what might happen with location events)
        for i in 0..<5 {
            if i % 2 == 0 {
                appData.startVisit(at: testCoord)
                #expect(appData.isCurrentlyInOffice == true)
            } else {
                await appData.endVisit()
                #expect(appData.isCurrentlyInOffice == false)
            }
            
            // Force sync and verify persistence matches in-memory state
            appData.sharedUserDefaults.synchronize()
            let persistedStatus = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
            #expect(persistedStatus == appData.isCurrentlyInOffice)
        }
    }
    
    @Test("Widget Sync - Current visit persistence") 
    func testCurrentVisitPersistence() async throws {
        let appData = await createTestAppData()
        let testCoord = testCoordinate()
        
        // Ensure clean state by explicitly ending any existing visit
        if appData.isCurrentlyInOffice {
            await appData.endVisit()
        }
        appData.sharedUserDefaults.synchronize()
        
        // Verify no current visit initially
        #expect(appData.currentVisit == nil)
        
        // Start a new visit
        appData.startVisit(at: testCoord)
        let visitId = appData.currentVisit?.id
        
        // Force synchronization and allow a short propagation window
        appData.sharedUserDefaults.synchronize()
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Verify current visit is persisted
        #expect(appData.currentVisit != nil)
        let persistedVisitData = appData.sharedUserDefaults.data(forKey: "CurrentVisit")
        #expect(persistedVisitData != nil, "CurrentVisit should be persisted to UserDefaults")
        
        // Verify persisted visit can be decoded and matches
        if let data = persistedVisitData {
            let decodedVisit = try? JSONDecoder().decode(OfficeVisit.self, from: data)
            #expect(decodedVisit?.id == visitId, "Decoded visit ID should match original visit ID")
        }
        
        // End visit
        await appData.endVisit()
        appData.sharedUserDefaults.synchronize()
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Verify current visit is cleared from persistence
        #expect(appData.currentVisit == nil)
        let clearedVisitData = appData.sharedUserDefaults.data(forKey: "CurrentVisit")
        #expect(clearedVisitData == nil, "CurrentVisit should be cleared from UserDefaults after ending visit")
    }
    
    // MARK: - Widget Data Creation Tests
    
    @Test("Widget Data - Accurate office status reflection")
    func testWidgetDataOfficeStatusAccuracy() async throws {
        let appData = await createTestAppData()
        let testCoord = testCoordinate()
        
        // Test when not in office - check through UserDefaults directly
        let isAwayStatus = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        #expect(isAwayStatus == false)
        
        // Start office visit
        appData.startVisit(at: testCoord)
        appData.sharedUserDefaults.synchronize()
        
        // Test when in office - check through UserDefaults directly
        let isInOfficeStatus = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        #expect(isInOfficeStatus == true)
        
        // End office visit
        await appData.endVisit()
        appData.sharedUserDefaults.synchronize()
        
        // Test when away again - check through UserDefaults directly
        let isAfterExitStatus = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        #expect(isAfterExitStatus == false)
    }
    
    @Test("Widget Data - Proper UserDefaults synchronization timing")
    func testWidgetDataSynchronizationTiming() async throws {
        let appData = await createTestAppData()
        
        // Force a visit update
        appData.startVisit(at: testCoordinate())
        
        // Check that UserDefaults reflects the change
        let isInOfficeAfterStart = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        #expect(isInOfficeAfterStart == true)
        
        // End visit and verify
        await appData.endVisit()
        
        // UserDefaults should reflect the status change
        let isInOfficeAfterEnd = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        #expect(isInOfficeAfterEnd == false)
    }
    
    // MARK: - Location Service Integration Tests
    
    @Test("Location Integration - End visit updates all states")
    func testLocationIntegrationEndVisit() async throws {
        let appData = await createTestAppData()
        let locationService = LocationService()
        let testCoord = testCoordinate()
        
        // Set up location service with app data
        locationService.setAppData(appData)
        
        // Start a visit manually
        appData.startVisit(at: testCoord)
        #expect(appData.isCurrentlyInOffice == true)
        
        // Simulate location service ending the visit (like didExitRegion would do)
        await appData.endVisit()
        appData.sharedUserDefaults.synchronize()
        
        // Verify all states are consistent
        #expect(appData.isCurrentlyInOffice == false)
        #expect(appData.currentVisit == nil)
        #expect(appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice") == false)
        
        // Verify UserDefaults reflects the change  
        let finalStatus = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        #expect(finalStatus == false)
    }
    
    @Test("Location Integration - Multiple rapid state changes")
    func testLocationIntegrationRapidChanges() async throws {
        let appData = await createTestAppData()
        let testCoord = testCoordinate()
        
        // Simulate rapid entry/exit cycles that might occur with poor GPS signal
        for _ in 0..<3 {
            // Enter office
            appData.startVisit(at: testCoord)
            appData.sharedUserDefaults.synchronize()
            
            #expect(appData.isCurrentlyInOffice == true)
            #expect(appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice") == true)
            
            // Brief delay
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Exit office  
            await appData.endVisit()
            appData.sharedUserDefaults.synchronize()
            
            #expect(appData.isCurrentlyInOffice == false)
            #expect(appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice") == false)
        }
        
        // Final state should be consistent
        let finalStatus = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        #expect(finalStatus == false)
    }
    
    // MARK: - Grace Period Expiry Override Tests
    
    @Test("Widget Grace Period - Expired grace period overrides IsCurrentlyInOffice to false")
    func testExpiredGracePeriodOverridesOfficeStatus() async throws {
        let appData = await createTestAppData()
        let testCoord = testCoordinate()
        
        // Simulate: user was in office
        appData.startVisit(at: testCoord)
        appData.sharedUserDefaults.synchronize()
        #expect(appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice") == true)
        
        // Simulate: app detected exit and set grace period expiry 5 minutes ago
        // (timer was suspended in background, so endVisit() never ran)
        let expiredTime = Date().addingTimeInterval(-300) // 5 minutes ago
        appData.sharedUserDefaults.set(expiredTime, forKey: "GracePeriodExpires")
        appData.sharedUserDefaults.synchronize()
        
        // Verify: IsCurrentlyInOffice is still true (app never updated it)
        #expect(appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice") == true)
        
        // Apply the same logic the widget uses to detect expired grace period
        var isCurrentlyInOffice = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        if isCurrentlyInOffice,
           let gracePeriodExpires = appData.sharedUserDefaults.object(forKey: "GracePeriodExpires") as? Date,
           gracePeriodExpires <= Date() {
            isCurrentlyInOffice = false
        }
        
        // The widget should show "away" because grace period has expired
        #expect(isCurrentlyInOffice == false, "Widget should override to 'away' when grace period has expired")
    }
    
    @Test("Widget Grace Period - Active grace period keeps IsCurrentlyInOffice true")
    func testActiveGracePeriodKeepsOfficeStatus() async throws {
        let appData = await createTestAppData()
        let testCoord = testCoordinate()
        
        // Simulate: user was in office
        appData.startVisit(at: testCoord)
        appData.sharedUserDefaults.synchronize()
        
        // Simulate: grace period set to expire 3 minutes from now (still active)
        let futureTime = Date().addingTimeInterval(180) // 3 minutes from now
        appData.sharedUserDefaults.set(futureTime, forKey: "GracePeriodExpires")
        appData.sharedUserDefaults.synchronize()
        
        // Apply the same logic the widget uses
        var isCurrentlyInOffice = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        if isCurrentlyInOffice,
           let gracePeriodExpires = appData.sharedUserDefaults.object(forKey: "GracePeriodExpires") as? Date,
           gracePeriodExpires <= Date() {
            isCurrentlyInOffice = false
        }
        
        // Should still show "in office" because grace period hasn't expired yet
        #expect(isCurrentlyInOffice == true, "Widget should still show 'in office' during active grace period")
    }
    
    @Test("Widget Grace Period - No grace period key leaves status unchanged")
    func testNoGracePeriodKeyLeavesStatusUnchanged() async throws {
        let appData = await createTestAppData()
        let testCoord = testCoordinate()
        
        // Simulate: user is in office, no grace period active
        appData.startVisit(at: testCoord)
        appData.sharedUserDefaults.synchronize()
        
        // Ensure no grace period key exists
        appData.sharedUserDefaults.removeObject(forKey: "GracePeriodExpires")
        appData.sharedUserDefaults.synchronize()
        
        // Apply the same logic the widget uses
        var isCurrentlyInOffice = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        if isCurrentlyInOffice,
           let gracePeriodExpires = appData.sharedUserDefaults.object(forKey: "GracePeriodExpires") as? Date,
           gracePeriodExpires <= Date() {
            isCurrentlyInOffice = false
        }
        
        // Should still show "in office" - no grace period means user is genuinely there
        #expect(isCurrentlyInOffice == true, "Widget should show 'in office' when no grace period exists")
    }
    
    @Test("Widget Grace Period - Visit duration is nil when grace period expired")
    func testVisitDurationNilWhenGracePeriodExpired() async throws {
        let appData = await createTestAppData()
        let testCoord = testCoordinate()
        
        // Simulate: user was in office with active visit
        appData.startVisit(at: testCoord)
        appData.sharedUserDefaults.synchronize()
        
        // Verify current visit data exists
        #expect(appData.sharedUserDefaults.data(forKey: "CurrentVisit") != nil)
        
        // Simulate: grace period expired (app didn't clean up)
        let expiredTime = Date().addingTimeInterval(-300)
        appData.sharedUserDefaults.set(expiredTime, forKey: "GracePeriodExpires")
        appData.sharedUserDefaults.synchronize()
        
        // Apply the widget's logic: if grace period expired, treat as away
        var isCurrentlyInOffice = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        if isCurrentlyInOffice,
           let gracePeriodExpires = appData.sharedUserDefaults.object(forKey: "GracePeriodExpires") as? Date,
           gracePeriodExpires <= Date() {
            isCurrentlyInOffice = false
        }
        
        // Calculate visit duration only if still in office
        var currentVisitDuration: TimeInterval? = nil
        if isCurrentlyInOffice,
           let currentVisitData = appData.sharedUserDefaults.data(forKey: "CurrentVisit"),
           let currentVisit = try? JSONDecoder().decode(OfficeVisit.self, from: currentVisitData) {
            currentVisitDuration = Date().timeIntervalSince(currentVisit.entryTime)
        }
        
        // Duration should be nil since user has left
        #expect(currentVisitDuration == nil, "Visit duration should be nil when grace period has expired")
        #expect(isCurrentlyInOffice == false)
    }
}