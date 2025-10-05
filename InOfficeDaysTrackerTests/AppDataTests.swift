//
//  AppDataTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for AppData critical functions including visit management and progress calculations
//

import Testing
import Foundation
import CoreLocation
@testable import InOfficeDaysTracker

@MainActor
struct AppDataTests {
    
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
    
    // MARK: - Visit Management Tests
    
    @Test("AppData - Start office visit")
    func testStartOfficeVisit() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        
        appData.startVisit(at: testCoord)
        
        #expect(appData.isCurrentlyInOffice == true)
        #expect(appData.currentVisit != nil)
        #expect(appData.currentVisit?.isActiveSession == true)
        #expect(appData.visits.count == 1)
    }
    
    @Test("AppData - End office visit")
    func testEndOfficeVisit() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        
        // Start visit
        appData.startVisit(at: testCoord)
        #expect(appData.isCurrentlyInOffice == true)
        
        // End visit
        appData.endVisit()
        
        #expect(appData.isCurrentlyInOffice == false)
        #expect(appData.currentVisit == nil)
        #expect(appData.visits.count == 1)
        #expect(appData.visits.first?.isActiveSession == false)
    }
    
    @Test("AppData - Multiple visits same day")
    func testMultipleVisitsSameDay() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        
        // First visit
        appData.startVisit(at: testCoord)
        appData.endVisit()
        
        // Second visit (same day)
        appData.startVisit(at: testCoord)
        appData.endVisit()
        
        #expect(appData.visits.count == 1) // Should merge into single visit
        #expect(appData.visits.first?.events.count == 2) // With two events
    }
    
    @Test("AppData - Cannot start visit when already in office")
    func testCannotStartWhenInOffice() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        
        // Start first visit
        appData.startVisit(at: testCoord)
        let firstVisitId = appData.currentVisit?.id
        
        // Try to start second visit (should be ignored)
        appData.startVisit(at: testCoord)
        
        #expect(appData.currentVisit?.id == firstVisitId) // Should be same visit
        #expect(appData.visits.count == 1) // Should not create new visit
    }
    
    @Test("AppData - Cannot end visit when not in office")
    func testCannotEndWhenNotInOffice() async throws {
        let appData = createTestAppData()
        
        // Try to end visit without starting
        appData.endVisit()
        
        #expect(appData.isCurrentlyInOffice == false)
        #expect(appData.currentVisit == nil)
        #expect(appData.visits.count == 0)
    }
    
    // MARK: - Progress Calculation Tests
    
    @Test("AppData - Monthly progress with completed visits")
    func testMonthlyProgressCalculation() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        
        // Set goal to 10 days
        var settings = appData.settings
        settings.monthlyGoal = 10
        appData.updateSettings(settings)
        
        // Add some completed visits for current month
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.dateInterval(of: .month, for: now)!.start
        
        for i in 0..<5 {
            let visitDate = calendar.date(byAdding: .day, value: i, to: monthStart)!
            let event = OfficeEvent(
                entryTime: visitDate,
                exitTime: visitDate.addingTimeInterval(3600) // 1 hour
            )
            let visit = OfficeVisit(date: visitDate, events: [event], coordinate: testCoord)
            appData.visits.append(visit)
        }
        
        let progress = appData.getCurrentMonthProgress()
        
        #expect(progress.current == 5)
        #expect(progress.goal == 10)
        #expect(progress.percentage == 0.5)
    }
    
    @Test("AppData - Progress with active visit")
    func testProgressWithActiveVisit() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        
        // Set goal
        var settings = appData.settings
        settings.monthlyGoal = 10
        appData.updateSettings(settings)
        
        // Add completed visit from yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let completedEvent = OfficeEvent(
            entryTime: yesterday.addingTimeInterval(3600), // 1 hour from start of yesterday
            exitTime: yesterday.addingTimeInterval(7200) // 2 hours from start (1 hour duration)
        )
        let completedVisit = OfficeVisit(date: yesterday, events: [completedEvent], coordinate: testCoord)
        appData.visits.append(completedVisit)
        
        // Start active visit today
        appData.startVisit(at: testCoord)
        
        let progress = appData.getCurrentMonthProgress()
        
        #expect(progress.current == 2) // 1 completed + 1 active
        #expect(progress.goal == 10)
        #expect(progress.percentage == 0.2)
    }
    
    @Test("AppData - Get valid visits filters correctly")
    func testGetValidVisits() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        
        let now = Date()
        
        // Valid visit (1 hour)
        let validEvent = OfficeEvent(
            entryTime: now.addingTimeInterval(-7200), // 2 hours ago
            exitTime: now.addingTimeInterval(-3600) // 1 hour ago (1 hour duration)
        )
        let validVisit = OfficeVisit(date: now, events: [validEvent], coordinate: testCoord)
        
        // Invalid visit (10 minutes - too short)
        let invalidEvent = OfficeEvent(
            entryTime: now.addingTimeInterval(-1800), // 30 minutes ago
            exitTime: now.addingTimeInterval(-1200) // 20 minutes ago (10 min duration)
        )
        let invalidVisit = OfficeVisit(date: now, events: [invalidEvent], coordinate: testCoord)
        
        // Active visit (should be excluded from valid visits)
        let activeEvent = OfficeEvent(entryTime: now.addingTimeInterval(-600), exitTime: nil)
        let activeVisit = OfficeVisit(date: now, events: [activeEvent], coordinate: testCoord)
        
        appData.visits = [validVisit, invalidVisit, activeVisit]
        
        let validVisits = appData.getValidVisits(for: now)
        
        #expect(validVisits.count == 1) // Only the valid completed visit
        #expect(validVisits.first?.id == validVisit.id)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test("AppData - Progress calculation with zero goal")
    func testProgressWithZeroGoal() async throws {
        let appData = createTestAppData()
        
        // Set goal to 0
        var settings = appData.settings
        settings.monthlyGoal = 0
        appData.updateSettings(settings)
        
        let progress = appData.getCurrentMonthProgress()
        
        #expect(progress.current == 0)
        #expect(progress.goal == 0)
        #expect(progress.percentage == 0.0) // Should handle division by zero
    }
    
    @Test("AppData - Visits from previous month excluded")
    func testPreviousMonthVisitsExcluded() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        
        let calendar = Calendar.current
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        
        // Add visit from last month
        let oldEvent = OfficeEvent(
            entryTime: lastMonth,
            exitTime: lastMonth.addingTimeInterval(3600)
        )
        let oldVisit = OfficeVisit(date: lastMonth, events: [oldEvent], coordinate: testCoord)
        
        // Add visit from current month
        let currentEvent = OfficeEvent(
            entryTime: now.addingTimeInterval(-3600),
            exitTime: now
        )
        let currentVisit = OfficeVisit(date: now, events: [currentEvent], coordinate: testCoord)
        
        appData.visits = [oldVisit, currentVisit]
        
        let progress = appData.getCurrentMonthProgress()
        
        #expect(progress.current == 1) // Only current month visit
    }
    
    @Test("AppData - Settings persistence")
    func testSettingsPersistence() async throws {
        let appData = createTestAppData()
        
        // Update settings
        var newSettings = AppSettings()
        newSettings.monthlyGoal = 15
        newSettings.trackingDays = [2, 3, 4, 5, 6] // Mon-Fri
        newSettings.isSetupComplete = true
        
        appData.updateSettings(newSettings)
        
        #expect(appData.settings.monthlyGoal == 15)
        #expect(appData.settings.trackingDays == [2, 3, 4, 5, 6])
        #expect(appData.settings.isSetupComplete == true)
    }
}