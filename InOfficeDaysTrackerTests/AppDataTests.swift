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
        // Ensure tests start with a clean settings state (avoid persisted UserDefaults interference)
        appData.updateSettings(AppSettings())
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
        
        let calendar = Calendar.current
        let now = Date()
        let dayOfMonth = calendar.component(.day, from: now)
        
        if dayOfMonth > 1 {
            // Normal case: We can have a completed visit on an earlier day AND an active visit today
            // Add completed visit from earlier this month (on a DIFFERENT day than today)
            let completedDate = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: now),
                month: calendar.component(.month, from: now),
                day: 1,
                hour: 10
            ))!
            
            let completedEvent = OfficeEvent(
                entryTime: completedDate,
                exitTime: completedDate.addingTimeInterval(3600) // 1 hour duration
            )
            let completedVisit = OfficeVisit(date: completedDate, events: [completedEvent], coordinate: testCoord)
            appData.visits.append(completedVisit)
            
            // Start active visit today (different day)
            appData.startVisit(at: testCoord)
            
            let progress = appData.getCurrentMonthProgress()
            
            #expect(progress.current == 2) // 1 completed + 1 active (on different days)
            #expect(progress.goal == 10)
            #expect(progress.percentage == 0.2)
        } else {
            // Edge case: First day of month - can't have 2 different days
            // Test that a single active visit counts toward progress
            appData.startVisit(at: testCoord)
            
            let progress = appData.getCurrentMonthProgress()
            
            #expect(progress.current == 1) // 1 active visit on day 1
            #expect(progress.goal == 10)
            #expect(progress.percentage == 0.1)
        }
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
        
        // Disable auto-calculate and set goal to 0
        var settings = appData.settings
        settings.autoCalculateGoal = false
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

    @Test("AppData - Streak counts previous months when current month not met")
    func testStreakCountsPreviousWhenCurrentNotMet() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        var settings = appData.settings
        settings.monthlyGoal = 2
        settings.autoCalculateGoal = false
        appData.updateSettings(settings)

        let calendar = Calendar.current
        let now = Date()

        // Previous month (met goal with 2 visits)
        let prevMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        let prevDay1 = calendar.date(from: DateComponents(year: calendar.component(.year, from: prevMonth), month: calendar.component(.month, from: prevMonth), day: 5))!
        let prevDay2 = calendar.date(from: DateComponents(year: calendar.component(.year, from: prevMonth), month: calendar.component(.month, from: prevMonth), day: 10))!

        let event1 = OfficeEvent(entryTime: prevDay1, exitTime: prevDay1.addingTimeInterval(3600))
        let visit1 = OfficeVisit(date: prevDay1, events: [event1], coordinate: testCoord)
        let event2 = OfficeEvent(entryTime: prevDay2, exitTime: prevDay2.addingTimeInterval(3600))
        let visit2 = OfficeVisit(date: prevDay2, events: [event2], coordinate: testCoord)

        // Current month: only 1 visit (goal not met)
        let currDay = Date()
        let currEvent = OfficeEvent(entryTime: currDay.addingTimeInterval(-3600), exitTime: currDay)
        let currVisit = OfficeVisit(date: currDay, events: [currEvent], coordinate: testCoord)

        appData.visits = [visit1, visit2, currVisit]

        let streak = appData.getMonthlyStreak()
        #expect(streak == 1) // Should count previous month even though current month isn't met
    }

    @Test("AppData - Streak includes current month when met")
    func testStreakIncludesCurrentWhenMet() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        var settings = appData.settings
        settings.monthlyGoal = 2
        settings.autoCalculateGoal = false
        appData.updateSettings(settings)

        let calendar = Calendar.current
        let now = Date()

        // Previous month met (2 visits on different days)
        let prevMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        let prevDay1 = calendar.date(from: DateComponents(year: calendar.component(.year, from: prevMonth), month: calendar.component(.month, from: prevMonth), day: 5))!
        let prevDay2 = calendar.date(from: DateComponents(year: calendar.component(.year, from: prevMonth), month: calendar.component(.month, from: prevMonth), day: 10))!
        let event1 = OfficeEvent(entryTime: prevDay1, exitTime: prevDay1.addingTimeInterval(3600))
        let visit1 = OfficeVisit(date: prevDay1, events: [event1], coordinate: testCoord)
        let event2 = OfficeEvent(entryTime: prevDay2, exitTime: prevDay2.addingTimeInterval(3600))
        let visit2 = OfficeVisit(date: prevDay2, events: [event2], coordinate: testCoord)

        // Current month met (2 visits) - both must be in current month
        // Use dates that are guaranteed to be in the current month
        let currYear = calendar.component(.year, from: now)
        let currMonth = calendar.component(.month, from: now)
        let dayOfMonth = calendar.component(.day, from: now)
        
        // First visit: current date
        let currDay1 = now
        let ce1 = OfficeEvent(entryTime: currDay1.addingTimeInterval(-3600), exitTime: currDay1)
        let cv1 = OfficeVisit(date: currDay1, events: [ce1], coordinate: testCoord)
        
        // Second visit: if we're on day 1, use same day earlier; otherwise use an earlier day in month
        let currDay2: Date
        if dayOfMonth > 1 {
            currDay2 = calendar.date(from: DateComponents(year: currYear, month: currMonth, day: 1, hour: 10))!
        } else {
            // On day 1, create second visit as different event on same day
            currDay2 = now.addingTimeInterval(-7200)
        }
        let ce2 = OfficeEvent(entryTime: currDay2.addingTimeInterval(-3600), exitTime: currDay2)
        let cv2 = OfficeVisit(date: currDay2, events: [ce2], coordinate: testCoord)

        appData.visits = [visit1, visit2, cv1, cv2]

        let streak = appData.getMonthlyStreak()
        #expect(streak == 2) // previous month (1) + current month (1)
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
    
    // MARK: - Chart Data Tests (Bug Fix Verification)
    
    @Test("AppData - getVisitTrend returns data for days range")
    func testGetVisitTrendDays() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        let calendar = Calendar.current
        let now = Date()
        
        // Add visits over the past 10 days
        for dayOffset in 0..<10 {
            let visitDate = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            let event = OfficeEvent(
                entryTime: visitDate,
                exitTime: visitDate.addingTimeInterval(3600) // 1 hour
            )
            let visit = OfficeVisit(date: visitDate, events: [event], coordinate: testCoord)
            appData.visits.append(visit)
        }
        
        // Get trend data for 30 days
        let trendData = appData.getVisitTrend(days: 30)
        
        #expect(trendData.count == 30) // Should return 30 data points
        
        // Check that recent days have counts
        let recentDays = trendData.suffix(10)
        for (_, count) in recentDays {
            #expect(count > 0) // All recent days should have visits
        }
        
        // Check that older days have zero counts
        let olderDays = trendData.prefix(10)
        for (_, count) in olderDays {
            #expect(count == 0) // Older days should have no visits
        }
    }
    
    @Test("AppData - getVisitTrend returns data for months range")
    func testGetVisitTrendMonths() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        let calendar = Calendar.current
        let now = Date()
        
        // Add visits over the past 2 months
        for dayOffset in 0..<60 {
            // Add visits every 3 days
            if dayOffset % 3 == 0 {
                let visitDate = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                let event = OfficeEvent(
                    entryTime: visitDate,
                    exitTime: visitDate.addingTimeInterval(3600)
                )
                let visit = OfficeVisit(date: visitDate, events: [event], coordinate: testCoord)
                appData.visits.append(visit)
            }
        }
        
        // Get trend data for 2 months
        let trendData = appData.getVisitTrend(months: 2)
        
        #expect(!trendData.isEmpty) // Should return data points
        
        // Verify data structure - each element should be a tuple with date and count
        for (date, count) in trendData {
            #expect(date is Date) // date should be a Date
            #expect(count >= 0) // count should be non-negative
        }
        
        // Count days with visits
        let daysWithVisits = trendData.filter { $0.count > 0 }.count
        #expect(daysWithVisits == 20) // Should have 20 days with visits (60 / 3)
    }
    
    @Test("AppData - hasEnoughChartData with sufficient data (days)")
    func testHasEnoughChartDataDaysSufficient() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        let calendar = Calendar.current
        let now = Date()
        
        // Add 10 visits over the past 30 days (more than 7 required)
        for dayOffset in 0..<10 {
            let visitDate = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            let event = OfficeEvent(
                entryTime: visitDate,
                exitTime: visitDate.addingTimeInterval(3600)
            )
            let visit = OfficeVisit(date: visitDate, events: [event], coordinate: testCoord)
            appData.visits.append(visit)
        }
        
        let hasEnoughData = appData.hasEnoughChartData(days: 30)
        
        #expect(hasEnoughData == true) // Should have enough data (10 > 7)
    }
    
    @Test("AppData - hasEnoughChartData with insufficient data (days)")
    func testHasEnoughChartDataDaysInsufficient() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        let calendar = Calendar.current
        let now = Date()
        
        // Add only 3 visits (less than 7 required)
        for dayOffset in 0..<3 {
            let visitDate = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            let event = OfficeEvent(
                entryTime: visitDate,
                exitTime: visitDate.addingTimeInterval(3600)
            )
            let visit = OfficeVisit(date: visitDate, events: [event], coordinate: testCoord)
            appData.visits.append(visit)
        }
        
        let hasEnoughData = appData.hasEnoughChartData(days: 30)
        
        #expect(hasEnoughData == false) // Should not have enough data (3 < 7)
    }
    
    @Test("AppData - hasEnoughChartData with sufficient data (months)")
    func testHasEnoughChartDataMonthsSufficient() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        let calendar = Calendar.current
        let now = Date()
        
        // Add 15 visits over the past 2 months (more than 7 required)
        for dayOffset in 0..<15 {
            let visitDate = calendar.date(byAdding: .day, value: -dayOffset * 4, to: now)!
            let event = OfficeEvent(
                entryTime: visitDate,
                exitTime: visitDate.addingTimeInterval(3600)
            )
            let visit = OfficeVisit(date: visitDate, events: [event], coordinate: testCoord)
            appData.visits.append(visit)
        }
        
        let hasEnoughData = appData.hasEnoughChartData(months: 2)
        
        #expect(hasEnoughData == true) // Should have enough data (15 > 7)
    }
    
    @Test("AppData - hasEnoughChartData with insufficient data (months)")
    func testHasEnoughChartDataMonthsInsufficient() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        let calendar = Calendar.current
        let now = Date()
        
        // Add only 4 visits over 2 months (less than 7 required)
        for dayOffset in 0..<4 {
            let visitDate = calendar.date(byAdding: .day, value: -dayOffset * 15, to: now)!
            let event = OfficeEvent(
                entryTime: visitDate,
                exitTime: visitDate.addingTimeInterval(3600)
            )
            let visit = OfficeVisit(date: visitDate, events: [event], coordinate: testCoord)
            appData.visits.append(visit)
        }
        
        let hasEnoughData = appData.hasEnoughChartData(months: 2)
        
        #expect(hasEnoughData == false) // Should not have enough data (4 < 7)
    }
    
    @Test("AppData - hasEnoughChartData with exactly 7 days of data")
    func testHasEnoughChartDataExactlySevenDays() async throws {
        let appData = createTestAppData()
        let testCoord = testCoordinate()
        let calendar = Calendar.current
        let now = Date()
        
        // Add exactly 7 visits
        for dayOffset in 0..<7 {
            let visitDate = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            let event = OfficeEvent(
                entryTime: visitDate,
                exitTime: visitDate.addingTimeInterval(3600)
            )
            let visit = OfficeVisit(date: visitDate, events: [event], coordinate: testCoord)
            appData.visits.append(visit)
        }
        
        let hasEnoughData = appData.hasEnoughChartData(days: 30)
        
        #expect(hasEnoughData == true) // Should have enough data (7 == 7)
    }
    
    @Test("AppData - getVisitTrend handles empty visits array")
    func testGetVisitTrendEmptyVisits() async throws {
        let appData = createTestAppData()
        
        // Don't add any visits
        let trendData = appData.getVisitTrend(days: 30)
        
        #expect(trendData.count == 30) // Should still return 30 data points
        
        // All counts should be zero
        for (_, count) in trendData {
            #expect(count == 0)
        }
    }
    
    @Test("AppData - hasEnoughChartData with no visits returns false")
    func testHasEnoughChartDataNoVisits() async throws {
        let appData = createTestAppData()
        
        let hasEnoughData = appData.hasEnoughChartData(days: 30)
        
        #expect(hasEnoughData == false) // No visits means not enough data
    }
}