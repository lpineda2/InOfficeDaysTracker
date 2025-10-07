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
    func createTestAppData() -> AppData {
        let appData = AppData()
        appData.visits = [] // Clear any existing visits
        appData.currentVisit = nil
        appData.isCurrentlyInOffice = false
        return appData
    }
    
    /// Creates a test coordinate for San Francisco
    func testCoordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
    
    // MARK: - Widget Data Synchronization Tests
    
    @Test("Widget Sync - Office status persistence after entry")
    func testOfficeStatusPersistenceAfterEntry() async throws {
        let appData = createTestAppData()
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
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        
        // Start office visit
        appData.startVisit(at: testCoord)
        #expect(appData.isCurrentlyInOffice == true)
        
        // End office visit  
        appData.endVisit()
        
        // Force synchronization (simulating what LocationService does)
        appData.sharedUserDefaults.synchronize()
        
        // Verify both in-memory and persisted state are updated
        #expect(appData.isCurrentlyInOffice == false)
        #expect(appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice") == false)
    }
    
    @Test("Widget Sync - UserDefaults synchronization timing")
    func testUserDefaultsSynchronizationTiming() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        
        // Test rapid state changes (like what might happen with location events)
        for i in 0..<5 {
            if i % 2 == 0 {
                appData.startVisit(at: testCoord)
                #expect(appData.isCurrentlyInOffice == true)
            } else {
                appData.endVisit()
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
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        
        // Verify no current visit initially
        #expect(appData.currentVisit == nil)
        #expect(appData.sharedUserDefaults.data(forKey: "CurrentVisit") == nil)
        
        // Start visit
        appData.startVisit(at: testCoord)
        let visitId = appData.currentVisit?.id
        
        // Force synchronization
        appData.sharedUserDefaults.synchronize()
        
        // Verify current visit is persisted
        #expect(appData.currentVisit != nil)
        let persistedVisitData = appData.sharedUserDefaults.data(forKey: "CurrentVisit")
        #expect(persistedVisitData != nil)
        
        // Verify persisted visit can be decoded and matches
        if let data = persistedVisitData {
            let decodedVisit = try? JSONDecoder().decode(OfficeVisit.self, from: data)
            #expect(decodedVisit?.id == visitId)
        }
        
        // End visit
        appData.endVisit()
        appData.sharedUserDefaults.synchronize()
        
        // Verify current visit is cleared from persistence
        #expect(appData.currentVisit == nil)
        let clearedVisitData = appData.sharedUserDefaults.data(forKey: "CurrentVisit")
        #expect(clearedVisitData == nil)
    }
    
    // MARK: - Widget Data Creation Tests
    
    @Test("Widget Data - Accurate office status reflection")
    func testWidgetDataOfficeStatusAccuracy() async throws {
        let appData = createTestAppData()
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
        appData.endVisit()
        appData.sharedUserDefaults.synchronize()
        
        // Test when away again - check through UserDefaults directly
        let isAfterExitStatus = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        #expect(isAfterExitStatus == false)
    }        @Test("Widget Data - Proper UserDefaults synchronization timing")
    func testWidgetDataSynchronizationTiming() async throws {
        let appData = createTestAppData()
        
        // Force a visit update
        appData.startVisit(at: testCoordinate())
        
        // Check that UserDefaults reflects the change
        let isInOfficeAfterStart = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        #expect(isInOfficeAfterStart == true)
        
        // End visit and verify
        appData.endVisit()
        
        // UserDefaults should reflect the status change
        let isInOfficeAfterEnd = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        #expect(isInOfficeAfterEnd == false)
    }
    
    // MARK: - Location Service Integration Tests
    
    @Test("Location Integration - End visit updates all states")
    func testLocationIntegrationEndVisit() async throws {
        let appData = createTestAppData()
        let locationService = LocationService()
        let testCoord = testCoordinate()
        
        // Set up location service with app data
        locationService.setAppData(appData)
        
        // Start a visit manually
        appData.startVisit(at: testCoord)
        #expect(appData.isCurrentlyInOffice == true)
        
        // Simulate location service ending the visit (like didExitRegion would do)
        appData.endVisit()
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
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        
        // Simulate rapid entry/exit cycles that might occur with poor GPS signal
        for cycle in 0..<3 {
            // Enter office
            appData.startVisit(at: testCoord)
            appData.sharedUserDefaults.synchronize()
            
            #expect(appData.isCurrentlyInOffice == true)
            #expect(appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice") == true)
            
            // Brief delay
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Exit office  
            appData.endVisit()
            appData.sharedUserDefaults.synchronize()
            
            #expect(appData.isCurrentlyInOffice == false)
            #expect(appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice") == false)
        }
        
        // Final state should be consistent
        let finalStatus = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        #expect(finalStatus == false)
    }
}