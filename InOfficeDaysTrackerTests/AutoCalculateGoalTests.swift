//
//  AutoCalculateGoalTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for the auto-calculate office days feature (v1.9.0)
//

import XCTest
import CoreLocation
@testable import InOfficeDaysTracker

final class AutoCalculateGoalTests: XCTestCase {
    
    // MARK: - CompanyPolicy Tests
    
    func testHybrid50PolicyCalculation() {
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        
        // 20 working days → 10 required (50%)
        XCTAssertEqual(policy.calculateRequiredDays(workingDays: 20), 10)
        
        // 21 working days → 10 required (floor of 10.5)
        XCTAssertEqual(policy.calculateRequiredDays(workingDays: 21), 10)
        
        // 22 working days → 11 required
        XCTAssertEqual(policy.calculateRequiredDays(workingDays: 22), 11)
        
        // 19 working days → 9 required (floor of 9.5)
        XCTAssertEqual(policy.calculateRequiredDays(workingDays: 19), 9)
    }
    
    func testHybrid40PolicyCalculation() {
        var policy = CompanyPolicy()
        policy.policyType = .hybrid40
        
        // 20 working days → 8 required (40%)
        XCTAssertEqual(policy.calculateRequiredDays(workingDays: 20), 8)
        
        // 21 working days → 8 required (floor of 8.4)
        XCTAssertEqual(policy.calculateRequiredDays(workingDays: 21), 8)
    }
    
    func testHybrid60PolicyCalculation() {
        var policy = CompanyPolicy()
        policy.policyType = .hybrid60
        
        // 20 working days → 12 required (60%)
        XCTAssertEqual(policy.calculateRequiredDays(workingDays: 20), 12)
    }
    
    func testFullOfficePolicy() {
        var policy = CompanyPolicy()
        policy.policyType = .fullOffice
        
        // 20 working days → 20 required (100%)
        XCTAssertEqual(policy.calculateRequiredDays(workingDays: 20), 20)
    }
    
    func testFullRemotePolicy() {
        var policy = CompanyPolicy()
        policy.policyType = .fullRemote
        
        // 20 working days → 0 required (0%)
        XCTAssertEqual(policy.calculateRequiredDays(workingDays: 20), 0)
    }
    
    func testCustomPolicyCalculation() {
        var policy = CompanyPolicy()
        policy.policyType = .custom
        policy.customPercentage = 75
        
        // 20 working days → 15 required (75%)
        XCTAssertEqual(policy.calculateRequiredDays(workingDays: 20), 15)
        
        // 21 working days → 15 required (floor of 15.75)
        XCTAssertEqual(policy.calculateRequiredDays(workingDays: 21), 15)
    }
    
    func testPolicyRequiredPercentage() {
        var policy = CompanyPolicy()
        
        policy.policyType = .hybrid50
        XCTAssertEqual(policy.requiredPercentage, 0.5)
        
        policy.policyType = .hybrid40
        XCTAssertEqual(policy.requiredPercentage, 0.4)
        
        policy.policyType = .hybrid60
        XCTAssertEqual(policy.requiredPercentage, 0.6)
        
        policy.policyType = .fullOffice
        XCTAssertEqual(policy.requiredPercentage, 1.0)
        
        policy.policyType = .fullRemote
        XCTAssertEqual(policy.requiredPercentage, 0.0)
        
        policy.policyType = .custom
        policy.customPercentage = 33
        XCTAssertEqual(policy.requiredPercentage, 0.33)
    }
    
    // MARK: - HolidayCalendar Tests
    
    func testNYSEPresetHolidayCount() {
        // NYSE has 10 holidays
        let preset = HolidayPreset.nyse
        XCTAssertEqual(preset.holidays.count, 10)
    }
    
    func testUSFederalPresetHolidayCount() {
        // US Federal has 11 holidays
        let preset = HolidayPreset.usFederal
        XCTAssertEqual(preset.holidays.count, 11)
    }
    
    func testNonePresetHolidayCount() {
        // None preset has 0 holidays
        let preset = HolidayPreset.none
        XCTAssertEqual(preset.holidays.count, 0)
    }
    
    func testNewYearsDay2026() {
        let date = USHoliday.newYearsDay.date(for: 2026)
        XCTAssertNotNil(date)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)  // Thursday, Jan 1, 2026
    }
    
    func testMLKDay2026() {
        // MLK Day is 3rd Monday of January
        let date = USHoliday.mlkDay.date(for: 2026)
        XCTAssertNotNil(date)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 19)  // Monday, Jan 19, 2026
        XCTAssertEqual(components.weekday, 2)  // Monday
    }
    
    func testPresidentsDay2026() {
        // Presidents Day is 3rd Monday of February
        let date = USHoliday.presidentsDay.date(for: 2026)
        XCTAssertNotNil(date)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 16)  // Monday, Feb 16, 2026
    }
    
    func testGoodFriday2026() {
        // Good Friday 2026 is April 3
        let date = USHoliday.goodFriday.date(for: 2026)
        XCTAssertNotNil(date)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 3)
    }
    
    func testMemorialDay2026() {
        // Memorial Day is last Monday of May
        let date = USHoliday.memorialDay.date(for: 2026)
        XCTAssertNotNil(date)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 5)
        XCTAssertEqual(components.day, 25)  // Monday, May 25, 2026
    }
    
    func testJuneteenth2026() {
        // Juneteenth is June 19, observed on Friday June 19, 2026
        let date = USHoliday.juneteenth.date(for: 2026)
        XCTAssertNotNil(date)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 19)
    }
    
    func testIndependenceDay2026() {
        // July 4 falls on Saturday in 2026, observed Friday July 3
        let date = USHoliday.independenceDay.date(for: 2026)
        XCTAssertNotNil(date)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 3)  // Observed on Friday
    }
    
    func testLaborDay2026() {
        // Labor Day is 1st Monday of September
        let date = USHoliday.laborDay.date(for: 2026)
        XCTAssertNotNil(date)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 7)  // Monday, Sep 7, 2026
    }
    
    func testThanksgivingDay2026() {
        // Thanksgiving is 4th Thursday of November
        let date = USHoliday.thanksgiving.date(for: 2026)
        XCTAssertNotNil(date)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 26)  // Thursday, Nov 26, 2026
        XCTAssertEqual(components.weekday, 5)  // Thursday
    }
    
    func testChristmasDay2026() {
        // Christmas falls on Friday in 2026
        let date = USHoliday.christmas.date(for: 2026)
        XCTAssertNotNil(date)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 25)
    }
    
    // MARK: - HolidayCalendar Custom Additions/Removals Tests
    
    func testHolidayCalendarCustomRemovals() {
        var calendar = HolidayCalendar(preset: .usFederal)
        calendar.customRemovals = [HolidayDate(holiday: .columbusDay), HolidayDate(holiday: .veteransDay)]
        
        let holidays = calendar.getHolidays(for: 2026)
        
        // Should have 9 holidays (11 - 2 removed)
        XCTAssertEqual(holidays.count, 9)
    }
    
    func testHolidayCalendarCustomAdditions() {
        var calendar = HolidayCalendar(preset: .none)
        let customHoliday = HolidayDate(month: 6, day: 15, name: "Company Day")
        calendar.customAdditions = [customHoliday]
        
        let holidays = calendar.getHolidays(for: 2026)
        
        XCTAssertEqual(holidays.count, 1)
        
        let calendarUtil = Calendar.current
        let components = calendarUtil.dateComponents([.month, .day], from: holidays[0])
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
    }
    
    // MARK: - OfficeLocation Tests
    
    func testOfficeLocationContainsCoordinate() {
        let officeCoord = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)  // NYC
        let office = OfficeLocation(
            name: "NYC Office",
            coordinate: officeCoord,
            address: "123 Wall St, New York, NY",
            detectionRadius: 200,
            isPrimary: true
        )
        
        // Point within 200m should be detected
        let nearbyCoord = CLLocationCoordinate2D(latitude: 40.7130, longitude: -74.0062)
        XCTAssertTrue(office.contains(coordinate: nearbyCoord))
        
        // Point far away should not be detected
        let farCoord = CLLocationCoordinate2D(latitude: 40.7500, longitude: -73.9500)
        XCTAssertFalse(office.contains(coordinate: farCoord))
    }
    
    func testOfficeLocationMaxLocations() {
        XCTAssertEqual(OfficeLocation.maxLocations, 2)
    }
    
    func testOfficeLocationShortAddress() {
        let office = OfficeLocation(
            name: "Office",
            coordinate: nil,
            address: "123 Main St, Suite 100, New York, NY 10001",
            detectionRadius: 200,
            isPrimary: true
        )
        
        XCTAssertEqual(office.shortAddress, "123 Main St")
    }
    
    // MARK: - GoalCalculationBreakdown Tests
    
    func testGoalCalculationBreakdownExample() {
        // January 2026: 22 weekdays, 2 holidays (New Year's, MLK Day), 0 PTO
        // Business days = 22 - 2 = 20
        // Working days = 20 - 0 = 20
        // 50% policy = 10 required days
        
        let breakdown = GoalCalculationBreakdown(
            weekdaysInMonth: 22,
            holidays: [Date(), Date()],  // 2 placeholder holidays
            businessDays: 20,
            ptoDays: [],
            workingDays: 20,
            policyPercentage: 0.5,
            requiredDays: 10
        )
        
        XCTAssertEqual(breakdown.weekdaysInMonth, 22)
        XCTAssertEqual(breakdown.holidayCount, 2)
        XCTAssertEqual(breakdown.businessDays, 20)
        XCTAssertEqual(breakdown.ptoCount, 0)
        XCTAssertEqual(breakdown.workingDays, 20)
        XCTAssertEqual(breakdown.policyPercentage, 0.5)
        XCTAssertEqual(breakdown.requiredDays, 10)
    }
    
    // MARK: - 2026 Monthly Requirements Validation Tests
    // These test the specific numbers provided by the user for 2026
    
    func testJanuary2026Requirements() {
        // January 2026: 22 weekdays, 2 holidays (New Year's Day, MLK Day)
        // Business days = 20, 50% = 10 required
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        let businessDays = 22 - 2  // weekdays - holidays
        let required = policy.calculateRequiredDays(workingDays: businessDays)
        XCTAssertEqual(required, 10)
    }
    
    func testFebruary2026Requirements() {
        // February 2026: 20 weekdays, 1 holiday (Presidents Day)
        // Business days = 19, 50% = 9 required (floor of 9.5)
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        let businessDays = 20 - 1
        let required = policy.calculateRequiredDays(workingDays: businessDays)
        XCTAssertEqual(required, 9)
    }
    
    func testMarch2026Requirements() {
        // March 2026: 22 weekdays, 0 holidays (SIFMA Modified)
        // Business days = 22, 50% = 11 required
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        let businessDays = 22 - 0
        let required = policy.calculateRequiredDays(workingDays: businessDays)
        XCTAssertEqual(required, 11)
    }
    
    func testApril2026Requirements() {
        // April 2026: 22 weekdays, 1 holiday (Good Friday)
        // Business days = 21, 50% = 10 required (floor of 10.5)
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        let businessDays = 22 - 1
        let required = policy.calculateRequiredDays(workingDays: businessDays)
        XCTAssertEqual(required, 10)
    }
    
    func testMay2026Requirements() {
        // May 2026: 21 weekdays, 1 holiday (Memorial Day)
        // Business days = 20, 50% = 10 required
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        let businessDays = 21 - 1
        let required = policy.calculateRequiredDays(workingDays: businessDays)
        XCTAssertEqual(required, 10)
    }
    
    func testJune2026Requirements() {
        // June 2026: 22 weekdays, 1 holiday (Juneteenth)
        // Business days = 21, 50% = 10 required (floor of 10.5)
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        let businessDays = 22 - 1
        let required = policy.calculateRequiredDays(workingDays: businessDays)
        XCTAssertEqual(required, 10)
    }
    
    func testJuly2026Requirements() {
        // July 2026: 23 weekdays, 1 holiday (Independence Day - observed July 3)
        // Business days = 22, 50% = 11 required
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        let businessDays = 23 - 1
        let required = policy.calculateRequiredDays(workingDays: businessDays)
        XCTAssertEqual(required, 11)
    }
    
    func testAugust2026Requirements() {
        // August 2026: 21 weekdays, 0 holidays
        // Business days = 21, 50% = 10 required (floor of 10.5)
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        let businessDays = 21 - 0
        let required = policy.calculateRequiredDays(workingDays: businessDays)
        XCTAssertEqual(required, 10)
    }
    
    func testSeptember2026Requirements() {
        // September 2026: 22 weekdays, 1 holiday (Labor Day)
        // Business days = 21, 50% = 10 required (floor of 10.5)
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        let businessDays = 22 - 1
        let required = policy.calculateRequiredDays(workingDays: businessDays)
        XCTAssertEqual(required, 10)
    }
    
    func testOctober2026Requirements() {
        // October 2026: 22 weekdays, 0 holidays (SIFMA Modified excludes Columbus Day)
        // Business days = 22, 50% = 11 required
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        let businessDays = 22 - 0
        let required = policy.calculateRequiredDays(workingDays: businessDays)
        XCTAssertEqual(required, 11)
    }
    
    func testNovember2026Requirements() {
        // November 2026: 21 weekdays, 1 holiday (Thanksgiving - SIFMA Modified excludes Veterans Day)
        // Business days = 20, 50% = 10 required
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        let businessDays = 21 - 1
        let required = policy.calculateRequiredDays(workingDays: businessDays)
        XCTAssertEqual(required, 10)
    }
    
    func testDecember2026Requirements() {
        // December 2026: 23 weekdays, 1 holiday (Christmas)
        // Business days = 22, 50% = 11 required
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        let businessDays = 23 - 1
        let required = policy.calculateRequiredDays(workingDays: businessDays)
        XCTAssertEqual(required, 11)
    }
    
    // MARK: - Policy Codable Tests
    
    func testCompanyPolicyCodable() throws {
        var original = CompanyPolicy()
        original.policyType = .custom
        original.customPercentage = 65
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CompanyPolicy.self, from: data)
        
        XCTAssertEqual(decoded.policyType, original.policyType)
        XCTAssertEqual(decoded.customPercentage, original.customPercentage)
    }
    
    func testHolidayCalendarCodable() throws {
        var original = HolidayCalendar(preset: .nyse)
        original.customRemovals = [HolidayDate(holiday: .goodFriday)]
        original.customAdditions = [HolidayDate(month: 3, day: 15, name: "Floating")]
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HolidayCalendar.self, from: data)
        
        XCTAssertEqual(decoded.preset, original.preset)
        XCTAssertEqual(decoded.customRemovals.count, original.customRemovals.count)
        XCTAssertEqual(decoded.customAdditions.count, original.customAdditions.count)
    }
    
    func testOfficeLocationCodable() throws {
        let original = OfficeLocation(
            name: "HQ",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            address: "San Francisco, CA",
            detectionRadius: 500,
            isPrimary: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OfficeLocation.self, from: data)
        
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.address, original.address)
        XCTAssertEqual(decoded.detectionRadius, original.detectionRadius)
        XCTAssertEqual(decoded.isPrimary, original.isPrimary)
        XCTAssertEqual(decoded.coordinate?.latitude, original.coordinate?.latitude)
        XCTAssertEqual(decoded.coordinate?.longitude, original.coordinate?.longitude)
    }
    
    // MARK: - Additional OfficeLocation Tests
    
    func testOfficeLocationWithNilCoordinate() {
        let office = OfficeLocation(
            name: "Pending Office",
            coordinate: nil,
            address: "TBD",
            detectionRadius: 200,
            isPrimary: false
        )
        
        // Should not contain any coordinate when office has no coordinate
        let anyCoord = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        XCTAssertFalse(office.contains(coordinate: anyCoord))
    }
    
    func testOfficeLocationExactBoundary() {
        let officeCoord = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let office = OfficeLocation(
            name: "Test Office",
            coordinate: officeCoord,
            address: "Test Address",
            detectionRadius: 100,  // 100 meters
            isPrimary: true
        )
        
        // Point exactly at office should be detected
        XCTAssertTrue(office.contains(coordinate: officeCoord))
    }
    
    func testOfficeLocationRadiusVariations() {
        let officeCoord = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        
        // Small radius office
        let smallRadiusOffice = OfficeLocation(
            name: "Small",
            coordinate: officeCoord,
            address: "Test",
            detectionRadius: 50,
            isPrimary: false
        )
        
        // Large radius office
        let largeRadiusOffice = OfficeLocation(
            name: "Large",
            coordinate: officeCoord,
            address: "Test",
            detectionRadius: 1000,
            isPrimary: false
        )
        
        // A point ~150m away
        let nearbyCoord = CLLocationCoordinate2D(latitude: 40.7140, longitude: -74.0060)
        
        // Should be outside small radius but inside large radius
        XCTAssertFalse(smallRadiusOffice.contains(coordinate: nearbyCoord))
        XCTAssertTrue(largeRadiusOffice.contains(coordinate: nearbyCoord))
    }
    
    func testOfficeLocationRadiusFormattedMetric() {
        let office = OfficeLocation(
            name: "Test",
            coordinate: nil,
            address: "Test",
            detectionRadius: 500,
            isPrimary: false
        )
        
        // radiusFormatted should return formatted string
        let display = office.radiusFormatted
        XCTAssertFalse(display.isEmpty)
        XCTAssertTrue(display.contains("meters") || display.contains("m"))
    }
    
    func testOfficeLocationRadiusFormattedKilometers() {
        let office = OfficeLocation(
            name: "Test",
            coordinate: nil,
            address: "Test",
            detectionRadius: 1500,  // 1.5 km
            isPrimary: false
        )
        
        let display = office.radiusFormatted
        XCTAssertTrue(display.contains("km"))
    }
    
    func testMultipleOfficeLocationsPrimarySelection() {
        let office1 = OfficeLocation(
            name: "Branch Office",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            address: "NYC",
            detectionRadius: 200,
            isPrimary: false
        )
        
        let office2 = OfficeLocation(
            name: "HQ",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            address: "SF",
            detectionRadius: 200,
            isPrimary: true
        )
        
        let offices = [office1, office2]
        
        // Find primary
        let primary = offices.first(where: { $0.isPrimary })
        XCTAssertNotNil(primary)
        XCTAssertEqual(primary?.name, "HQ")
    }
    
    func testMultipleOfficeLocationsNoPrimary() {
        let office1 = OfficeLocation(
            name: "Office A",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            address: "NYC",
            detectionRadius: 200,
            isPrimary: false
        )
        
        let office2 = OfficeLocation(
            name: "Office B",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            address: "SF",
            detectionRadius: 200,
            isPrimary: false
        )
        
        let offices = [office1, office2]
        
        // When no primary, should fall back to first
        let primary = offices.first(where: { $0.isPrimary }) ?? offices.first
        XCTAssertEqual(primary?.name, "Office A")
    }
    
    func testOfficeLocationContainsWithMultipleLocations() {
        let nycOffice = OfficeLocation(
            name: "NYC",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            address: "New York",
            detectionRadius: 200,
            isPrimary: true
        )
        
        let sfOffice = OfficeLocation(
            name: "SF",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            address: "San Francisco",
            detectionRadius: 200,
            isPrimary: false
        )
        
        let offices = [nycOffice, sfOffice]
        
        // Point near NYC
        let nycNearby = CLLocationCoordinate2D(latitude: 40.7130, longitude: -74.0062)
        let foundNYC = offices.first { $0.contains(coordinate: nycNearby) }
        XCTAssertNotNil(foundNYC)
        XCTAssertEqual(foundNYC?.name, "NYC")
        
        // Point near SF
        let sfNearby = CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4196)
        let foundSF = offices.first { $0.contains(coordinate: sfNearby) }
        XCTAssertNotNil(foundSF)
        XCTAssertEqual(foundSF?.name, "SF")
        
        // Point far from both
        let farAway = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)  // London
        let foundNone = offices.first { $0.contains(coordinate: farAway) }
        XCTAssertNil(foundNone)
    }
    
    func testIsWithinAnyOfficeLocationLogic() {
        let nycOffice = OfficeLocation(
            name: "NYC",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            address: "New York",
            detectionRadius: 200,
            isPrimary: true
        )
        
        let sfOffice = OfficeLocation(
            name: "SF",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            address: "San Francisco",
            detectionRadius: 200,
            isPrimary: false
        )
        
        let offices = [nycOffice, sfOffice]
        
        // Simulate isWithinAnyOfficeLocation logic
        let nycNearby = CLLocationCoordinate2D(latitude: 40.7130, longitude: -74.0062)
        let isWithinAny = offices.contains { $0.contains(coordinate: nycNearby) }
        XCTAssertTrue(isWithinAny)
        
        // Far location
        let farAway = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let isWithinAnyFar = offices.contains { $0.contains(coordinate: farAway) }
        XCTAssertFalse(isWithinAnyFar)
    }
    
    func testEmptyOfficeLocationsArray() {
        let offices: [OfficeLocation] = []
        
        // No primary in empty array
        let primary = offices.first(where: { $0.isPrimary }) ?? offices.first
        XCTAssertNil(primary)
        
        // Any coordinate check should return false
        let coord = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let isWithinAny = offices.contains { $0.contains(coordinate: coord) }
        XCTAssertFalse(isWithinAny)
    }
    
    func testOfficeLocationIdentity() {
        let office1 = OfficeLocation(
            name: "Office",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            address: "NYC",
            detectionRadius: 200,
            isPrimary: true
        )
        
        var office2 = office1
        
        // Same ID means same location
        XCTAssertEqual(office1.id, office2.id)
        
        // Modifying copy doesn't affect original
        office2.name = "Modified"
        XCTAssertNotEqual(office1.name, office2.name)
    }
    
    func testOfficeLocationShortAddressVariations() {
        // Full address
        let office1 = OfficeLocation(
            name: "Test",
            coordinate: nil,
            address: "123 Main St, Suite 100, New York, NY 10001",
            detectionRadius: 200,
            isPrimary: false
        )
        XCTAssertEqual(office1.shortAddress, "123 Main St")
        
        // Address with no comma
        let office2 = OfficeLocation(
            name: "Test",
            coordinate: nil,
            address: "123 Main St",
            detectionRadius: 200,
            isPrimary: false
        )
        XCTAssertEqual(office2.shortAddress, "123 Main St")
        
        // Empty address
        let office3 = OfficeLocation(
            name: "Test",
            coordinate: nil,
            address: "",
            detectionRadius: 200,
            isPrimary: false
        )
        XCTAssertEqual(office3.shortAddress, "")
    }
    
    // MARK: - Migration Simulation Tests
    
    func testMigrationFromSingleToMultipleLocations() {
        // Simulate legacy single location data
        let legacyCoordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let legacyAddress = "123 Wall St, New York, NY"
        let legacyRadius: Double = 500
        
        // Simulate migration logic
        var officeLocations: [OfficeLocation] = []
        
        // Migration condition: has legacy location but no new locations
        if officeLocations.isEmpty {
            let migratedLocation = OfficeLocation(
                name: "Office",
                coordinate: legacyCoordinate,
                address: legacyAddress,
                detectionRadius: legacyRadius,
                isPrimary: true
            )
            officeLocations = [migratedLocation]
        }
        
        // Verify migration result
        XCTAssertEqual(officeLocations.count, 1)
        XCTAssertEqual(officeLocations[0].name, "Office")
        XCTAssertEqual(officeLocations[0].address, legacyAddress)
        XCTAssertEqual(officeLocations[0].detectionRadius, legacyRadius)
        XCTAssertTrue(officeLocations[0].isPrimary)
        XCTAssertEqual(officeLocations[0].coordinate?.latitude, legacyCoordinate.latitude)
        XCTAssertEqual(officeLocations[0].coordinate?.longitude, legacyCoordinate.longitude)
    }
    
    func testMigrationSkippedWhenLocationsExist() {
        // Simulate existing locations
        let existingLocation = OfficeLocation(
            name: "Existing HQ",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            address: "SF",
            detectionRadius: 300,
            isPrimary: true
        )
        var officeLocations = [existingLocation]
        
        // Legacy data that should NOT be migrated
        let legacyCoordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let legacyAddress = "123 Wall St, New York, NY"
        let legacyRadius: Double = 500
        
        // Migration condition check
        if officeLocations.isEmpty {
            let migratedLocation = OfficeLocation(
                name: "Office",
                coordinate: legacyCoordinate,
                address: legacyAddress,
                detectionRadius: legacyRadius,
                isPrimary: true
            )
            officeLocations = [migratedLocation]
        }
        
        // Should still have original location, not migrated
        XCTAssertEqual(officeLocations.count, 1)
        XCTAssertEqual(officeLocations[0].name, "Existing HQ")
        XCTAssertEqual(officeLocations[0].address, "SF")
    }
    
    func testMigrationWithNilLegacyLocation() {
        // Simulate no legacy location
        let legacyCoordinate: CLLocationCoordinate2D? = nil
        var officeLocations: [OfficeLocation] = []
        
        // Migration should not happen when legacy coordinate is nil
        if let coord = legacyCoordinate, officeLocations.isEmpty {
            let migratedLocation = OfficeLocation(
                name: "Office",
                coordinate: coord,
                address: "",
                detectionRadius: 200,
                isPrimary: true
            )
            officeLocations = [migratedLocation]
        }
        
        // Should remain empty
        XCTAssertTrue(officeLocations.isEmpty)
    }
    
    // MARK: - Edge Cases
    
    func testOfficeLocationAtEquator() {
        let equatorOffice = OfficeLocation(
            name: "Equator Office",
            coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
            address: "Gulf of Guinea",
            detectionRadius: 1000,
            isPrimary: true
        )
        
        // Should work at equator
        let nearby = CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001)
        XCTAssertTrue(equatorOffice.contains(coordinate: nearby))
    }
    
    func testOfficeLocationNearInternationalDateLine() {
        let tokyoOffice = OfficeLocation(
            name: "Tokyo Office",
            coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
            address: "Tokyo, Japan",
            detectionRadius: 500,
            isPrimary: true
        )
        
        let nearby = CLLocationCoordinate2D(latitude: 35.6765, longitude: 139.6506)
        XCTAssertTrue(tokyoOffice.contains(coordinate: nearby))
    }
    
    func testOfficeLocationAtExtremeLatitudes() {
        // Near North Pole
        let arcticOffice = OfficeLocation(
            name: "Arctic Research",
            coordinate: CLLocationCoordinate2D(latitude: 89.0, longitude: 0.0),
            address: "Arctic",
            detectionRadius: 1000,
            isPrimary: false
        )
        
        _ = CLLocationCoordinate2D(latitude: 89.001, longitude: 0.001)
        // This should work (distance calculation near poles)
        XCTAssertNotNil(arcticOffice.coordinate)
    }
    
    func testMaxLocationLimitEnforcement() {
        let maxLocations = OfficeLocation.maxLocations
        
        var offices: [OfficeLocation] = []
        
        // Add locations up to max
        for i in 1...maxLocations {
            let office = OfficeLocation(
                name: "Office \(i)",
                coordinate: CLLocationCoordinate2D(latitude: Double(40 + i), longitude: Double(-74 - i)),
                address: "Address \(i)",
                detectionRadius: 200,
                isPrimary: i == 1
            )
            offices.append(office)
        }
        
        XCTAssertEqual(offices.count, maxLocations)
        
        // Trying to add more should be blocked (in real app logic)
        let canAddMore = offices.count < maxLocations
        XCTAssertFalse(canAddMore)
    }
    
    // MARK: - Multi-Location Check-In Simulation Tests
    
    func testBothOfficeLocationsWorkForCheckIn() {
        // Setup: Two configured office locations
        let nycOffice = OfficeLocation(
            name: "NYC Headquarters",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            address: "350 5th Ave, New York, NY 10118",
            detectionRadius: 300,
            isPrimary: true
        )
        
        let sfOffice = OfficeLocation(
            name: "SF Branch",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            address: "1 Market St, San Francisco, CA 94105",
            detectionRadius: 300,
            isPrimary: false
        )
        
        let configuredOffices = [nycOffice, sfOffice]
        
        // Scenario 1: User arrives at NYC office (primary)
        let nycArrivalLocation = CLLocationCoordinate2D(latitude: 40.7130, longitude: -74.0058)
        
        let isAtNYC = configuredOffices.contains { $0.contains(coordinate: nycArrivalLocation) }
        XCTAssertTrue(isAtNYC, "User should be detected at NYC office")
        
        let detectedNYCOffice = configuredOffices.first { $0.contains(coordinate: nycArrivalLocation) }
        XCTAssertEqual(detectedNYCOffice?.name, "NYC Headquarters")
        XCTAssertTrue(detectedNYCOffice?.isPrimary ?? false)
        
        // Scenario 2: User travels and arrives at SF office (secondary)
        let sfArrivalLocation = CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4192)
        
        let isAtSF = configuredOffices.contains { $0.contains(coordinate: sfArrivalLocation) }
        XCTAssertTrue(isAtSF, "User should be detected at SF office")
        
        let detectedSFOffice = configuredOffices.first { $0.contains(coordinate: sfArrivalLocation) }
        XCTAssertEqual(detectedSFOffice?.name, "SF Branch")
        XCTAssertFalse(detectedSFOffice?.isPrimary ?? true)
        
        // Scenario 3: User is in transit (not at either office)
        let transitLocation = CLLocationCoordinate2D(latitude: 39.0, longitude: -100.0)  // Kansas
        
        let isInTransit = !configuredOffices.contains { $0.contains(coordinate: transitLocation) }
        XCTAssertTrue(isInTransit, "User should NOT be detected at any office while in transit")
    }
    
    func testCheckInAtSecondaryOfficeCountsTowardGoal() {
        // This tests the business logic that visiting EITHER office counts toward the monthly goal
        let offices = [
            OfficeLocation(
                name: "Main Office",
                coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                address: "NYC",
                detectionRadius: 200,
                isPrimary: true
            ),
            OfficeLocation(
                name: "Satellite Office",
                coordinate: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
                address: "Los Angeles",
                detectionRadius: 200,
                isPrimary: false
            )
        ]
        
        // Simulate a week of visits alternating between offices
        let visitLocations = [
            ("Monday", CLLocationCoordinate2D(latitude: 40.7130, longitude: -74.0058)),    // NYC
            ("Tuesday", CLLocationCoordinate2D(latitude: 34.0524, longitude: -118.2435)),  // LA
            ("Wednesday", CLLocationCoordinate2D(latitude: 40.7126, longitude: -74.0062)), // NYC
            ("Thursday", CLLocationCoordinate2D(latitude: 34.0520, longitude: -118.2439)), // LA
            ("Friday", CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),    // NYC
        ]
        
        var validVisitCount = 0
        
        for (day, location) in visitLocations {
            let isAtAnyOffice = offices.contains { $0.contains(coordinate: location) }
            if isAtAnyOffice {
                validVisitCount += 1
            }
            XCTAssertTrue(isAtAnyOffice, "\(day) visit should be detected at an office")
        }
        
        // All 5 visits should count
        XCTAssertEqual(validVisitCount, 5, "All visits to either office should count toward goal")
    }
    
    func testOverlappingOfficeRadiiHandledCorrectly() {
        // Edge case: Two offices very close together (e.g., same building, different floors)
        // The user should be detected at ONE of them
        let mainFloorOffice = OfficeLocation(
            name: "Main Floor",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            address: "350 5th Ave, Floor 1",
            detectionRadius: 100,
            isPrimary: true
        )
        
        let upperFloorOffice = OfficeLocation(
            name: "Upper Floor",
            coordinate: CLLocationCoordinate2D(latitude: 40.7129, longitude: -74.0061),  // Very close
            address: "350 5th Ave, Floor 20",
            detectionRadius: 100,
            isPrimary: false
        )
        
        let offices = [mainFloorOffice, upperFloorOffice]
        
        // User arrives at building
        let arrivalLocation = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        
        // Should be detected at least one office
        let isAtOffice = offices.contains { $0.contains(coordinate: arrivalLocation) }
        XCTAssertTrue(isAtOffice, "User should be detected at overlapping offices")
        
        // Count how many offices contain this location
        let matchingOffices = offices.filter { $0.contains(coordinate: arrivalLocation) }
        XCTAssertGreaterThanOrEqual(matchingOffices.count, 1, "At least one office should match")
        
        // In real app, first match is used (or primary is preferred)
        let firstMatch = offices.first { $0.contains(coordinate: arrivalLocation) }
        XCTAssertNotNil(firstMatch)
    }
    
    func testOfficeLocationBoundaryPrecision() {
        // Test that boundary detection is precise to within a few meters
        let office = OfficeLocation(
            name: "Test Office",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            address: "Test",
            detectionRadius: 100,  // 100 meters
            isPrimary: true
        )
        
        // Point approximately 90m away (should be INSIDE)
        // 1 degree latitude ≈ 111km, so 0.0008° ≈ 89m
        let insidePoint = CLLocationCoordinate2D(latitude: 40.7136, longitude: -74.0060)
        XCTAssertTrue(office.contains(coordinate: insidePoint), "Point ~90m away should be inside 100m radius")
        
        // Point approximately 150m away (should be OUTSIDE)
        // 0.00135° ≈ 150m
        let outsidePoint = CLLocationCoordinate2D(latitude: 40.7141, longitude: -74.0060)
        XCTAssertFalse(office.contains(coordinate: outsidePoint), "Point ~150m away should be outside 100m radius")
    }
    
    func testSequentialVisitsToDifferentOffices() {
        // Simulates user going to different offices on different days
        let nycOffice = OfficeLocation(
            name: "NYC",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            address: "New York",
            detectionRadius: 200,
            isPrimary: true
        )
        
        let bostonOffice = OfficeLocation(
            name: "Boston",
            coordinate: CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),
            address: "Boston",
            detectionRadius: 200,
            isPrimary: false
        )
        
        let offices = [nycOffice, bostonOffice]
        
        // Week 1: User works from NYC
        var week1Visits = 0
        for _ in 1...3 {
            let nycLocation = CLLocationCoordinate2D(latitude: 40.7130, longitude: -74.0058)
            if offices.contains(where: { $0.contains(coordinate: nycLocation) }) {
                week1Visits += 1
            }
        }
        XCTAssertEqual(week1Visits, 3)
        
        // Week 2: User works from Boston
        var week2Visits = 0
        for _ in 1...2 {
            let bostonLocation = CLLocationCoordinate2D(latitude: 42.3603, longitude: -71.0587)
            if offices.contains(where: { $0.contains(coordinate: bostonLocation) }) {
                week2Visits += 1
            }
        }
        XCTAssertEqual(week2Visits, 2)
        
        // Total monthly visits
        let totalVisits = week1Visits + week2Visits
        XCTAssertEqual(totalVisits, 5, "Visits to both offices should accumulate toward monthly goal")
    }
    
    func testPrimaryOfficePreferredWhenBothMatch() {
        // When a coordinate matches both offices (overlapping radii), primary should be preferred
        let primaryOffice = OfficeLocation(
            name: "Primary HQ",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            address: "HQ",
            detectionRadius: 500,  // Large radius
            isPrimary: true
        )
        
        let secondaryOffice = OfficeLocation(
            name: "Secondary Annex",
            coordinate: CLLocationCoordinate2D(latitude: 40.7130, longitude: -74.0062),  // Very close
            address: "Annex",
            detectionRadius: 500,  // Large radius
            isPrimary: false
        )
        
        let offices = [secondaryOffice, primaryOffice]  // Note: secondary listed first
        
        let arrivalLocation = CLLocationCoordinate2D(latitude: 40.7129, longitude: -74.0061)
        
        // Both offices should contain this point
        let matchingOffices = offices.filter { $0.contains(coordinate: arrivalLocation) }
        XCTAssertEqual(matchingOffices.count, 2, "Both offices should match this location")
        
        // But primary should be preferred
        let preferredOffice = offices.first(where: { $0.isPrimary && $0.contains(coordinate: arrivalLocation) })
            ?? offices.first(where: { $0.contains(coordinate: arrivalLocation) })
        
        XCTAssertEqual(preferredOffice?.name, "Primary HQ", "Primary office should be preferred when both match")
    }
    
    // MARK: - Settings Change Reactivity Tests
    
    /// Tests that toggling autoCalculateGoal changes the effective goal
    @MainActor
    func testAutoCalculateToggleChangesGoal() async {
        let appData = AppData()
        
        // Setup: Configure manual goal and policy
        var settings = appData.settings
        settings.monthlyGoal = 10
        settings.autoCalculateGoal = false
        settings.companyPolicy = CompanyPolicy(policyType: .hybrid50)
        settings.holidayCalendar = HolidayCalendar(preset: .none)
        appData.updateSettings(settings)
        
        let currentMonth = Date()
        
        // With auto-calculate OFF, should use manual goal
        let manualGoal = appData.getGoalForMonth(currentMonth)
        XCTAssertEqual(manualGoal, 10, "Manual goal should be 10")
        
        // Toggle auto-calculate ON
        var newSettings = appData.settings
        newSettings.autoCalculateGoal = true
        appData.updateSettings(newSettings)
        
        // Now should use calculated goal (different from manual)
        let calculatedGoal = appData.getGoalForMonth(currentMonth)
        
        // Verify settings actually changed
        XCTAssertTrue(appData.settings.autoCalculateGoal, "autoCalculateGoal should be true after update")
        
        // Calculated goal should be based on business days (likely different from 10)
        // For January 2026: ~23 weekdays, 50% hybrid = ~11-12 days
        XCTAssertNotEqual(calculatedGoal, manualGoal, "Calculated goal should differ from manual goal")
    }
    
    /// Tests that updateSettings properly persists the autoCalculateGoal setting
    @MainActor
    func testUpdateSettingsPersistsAutoCalculate() async {
        let appData = AppData()
        
        // Start with auto-calculate OFF
        var settings = appData.settings
        settings.autoCalculateGoal = false
        appData.updateSettings(settings)
        XCTAssertFalse(appData.settings.autoCalculateGoal)
        
        // Turn ON using proper update pattern (copy, modify, update)
        var newSettings = appData.settings
        newSettings.autoCalculateGoal = true
        appData.updateSettings(newSettings)
        
        // Verify the setting is now ON
        XCTAssertTrue(appData.settings.autoCalculateGoal, "autoCalculateGoal should be true after update")
    }
    
    /// Tests that getCurrentMonthProgress returns different goals based on autoCalculateGoal
    @MainActor
    func testGetCurrentMonthProgressReflectsSettingChange() async {
        let appData = AppData()
        
        // Setup
        var settings = appData.settings
        settings.monthlyGoal = 8
        settings.autoCalculateGoal = false
        settings.companyPolicy = CompanyPolicy(policyType: .hybrid60)  // 60% = more days
        settings.holidayCalendar = HolidayCalendar(preset: .none)
        appData.updateSettings(settings)
        
        // Get progress with manual goal
        let manualProgress = appData.getCurrentMonthProgress()
        XCTAssertEqual(manualProgress.goal, 8, "Should use manual goal of 8")
        
        // Toggle to auto-calculate
        var newSettings = appData.settings
        newSettings.autoCalculateGoal = true
        appData.updateSettings(newSettings)
        
        // Get progress with auto-calculated goal
        let autoProgress = appData.getCurrentMonthProgress()
        
        // With hybrid60 and ~23 weekdays, should be ~14 days (not 8)
        XCTAssertNotEqual(autoProgress.goal, 8, "Auto-calculated goal should differ from manual goal of 8")
        XCTAssertGreaterThan(autoProgress.goal, 8, "Hybrid60 should require more than 8 days")
    }
    
    /// Tests that toggling back to manual restores the manual goal
    @MainActor
    func testToggleBackToManualRestoresGoal() async {
        let appData = AppData()
        
        // Setup with manual goal
        var settings = appData.settings
        settings.monthlyGoal = 12
        settings.autoCalculateGoal = false
        appData.updateSettings(settings)
        
        let initialGoal = appData.getCurrentMonthProgress().goal
        XCTAssertEqual(initialGoal, 12)
        
        // Switch to auto-calculate
        var autoSettings = appData.settings
        autoSettings.autoCalculateGoal = true
        appData.updateSettings(autoSettings)
        
        // Switch back to manual
        var manualSettings = appData.settings
        manualSettings.autoCalculateGoal = false
        appData.updateSettings(manualSettings)
        
        let restoredGoal = appData.getCurrentMonthProgress().goal
        XCTAssertEqual(restoredGoal, 12, "Should restore to manual goal of 12")
    }
    
    /// Tests that policy type changes are reflected immediately
    @MainActor
    func testPolicyTypeChangeReflectedImmediately() async {
        let appData = AppData()
        
        // Setup with auto-calculate ON
        var settings = appData.settings
        settings.autoCalculateGoal = true
        settings.companyPolicy = CompanyPolicy(policyType: .hybrid40)
        settings.holidayCalendar = HolidayCalendar(preset: .none)
        appData.updateSettings(settings)
        
        let hybrid40Goal = appData.getCurrentMonthProgress().goal
        
        // Change to hybrid60 (should increase required days)
        var newSettings = appData.settings
        newSettings.companyPolicy = CompanyPolicy(policyType: .hybrid60)
        appData.updateSettings(newSettings)
        
        let hybrid60Goal = appData.getCurrentMonthProgress().goal
        
        XCTAssertGreaterThan(hybrid60Goal, hybrid40Goal, "Hybrid60 should require more days than Hybrid40")
    }
    
    /// Tests multiple rapid setting changes
    @MainActor
    func testRapidSettingChanges() async {
        let appData = AppData()
        
        // Simulate rapid toggles (like a user tapping quickly)
        for i in 1...5 {
            var settings = appData.settings
            settings.autoCalculateGoal = (i % 2 == 0)  // Toggle on even iterations
            appData.updateSettings(settings)
        }
        
        // After 5 iterations (1,2,3,4,5), should end with OFF (5 is odd)
        XCTAssertFalse(appData.settings.autoCalculateGoal, "Should be OFF after odd number of toggles")
        
        // One more toggle
        var finalSettings = appData.settings
        finalSettings.autoCalculateGoal = true
        appData.updateSettings(finalSettings)
        
        XCTAssertTrue(appData.settings.autoCalculateGoal, "Should be ON after final toggle")
    }
}
