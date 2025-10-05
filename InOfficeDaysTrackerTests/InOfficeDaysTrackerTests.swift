//
//  InOfficeDaysTrackerTests.swift
//  InOfficeDaysTrackerTests
//
//  Comprehensive unit tests for InOfficeDaysTracker critical functions
//

import Testing
import Foundation
import CoreLocation
@testable import InOfficeDaysTracker

struct InOfficeDaysTrackerTests {
    
    // MARK: - OfficeVisit Tests
    
    @Test("OfficeVisit - Single completed event duration calculation")
    func testOfficeVisitSingleCompletedEvent() async throws {
        let entryTime = Date()
        let exitTime = entryTime.addingTimeInterval(3600) // 1 hour later
        let event = OfficeEvent(entryTime: entryTime, exitTime: exitTime)
        
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let visit = OfficeVisit(date: entryTime, events: [event], coordinate: coordinate)
        
        #expect(visit.duration == 3600)
        #expect(visit.exitTime == exitTime)
        #expect(visit.entryTime == entryTime)
        #expect(visit.isActiveSession == false)
        #expect(visit.isValidVisit == true)
    }
    
    @Test("OfficeVisit - Active session (no exit time)")
    func testOfficeVisitActiveSession() async throws {
        let entryTime = Date()
        let event = OfficeEvent(entryTime: entryTime, exitTime: nil)
        
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let visit = OfficeVisit(date: entryTime, events: [event], coordinate: coordinate)
        
        #expect(visit.duration == nil)
        #expect(visit.exitTime == nil)
        #expect(visit.entryTime == entryTime)
        #expect(visit.isActiveSession == true)
        #expect(visit.isValidVisit == false) // Not valid until completed
    }
    
    @Test("OfficeVisit - Multiple events total duration")
    func testOfficeVisitMultipleEvents() async throws {
        let baseTime = Date()
        
        // First event: 1 hour
        let event1 = OfficeEvent(
            entryTime: baseTime,
            exitTime: baseTime.addingTimeInterval(3600)
        )
        
        // Second event: 2 hours  
        let event2 = OfficeEvent(
            entryTime: baseTime.addingTimeInterval(7200), // 2 hours later
            exitTime: baseTime.addingTimeInterval(14400) // 4 hours from start
        )
        
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let visit = OfficeVisit(date: baseTime, events: [event1, event2], coordinate: coordinate)
        
        #expect(visit.duration == 10800) // 1 hour + 2 hours = 3 hours total
        #expect(visit.isActiveSession == false)
        #expect(visit.isValidVisit == true)
    }
    
    @Test("OfficeVisit - Multiple events with active session")
    func testOfficeVisitMultipleEventsWithActive() async throws {
        let baseTime = Date()
        
        // First event: completed (1 hour)
        let event1 = OfficeEvent(
            entryTime: baseTime,
            exitTime: baseTime.addingTimeInterval(3600)
        )
        
        // Second event: active (no exit time)
        let event2 = OfficeEvent(
            entryTime: baseTime.addingTimeInterval(7200),
            exitTime: nil
        )
        
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let visit = OfficeVisit(date: baseTime, events: [event1, event2], coordinate: coordinate)
        
        #expect(visit.duration == nil) // Should be nil because session is active
        #expect(visit.exitTime == nil) // Should be nil because session is active
        #expect(visit.isActiveSession == true)
        #expect(visit.isValidVisit == false)
    }
    
    @Test("OfficeVisit - Empty events array")
    func testOfficeVisitEmptyEvents() async throws {
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let visit = OfficeVisit(date: Date(), events: [], coordinate: coordinate)
        
        #expect(visit.duration == nil)
        #expect(visit.exitTime == nil)
        #expect(visit.isActiveSession == false)
        #expect(visit.isValidVisit == false)
    }
    
    @Test("OfficeVisit - Duration validation (minimum 1 hour)")
    func testOfficeVisitDurationValidation() async throws {
        let baseTime = Date()
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Test short visit (10 minutes - should be invalid)
        let shortEvent = OfficeEvent(
            entryTime: baseTime,
            exitTime: baseTime.addingTimeInterval(600) // 10 minutes
        )
        let shortVisit = OfficeVisit(date: baseTime, events: [shortEvent], coordinate: coordinate)
        
        #expect(shortVisit.isValidVisit == false)
        
        // Test valid visit (1 hour - should be valid)
        let validEvent = OfficeEvent(
            entryTime: baseTime,
            exitTime: baseTime.addingTimeInterval(3600) // 1 hour
        )
        let validVisit = OfficeVisit(date: baseTime, events: [validEvent], coordinate: coordinate)
        
        #expect(validVisit.isValidVisit == true)
    }
    
    // MARK: - OfficeEvent Tests
    
    @Test("OfficeEvent - Duration calculation")
    func testOfficeEventDuration() async throws {
        let entryTime = Date()
        let exitTime = entryTime.addingTimeInterval(7200) // 2 hours
        
        let event = OfficeEvent(entryTime: entryTime, exitTime: exitTime)
        
        #expect(event.duration == 7200)
    }
    
    @Test("OfficeEvent - Active event (no exit time)")
    func testOfficeEventActive() async throws {
        let entryTime = Date()
        let event = OfficeEvent(entryTime: entryTime, exitTime: nil)
        
        #expect(event.duration == nil)
    }
}
