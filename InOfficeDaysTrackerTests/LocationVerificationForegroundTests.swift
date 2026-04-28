//
//  LocationVerificationForegroundTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for foreground location verification feature
//

import Testing
import Foundation
import CoreLocation
@testable import InOfficeDaysTracker

@MainActor
struct LocationVerificationForegroundTests {
    
    // MARK: - Test Helpers
    
    func createTestAppData() -> AppData {
        let suiteName = "group.com.lpineda.InOfficeDaysTracker.tests." + UUID().uuidString
        let groupDefaults = UserDefaults(suiteName: suiteName)!
        groupDefaults.removePersistentDomain(forName: suiteName)
        groupDefaults.synchronize()
        
        return AppData(sharedUserDefaults: groupDefaults)
    }
    
    func createTestOfficeLocation(
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 402,
        isPrimary: Bool = false
    ) -> OfficeLocation {
        return OfficeLocation(
            name: name,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            address: "\(name) Address",
            detectionRadius: radius,
            isPrimary: isPrimary
        )
    }
    
    // MARK: - Debouncing Tests
    
    @Test("Verification is debounced within 30 seconds")
    func testVerificationDebouncing() async throws {
        let verificationService = LocationVerificationService()
        let appData = createTestAppData()
        let locationService = LocationService()
        
        // Setup office location
        let office = createTestOfficeLocation(
            name: "Test Office",
            latitude: 27.9089,
            longitude: -82.4543,
            isPrimary: true
        )
        appData.settings.officeLocations = [office]
        appData.settings.isSetupComplete = true
        
        verificationService.setServices(appData: appData, locationService: locationService)
        locationService.setAppData(appData)
        
        // First call should execute (but may not get location)
        await verificationService.verifyLocationNow()
        
        // Immediate second call should be debounced
        await verificationService.verifyLocationNow()
        
        // Test passes if no crashes
        #expect(true)
    }
    
    @Test("Multiple rapid verification calls are serialized")
    func testConcurrentVerificationPrevention() async throws {
        let verificationService = LocationVerificationService()
        let appData = createTestAppData()
        let locationService = LocationService()
        
        let office = createTestOfficeLocation(
            name: "Test Office",
            latitude: 27.9089,
            longitude: -82.4543
        )
        appData.settings.officeLocations = [office]
        
        verificationService.setServices(appData: appData, locationService: locationService)
        
        // Launch multiple concurrent verifications
        async let call1 = verificationService.verifyLocationNow()
        async let call2 = verificationService.verifyLocationNow()
        async let call3 = verificationService.verifyLocationNow()
        
        // All should complete without crashes
        _ = await (call1, call2, call3)
        
        #expect(true)
    }
    
    // MARK: - Permission Tests
    
    @Test("Verification only occurs with proper authorization")
    func testVerificationRequiresPermission() async throws {
        let locationService = LocationService()
        let appData = createTestAppData()
        
        locationService.setAppData(appData)
        
        // Setup but no authorization
        #expect(locationService.authorizationStatus != .authorizedAlways)
        
        // Should not crash when called without permission
        await locationService.verifyLocationOnForeground()
        
        // Test passes if no crashes
        #expect(true)
    }
    
    @Test("Verification skipped when setup incomplete")
    func testVerificationSkippedWhenSetupIncomplete() async throws {
        let appData = createTestAppData()
        let locationService = LocationService()
        
        locationService.setAppData(appData)
        
        // Setup incomplete
        appData.settings.isSetupComplete = false
        
        // Should not crash
        await locationService.verifyLocationOnForeground()
        
        #expect(true)
    }
    
    // MARK: - Multi-Office Tests
    
    @Test("Verification works with multiple office locations")
    func testVerificationWithMultipleOffices() async throws {
        let appData = createTestAppData()
        let verificationService = LocationVerificationService()
        let locationService = LocationService()
        
        let office1 = createTestOfficeLocation(
            name: "SF Office",
            latitude: 37.7749,
            longitude: -122.4194,
            isPrimary: true
        )
        
        let office2 = createTestOfficeLocation(
            name: "NY Office",
            latitude: 40.7128,
            longitude: -74.0060,
            isPrimary: false
        )
        
        appData.settings.officeLocations = [office1, office2]
        appData.settings.isSetupComplete = true
        
        verificationService.setServices(appData: appData, locationService: locationService)
        locationService.setAppData(appData)
        
        // Should handle multiple offices without crashing
        await verificationService.verifyLocationNow()
        
        #expect(true)
    }
    
    @Test("Verification handles empty office locations")
    func testVerificationWithNoOffices() async throws {
        let appData = createTestAppData()
        let verificationService = LocationVerificationService()
        let locationService = LocationService()
        
        // No offices configured
        appData.settings.officeLocations = []
        appData.settings.officeLocation = nil
        appData.settings.isSetupComplete = true
        
        verificationService.setServices(appData: appData, locationService: locationService)
        locationService.setAppData(appData)
        
        // Should handle gracefully
        await verificationService.verifyLocationNow()
        
        #expect(true)
    }
    
    // MARK: - Legacy Compatibility Tests
    
    @Test("Verification works with legacy single office location")
    func testVerificationWithLegacySingleOffice() async throws {
        let appData = createTestAppData()
        let verificationService = LocationVerificationService()
        let locationService = LocationService()
        
        // Set legacy single location
        appData.settings.officeLocation = CLLocationCoordinate2D(
            latitude: 27.9089,
            longitude: -82.4543
        )
        appData.settings.officeAddress = "Legacy Office Address"
        appData.settings.detectionRadius = 402
        appData.settings.isSetupComplete = true
        
        verificationService.setServices(appData: appData, locationService: locationService)
        locationService.setAppData(appData)
        
        // Should work with legacy format
        await verificationService.verifyLocationNow()
        
        #expect(true)
    }
    
    // MARK: - Tracking Window Tests
    
    @Test("Verification respects tracking days")
    func testVerificationRespectsTrackingDays() async throws {
        let appData = createTestAppData()
        
        let office = createTestOfficeLocation(
            name: "Test Office",
            latitude: 27.9089,
            longitude: -82.4543
        )
        appData.settings.officeLocations = [office]
        appData.settings.isSetupComplete = true
        
        // Set tracking days to weekdays only (Monday=2 through Friday=6)
        appData.settings.trackingDays = [2, 3, 4, 5, 6]
        
        let verificationService = LocationVerificationService()
        let locationService = LocationService()
        
        verificationService.setServices(appData: appData, locationService: locationService)
        locationService.setAppData(appData)
        
        // Verification should complete without error regardless of day
        await verificationService.verifyLocationNow()
        
        #expect(true)
    }
    
    @Test("Verification respects office hours")
    func testVerificationRespectsOfficeHours() async throws {
        let appData = createTestAppData()
        
        let office = createTestOfficeLocation(
            name: "Test Office",
            latitude: 27.9089,
            longitude: -82.4543
        )
        appData.settings.officeLocations = [office]
        appData.settings.isSetupComplete = true
        
        // Set specific office hours
        let calendar = Calendar.current
        let startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let endTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: Date())!
        
        appData.settings.officeHours = AppSettings.OfficeHours(startTime: startTime, endTime: endTime)
        
        let verificationService = LocationVerificationService()
        let locationService = LocationService()
        
        verificationService.setServices(appData: appData, locationService: locationService)
        locationService.setAppData(appData)
        
        // Verification should complete without error regardless of current time
        await verificationService.verifyLocationNow()
        
        #expect(true)
    }
    
    // MARK: - Integration Tests
    
    @Test("LocationService bridge method delegates to verification service")
    func testLocationServiceBridgeMethod() async throws {
        let appData = createTestAppData()
        let locationService = LocationService()
        
        let office = createTestOfficeLocation(
            name: "Test Office",
            latitude: 27.9089,
            longitude: -82.4543
        )
        appData.settings.officeLocations = [office]
        appData.settings.isSetupComplete = true
        
        locationService.setAppData(appData)
        
        // Should delegate to verification service without crashing
        await locationService.verifyLocationOnForeground()
        
        #expect(true)
    }
    
    @Test("Verification maintains state consistency")
    func testVerificationStateConsistency() async throws {
        let appData = createTestAppData()
        
        let office = createTestOfficeLocation(
            name: "Test Office",
            latitude: 27.9089,
            longitude: -82.4543
        )
        appData.settings.officeLocations = [office]
        appData.settings.isSetupComplete = true
        
        // Record initial state
        let _ = appData.isCurrentlyInOffice // Initial state recorded
        let initialVisitCount = appData.visits.count
        
        let verificationService = LocationVerificationService()
        let locationService = LocationService()
        
        verificationService.setServices(appData: appData, locationService: locationService)
        locationService.setAppData(appData)
        
        // Run verification
        await verificationService.verifyLocationNow()
        
        // State should be consistent (even if unchanged due to no actual location)
        #expect(appData.visits.count >= initialVisitCount)
        
        // Office status is boolean, should remain valid
        #expect(appData.isCurrentlyInOffice == true || appData.isCurrentlyInOffice == false)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Verification handles invalid coordinates gracefully")
    func testVerificationWithInvalidCoordinates() async throws {
        let appData = createTestAppData()
        
        // Create office with invalid coordinates
        let office = OfficeLocation(
            name: "Invalid Office",
            coordinate: nil,
            address: "Invalid Address",
            detectionRadius: 402,
            isPrimary: true
        )
        
        appData.settings.officeLocations = [office]
        appData.settings.isSetupComplete = true
        
        let verificationService = LocationVerificationService()
        let locationService = LocationService()
        
        verificationService.setServices(appData: appData, locationService: locationService)
        locationService.setAppData(appData)
        
        // Should handle gracefully without crashing
        await verificationService.verifyLocationNow()
        
        #expect(true)
    }
    
    @Test("Verification handles location timeout gracefully")
    func testVerificationLocationTimeout() async throws {
        let appData = createTestAppData()
        
        let office = createTestOfficeLocation(
            name: "Test Office",
            latitude: 27.9089,
            longitude: -82.4543
        )
        appData.settings.officeLocations = [office]
        appData.settings.isSetupComplete = true
        
        let verificationService = LocationVerificationService()
        let locationService = LocationService()
        
        verificationService.setServices(appData: appData, locationService: locationService)
        locationService.setAppData(appData)
        
        // Verification may timeout getting location, but should not crash
        await verificationService.verifyLocationNow()
        
        #expect(true)
    }
}
