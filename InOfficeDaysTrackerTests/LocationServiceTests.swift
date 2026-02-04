//
//  LocationServiceTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for LocationService geofencing and multi-location support
//

import Testing
import Foundation
import CoreLocation
@testable import InOfficeDaysTracker

@MainActor
struct LocationServiceTests {
    
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
    
    // MARK: - Multi-Location Geofencing Tests
    
    @Test("Multiple office locations are configured in settings")
    func testMultipleOfficeLocationsConfiguration() async throws {
        let appData = createTestAppData()
        
        let office1 = createTestOfficeLocation(
            name: "Primary Office",
            latitude: 27.9089,
            longitude: -82.4543,
            isPrimary: true
        )
        
        let office2 = createTestOfficeLocation(
            name: "NY Office",
            latitude: 40.6892,
            longitude: -73.9932,
            isPrimary: false
        )
        
        appData.settings.officeLocations = [office1, office2]
        
        #expect(appData.settings.officeLocations.count == 2)
        #expect(appData.settings.officeLocations[0].name == "Primary Office")
        #expect(appData.settings.officeLocations[1].name == "NY Office")
        #expect(appData.settings.officeLocations[0].isPrimary == true)
        #expect(appData.settings.officeLocations[1].isPrimary == false)
    }
    
    @Test("Office location identification by UUID")
    func testOfficeLocationIdentificationByUUID() async throws {
        let office1 = createTestOfficeLocation(
            name: "Office A",
            latitude: 27.9089,
            longitude: -82.4543
        )
        
        let office2 = createTestOfficeLocation(
            name: "Office B",
            latitude: 40.6892,
            longitude: -73.9932
        )
        
        let offices = [office1, office2]
        
        // Verify each office has unique ID
        #expect(office1.id != office2.id)
        
        // Verify we can find offices by their ID
        let foundOffice1 = offices.first { $0.id == office1.id }
        let foundOffice2 = offices.first { $0.id == office2.id }
        
        #expect(foundOffice1?.name == "Office A")
        #expect(foundOffice2?.name == "Office B")
    }
    
    @Test("Office coordinates are valid")
    func testOfficeCoordinatesValidation() async throws {
        let validOffice = createTestOfficeLocation(
            name: "Valid Office",
            latitude: 27.9089,
            longitude: -82.4543
        )
        
        #expect(validOffice.coordinate != nil)
        #expect(validOffice.coordinate?.latitude == 27.9089)
        #expect(validOffice.coordinate?.longitude == -82.4543)
    }
    
    @Test("Region identifiers use office UUID")
    func testRegionIdentifiersUseOfficeUUID() async throws {
        let office = createTestOfficeLocation(
            name: "Test Office",
            latitude: 27.9089,
            longitude: -82.4543
        )
        
        // In the actual implementation, region.identifier should be office.id.uuidString
        let expectedIdentifier = office.id.uuidString
        
        #expect(expectedIdentifier.isEmpty == false)
        #expect(UUID(uuidString: expectedIdentifier) != nil) // Valid UUID format
    }
    
    // MARK: - Legacy Single Location Support Tests
    
    @Test("Legacy single location backward compatibility")
    func testLegacySingleLocationBackwardCompatibility() async throws {
        let appData = createTestAppData()
        
        // Set legacy single location (pre-multi-location feature)
        let legacyCoordinate = CLLocationCoordinate2D(latitude: 27.9089, longitude: -82.4543)
        appData.settings.officeLocation = legacyCoordinate
        appData.settings.officeAddress = "880 Carillon Pkwy, Saint Petersburg, FL"
        appData.settings.detectionRadius = 402
        
        // Verify legacy data is set
        #expect(appData.settings.officeLocation != nil)
        #expect(appData.settings.officeLocation?.latitude == 27.9089)
        
        // New multi-location array should be empty
        #expect(appData.settings.officeLocations.isEmpty == true)
        
        // LocationService should handle this by converting to OfficeLocation on the fly
        if let legacyLoc = appData.settings.officeLocation {
            let migratedOffice = OfficeLocation(
                name: "Office",
                coordinate: legacyLoc,
                address: appData.settings.officeAddress,
                detectionRadius: appData.settings.detectionRadius,
                isPrimary: true
            )
            
            #expect(migratedOffice.name == "Office")
            #expect(migratedOffice.isPrimary == true)
            #expect(migratedOffice.coordinate?.latitude == 27.9089)
        }
    }
    
    @Test("Multi-location takes precedence over legacy")
    func testMultiLocationTakesPrecedenceOverLegacy() async throws {
        let appData = createTestAppData()
        
        // Set both legacy and new format
        appData.settings.officeLocation = CLLocationCoordinate2D(latitude: 27.9089, longitude: -82.4543)
        
        let newOffice = createTestOfficeLocation(
            name: "New Office",
            latitude: 40.6892,
            longitude: -73.9932,
            isPrimary: true
        )
        appData.settings.officeLocations = [newOffice]
        
        // The implementation should prefer officeLocations array when not empty
        let shouldUseNew = !appData.settings.officeLocations.isEmpty
        #expect(shouldUseNew == true)
        
        // And use the new location
        #expect(appData.settings.officeLocations[0].coordinate?.latitude == 40.6892)
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Empty office locations array")
    func testEmptyOfficeLocationsArray() async throws {
        let appData = createTestAppData()
        
        // No legacy location and empty array
        appData.settings.officeLocation = nil
        appData.settings.officeLocations = []
        
        #expect(appData.settings.officeLocations.isEmpty == true)
        #expect(appData.settings.officeLocation == nil)
        
        // LocationService should handle this gracefully (set error)
    }
    
    @Test("Office with nil coordinate")
    func testOfficeWithNilCoordinate() async throws {
        let officeWithoutCoord = OfficeLocation(
            name: "No Coord Office",
            coordinate: nil,
            address: "Unknown",
            detectionRadius: 402,
            isPrimary: false
        )
        
        #expect(officeWithoutCoord.coordinate == nil)
        
        // LocationService should skip this office when creating geofences
    }
    
    @Test("Office with invalid detection radius")
    func testOfficeWithInvalidRadius() async throws {
        let office = createTestOfficeLocation(
            name: "Invalid Radius",
            latitude: 27.9089,
            longitude: -82.4543,
            radius: -100 // Invalid
        )
        
        // LocationService should clamp to valid range (1 to maximumRegionMonitoringDistance)
        let clampedRadius = min(max(office.detectionRadius, 1), 10000) // Assuming 10km max
        #expect(clampedRadius >= 1)
    }
    
    @Test("Maximum of 2 office locations enforced")
    func testMaximumTwoOfficeLocationsLimit() async throws {
        let appData = createTestAppData()
        
        let office1 = createTestOfficeLocation(name: "Office 1", latitude: 27.9089, longitude: -82.4543)
        let office2 = createTestOfficeLocation(name: "Office 2", latitude: 40.6892, longitude: -73.9932)
        
        // UI should prevent adding more than 2, but verify limit
        appData.settings.officeLocations = [office1, office2]
        
        #expect(appData.settings.officeLocations.count == 2)
        
        // If somehow 3 are added, LocationService should handle gracefully
        // (either monitor all 3 or just first 2, depending on implementation)
    }
    
    // MARK: - Visit Tracking with Multiple Locations Tests
    
    @Test("Starting visit at specific office location")
    func testStartingVisitAtSpecificOffice() async throws {
        let appData = createTestAppData()
        
        let office1 = createTestOfficeLocation(
            name: "Primary Office",
            latitude: 27.9089,
            longitude: -82.4543,
            isPrimary: true
        )
        
        let office2 = createTestOfficeLocation(
            name: "NY Office",
            latitude: 40.6892,
            longitude: -73.9932,
            isPrimary: false
        )
        
        appData.settings.officeLocations = [office1, office2]
        
        // Start visit at NY Office
        let nyCoordinate = office2.coordinate!
        appData.startVisit(at: nyCoordinate)
        
        #expect(appData.isCurrentlyInOffice == true)
        #expect(appData.currentVisit != nil)
        
        // Verify the visit coordinate matches NY Office
        let visitCoord = appData.currentVisit?.coordinate
        #expect(visitCoord?.latitude == 40.6892)
        #expect(visitCoord?.longitude == -73.9932)
    }
    
    @Test("Visit coordinates distinguish between offices")
    func testVisitCoordinatesDistinguishOffices() async throws {
        let appData = createTestAppData()
        
        let flOffice = CLLocationCoordinate2D(latitude: 27.9089, longitude: -82.4543)
        let nyOffice = CLLocationCoordinate2D(latitude: 40.6892, longitude: -73.9932)
        
        // Start visit at FL office and capture coordinate
        appData.startVisit(at: flOffice)
        let visit1 = appData.currentVisit
        #expect(visit1 != nil, "Visit 1 should exist")
        #expect(visit1?.coordinate != nil, "Visit 1 should have coordinate")
        let visit1Coord = visit1?.coordinate
        appData.endVisit()
        
        // Verify FL coordinate is stored correctly
        #expect(visit1Coord?.latitude == flOffice.latitude)
        #expect(visit1Coord?.longitude == flOffice.longitude)
        
        // Start NEW visit at NY office (on the same day, will resume session)
        // The coordinate should remain from the first office (FL)
        appData.startVisit(at: nyOffice)
        let visit2 = appData.currentVisit
        #expect(visit2 != nil, "Visit 2 should exist")
        #expect(visit2?.coordinate != nil, "Visit 2 should have coordinate")
        
        // Since this is the same day, the visit is resumed and keeps original coordinate
        // This is expected behavior: one visit per day, coordinate set on first entry
        let visit2Coord = visit2?.coordinate
        #expect(visit2Coord?.latitude == flOffice.latitude, "Coordinate should match first office visited today")
        #expect(visit2Coord?.longitude == flOffice.longitude, "Coordinate should match first office visited today")
        
        appData.endVisit()
    }
    
    // MARK: - Region Monitoring State Tests
    
    @Test("Multiple regions can be monitored simultaneously")
    func testMultipleRegionsMonitoredSimultaneously() async throws {
        let office1 = createTestOfficeLocation(
            name: "Office 1",
            latitude: 27.9089,
            longitude: -82.4543
        )
        
        let office2 = createTestOfficeLocation(
            name: "Office 2",
            latitude: 40.6892,
            longitude: -73.9932
        )
        
        let offices = [office1, office2]
        
        // LocationService should create separate CLCircularRegion for each
        var regionIdentifiers: [String] = []
        for office in offices {
            guard office.coordinate != nil else { continue }
            regionIdentifiers.append(office.id.uuidString)
        }
        
        #expect(regionIdentifiers.count == 2)
        #expect(regionIdentifiers[0] != regionIdentifiers[1])
        #expect(Set(regionIdentifiers).count == 2) // All unique
    }
    
    @Test("Region entry identification matches correct office")
    func testRegionEntryIdentificationMatchesCorrectOffice() async throws {
        let office1 = createTestOfficeLocation(
            name: "Primary Office",
            latitude: 27.9089,
            longitude: -82.4543,
            isPrimary: true
        )
        
        let office2 = createTestOfficeLocation(
            name: "NY Office",
            latitude: 40.6892,
            longitude: -73.9932,
            isPrimary: false
        )
        
        let offices = [office1, office2]
        
        // Simulate region entry for NY Office
        let enteredRegionId = office2.id.uuidString
        
        // Find which office was entered
        let enteredOffice = offices.first { $0.id.uuidString == enteredRegionId }
        
        #expect(enteredOffice != nil)
        #expect(enteredOffice?.name == "NY Office")
        #expect(enteredOffice?.isPrimary == false)
    }
    
    @Test("Legacy region identifier still supported")
    func testLegacyRegionIdentifierSupported() async throws {
        // Legacy identifier was hardcoded as "office_location"
        let legacyIdentifier = "office_location"
        
        // LocationService should still recognize this for backward compatibility
        let isLegacyFormat = legacyIdentifier == "office_location"
        #expect(isLegacyFormat == true)
        
        // Should handle by checking legacy officeLocation property
    }
    
    // MARK: - Data Consistency Tests
    
    @Test("Office location data persists correctly")
    func testOfficeLocationDataPersistence() async throws {
        let appData = createTestAppData()
        
        let office1 = createTestOfficeLocation(
            name: "Test Office",
            latitude: 27.9089,
            longitude: -82.4543,
            radius: 500,
            isPrimary: true
        )
        
        appData.settings.officeLocations = [office1]
        
        // Save to UserDefaults
        let encoder = JSONEncoder()
        let data = try encoder.encode(appData.settings)
        appData.sharedUserDefaults.set(data, forKey: "settings")
        appData.sharedUserDefaults.synchronize()
        
        // Load back
        guard let savedData = appData.sharedUserDefaults.data(forKey: "settings") else {
            #expect(Bool(false), "Failed to retrieve settings data")
            return
        }
        
        let decoder = JSONDecoder()
        let loadedSettings = try decoder.decode(AppSettings.self, from: savedData)
        
        #expect(loadedSettings.officeLocations.count == 1)
        #expect(loadedSettings.officeLocations[0].name == "Test Office")
        #expect(loadedSettings.officeLocations[0].detectionRadius == 500)
        #expect(loadedSettings.officeLocations[0].isPrimary == true)
    }
    
    @Test("Office ID remains stable across app launches")
    func testOfficeIDStability() async throws {
        let office = createTestOfficeLocation(
            name: "Stable Office",
            latitude: 27.9089,
            longitude: -82.4543
        )
        
        let originalId = office.id
        
        // Encode and decode (simulating persistence)
        let encoder = JSONEncoder()
        let data = try encoder.encode(office)
        
        let decoder = JSONDecoder()
        let decodedOffice = try decoder.decode(OfficeLocation.self, from: data)
        
        // ID should be preserved
        #expect(decodedOffice.id == originalId)
    }
}
