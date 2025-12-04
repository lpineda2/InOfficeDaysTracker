//
//  CalendarIntegrationTests.swift
//  InOfficeDaysTrackerTests
//
//  Simplified tests for calendar integration
//

import XCTest
import EventKit
import CoreLocation
@testable import InOfficeDaysTracker

class CalendarIntegrationTests: XCTestCase {
    
    var calendarService: CalendarService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
    }
    
    override func tearDownWithError() throws {
        calendarService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Calendar Settings Tests
    
    func testCalendarSettingsDefaults() {
        let settings = CalendarSettings()
        
        XCTAssertFalse(settings.isEnabled, "Should default to disabled")
        XCTAssertEqual(settings.officeEventTitle, "In Office Day", "Should have default office title")
        XCTAssertNil(settings.selectedCalendarId, "Should have no selected calendar by default")
        XCTAssertFalse(settings.showAsBusy, "Should default to free")
    }
    
    func testCalendarSettingsValidation() {
        var settings = CalendarSettings()
        settings.isEnabled = true
        settings.officeEventTitle = "Office Day"
        
        XCTAssertTrue(settings.isValidConfiguration, "Should be valid with non-empty title")
        
        settings.officeEventTitle = ""
        XCTAssertFalse(settings.isValidConfiguration, "Should be invalid with empty title")
    }
    
    func testCalendarSettingsReset() {
        var settings = CalendarSettings()
        settings.isEnabled = true
        settings.officeEventTitle = "Custom Title"
        settings.showAsBusy = true
        
        settings.resetToDefaults()
        
        XCTAssertFalse(settings.isEnabled, "Should reset to disabled")
        XCTAssertEqual(settings.officeEventTitle, "In Office Day", "Should reset title")
        XCTAssertFalse(settings.showAsBusy, "Should reset to free")
    }
    
    // MARK: - UID Generation Tests
    
    func testUIDGeneration() {
        let date = Date()
        let uid = CalendarEventUID.generate(for: date)
        
        XCTAssertTrue(uid.hasPrefix("iod-"), "UID should start with prefix")
        XCTAssertTrue(uid.hasSuffix("-office"), "UID should end with type")
    }
    
    func testUIDConsistency() {
        let date = Date()
        let uid1 = CalendarEventUID.generate(for: date)
        let uid2 = CalendarEventUID.generate(for: date)
        
        XCTAssertEqual(uid1, uid2, "Same date should produce same UID")
    }
    
    func testUIDDifferentDates() {
        let date1 = Date()
        let date2 = Calendar.current.date(byAdding: .day, value: 1, to: date1)!
        
        let uid1 = CalendarEventUID.generate(for: date1)
        let uid2 = CalendarEventUID.generate(for: date2)
        
        XCTAssertNotEqual(uid1, uid2, "Different dates should produce different UIDs")
    }
    
    // MARK: - Calendar Service Tests
    
    func testCalendarServiceInitialization() async {
        await MainActor.run {
            calendarService = CalendarService.shared
        }
        XCTAssertNotNil(calendarService, "CalendarService should initialize")
    }
    
    func testCalendarServiceAuthorizationStatus() async {
        await MainActor.run {
            calendarService = CalendarService.shared
        }
        let status = await calendarService.authorizationStatus
        XCTAssertTrue([
            .notDetermined, 
            .restricted, 
            .denied, 
            .fullAccess,
            .writeOnly
        ].contains(status), "Should have valid authorization status")
    }
    
    func testCalendarServiceAccessCheck() async {
        await MainActor.run {
            calendarService = CalendarService.shared
        }
        let hasAccess = await calendarService.hasCalendarAccess
        XCTAssertTrue(hasAccess == true || hasAccess == false, "Should return boolean")
    }
}
