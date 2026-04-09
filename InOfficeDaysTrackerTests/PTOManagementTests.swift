//
//  PTOManagementTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for PTO/Sick Days management including add, edit, delete, and display functionality
//

import Testing
import Foundation
@testable import InOfficeDaysTracker

@MainActor
struct PTOManagementTests {
    
    // MARK: - Test Setup Helper
    
    /// Creates a clean AppData instance for testing
    func createTestAppData() -> AppData {
        let appData = AppData()
        appData.visits = []
        appData.currentVisit = nil
        appData.isCurrentlyInOffice = false
        
        // Set up clean settings with auto-calculate enabled
        var settings = AppSettings()
        settings.autoCalculateGoal = true
        settings.monthlyGoal = 12
        settings.trackingDays = [2, 3, 4, 5, 6] // Mon-Fri
        settings.ptoSickDays = [:] // Clear any existing PTO
        appData.updateSettings(settings)
        
        return appData
    }
    
    /// Creates a test date for a specific day in the current month
    func createTestDate(day: Int, month: Int = 4, year: Int = 2026) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12 // Noon to avoid timezone edge cases
        return Calendar.current.date(from: components) ?? Date()
    }
    
    // MARK: - Basic PTO Operations Tests
    
    @Test("PTO - Add PTO day")
    func testAddPTODay() async throws {
        let appData = createTestAppData()
        let ptoDate = createTestDate(day: 14) // April 14, 2026
        
        appData.addPTODay(ptoDate)
        
        let ptoDays = appData.getPTODays(for: ptoDate)
        #expect(ptoDays.count == 1)
        #expect(Calendar.current.isDate(ptoDays.first ?? Date(), inSameDayAs: ptoDate))
    }
    
    @Test("PTO - Add multiple PTO days")
    func testAddMultiplePTODays() async throws {
        let appData = createTestAppData()
        let date1 = createTestDate(day: 14)
        let date2 = createTestDate(day: 23)
        let date3 = createTestDate(day: 25)
        
        appData.addPTODay(date1)
        appData.addPTODay(date2)
        appData.addPTODay(date3)
        
        let ptoDays = appData.getPTODays(for: date1)
        #expect(ptoDays.count == 3)
    }
    
    @Test("PTO - Prevent duplicate PTO days")
    func testPreventDuplicatePTODays() async throws {
        let appData = createTestAppData()
        let ptoDate = createTestDate(day: 14)
        
        appData.addPTODay(ptoDate)
        appData.addPTODay(ptoDate) // Try to add again
        
        let ptoDays = appData.getPTODays(for: ptoDate)
        #expect(ptoDays.count == 1) // Should still be only 1
    }
    
    @Test("PTO - Remove PTO day")
    func testRemovePTODay() async throws {
        let appData = createTestAppData()
        let ptoDate = createTestDate(day: 14)
        
        appData.addPTODay(ptoDate)
        #expect(appData.getPTODays(for: ptoDate).count == 1)
        
        appData.removePTODay(ptoDate)
        
        let ptoDays = appData.getPTODays(for: ptoDate)
        #expect(ptoDays.isEmpty)
    }
    
    @Test("PTO - Remove specific day from multiple")
    func testRemoveSpecificPTODay() async throws {
        let appData = createTestAppData()
        let date1 = createTestDate(day: 14)
        let date2 = createTestDate(day: 23)
        let date3 = createTestDate(day: 25)
        
        appData.addPTODay(date1)
        appData.addPTODay(date2)
        appData.addPTODay(date3)
        
        appData.removePTODay(date2) // Remove middle date
        
        let ptoDays = appData.getPTODays(for: date1)
        #expect(ptoDays.count == 2)
        #expect(!ptoDays.contains(where: { Calendar.current.isDate($0, inSameDayAs: date2) }))
    }
    
    @Test("PTO - Get PTO days returns sorted")
    func testGetPTODaysSorted() async throws {
        let appData = createTestAppData()
        
        // Add in random order
        appData.addPTODay(createTestDate(day: 25))
        appData.addPTODay(createTestDate(day: 14))
        appData.addPTODay(createTestDate(day: 23))
        
        let ptoDays = appData.getPTODays(for: createTestDate(day: 1))
        
        #expect(ptoDays.count == 3)
        // Verify sorted (earliest first)
        for i in 0..<(ptoDays.count - 1) {
            #expect(ptoDays[i] < ptoDays[i + 1])
        }
    }
    
    // MARK: - Month Isolation Tests
    
    @Test("PTO - Different months isolated")
    func testPTODaysIsolatedByMonth() async throws {
        let appData = createTestAppData()
        
        let aprilDate = createTestDate(day: 14, month: 4)
        let mayDate = createTestDate(day: 15, month: 5)
        
        appData.addPTODay(aprilDate)
        appData.addPTODay(mayDate)
        
        let aprilPTO = appData.getPTODays(for: aprilDate)
        let mayPTO = appData.getPTODays(for: mayDate)
        
        #expect(aprilPTO.count == 1)
        #expect(mayPTO.count == 1)
        #expect(aprilPTO != mayPTO)
    }
    
    @Test("PTO - Empty month returns empty array")
    func testEmptyMonthReturnsEmptyArray() async throws {
        let appData = createTestAppData()
        
        let ptoDays = appData.getPTODays(for: createTestDate(day: 1, month: 6)) // June, no PTO added
        
        #expect(ptoDays.isEmpty)
    }
    
    // MARK: - Goal Calculation Integration Tests
    
    @Test("PTO - Affects working days calculation")
    func testPTOAffectsWorkingDays() async throws {
        let appData = createTestAppData()
        _ = createTestDate(day: 1)
        
        // Get baseline working days
        let baselineWorkingDays = appData.getWorkingDaysRemaining()
        
        // Add PTO days (on working days)
        appData.addPTODay(createTestDate(day: 14)) // Monday
        appData.addPTODay(createTestDate(day: 16)) // Wednesday
        
        let workingDaysWithPTO = appData.getWorkingDaysRemaining()
        
        // Working days should decrease (assuming we're before these dates or at start of month)
        // Note: This depends on current date being before PTO dates
        #expect(workingDaysWithPTO <= baselineWorkingDays)
    }
    
    @Test("PTO - Affects required days calculation")
    func testPTOAffectsRequiredDays() async throws {
        let appData = createTestAppData()
        let currentMonth = createTestDate(day: 1)
        
        // Set up a specific company policy (50% hybrid)
        var settings = appData.settings
        settings.companyPolicy = CompanyPolicy(policyType: .hybrid50)
        settings.autoCalculateGoal = true
        appData.updateSettings(settings)
        
        let baselineRequired = appData.calculateRequiredDays(for: currentMonth)
        
        // Add 2 PTO days
        appData.addPTODay(createTestDate(day: 14))
        appData.addPTODay(createTestDate(day: 21))
        
        let requiredWithPTO = appData.calculateRequiredDays(for: currentMonth)
        
        // Required days should decrease since working days decreased
        #expect(requiredWithPTO <= baselineRequired)
    }
    
    @Test("PTO - Goal calculation breakdown includes PTO count")
    func testGoalBreakdownIncludesPTO() async throws {
        let appData = createTestAppData()
        let currentMonth = createTestDate(day: 1)
        
        appData.addPTODay(createTestDate(day: 14))
        appData.addPTODay(createTestDate(day: 21))
        appData.addPTODay(createTestDate(day: 25))
        
        let breakdown = appData.getGoalCalculationBreakdown(for: currentMonth)
        
        #expect(breakdown.ptoCount == 3)
    }
    
    // MARK: - Edge Cases
    
    @Test("PTO - Handle date at different times of day")
    func testPTODateNormalization() async throws {
        let appData = createTestAppData()
        
        // Create same day at different times
        var morning = DateComponents()
        morning.year = 2026
        morning.month = 4
        morning.day = 14
        morning.hour = 8
        morning.minute = 30
        
        var evening = DateComponents()
        evening.year = 2026
        evening.month = 4
        evening.day = 14
        evening.hour = 20
        evening.minute = 45
        
        let morningDate = Calendar.current.date(from: morning) ?? Date()
        let eveningDate = Calendar.current.date(from: evening) ?? Date()
        
        appData.addPTODay(morningDate)
        appData.addPTODay(eveningDate) // Should be treated as duplicate
        
        let ptoDays = appData.getPTODays(for: morningDate)
        #expect(ptoDays.count == 1) // Should only have one entry for April 14
    }
    
    @Test("PTO - Removing non-existent PTO day")
    func testRemoveNonExistentPTODay() async throws {
        let appData = createTestAppData()
        
        appData.addPTODay(createTestDate(day: 14))
        
        // Try to remove a day that doesn't exist
        appData.removePTODay(createTestDate(day: 15))
        
        let ptoDays = appData.getPTODays(for: createTestDate(day: 1))
        #expect(ptoDays.count == 1) // Should still have the original day
    }
    
    @Test("PTO - Empty state after removing all days")
    func testEmptyStateAfterRemovingAll() async throws {
        let appData = createTestAppData()
        
        let date1 = createTestDate(day: 14)
        let date2 = createTestDate(day: 23)
        
        appData.addPTODay(date1)
        appData.addPTODay(date2)
        
        appData.removePTODay(date1)
        appData.removePTODay(date2)
        
        let ptoDays = appData.getPTODays(for: date1)
        #expect(ptoDays.isEmpty)
    }
    
    // MARK: - Persistence Tests
    
    @Test("PTO - Settings persistence includes PTO data")
    func testPTOPersistence() async throws {
        let appData = createTestAppData()
        
        appData.addPTODay(createTestDate(day: 14))
        appData.addPTODay(createTestDate(day: 23))
        
        // Verify data is in settings structure
        let monthKey = "2026-04"
        #expect(appData.settings.ptoSickDays[monthKey] != nil)
        #expect(appData.settings.ptoSickDays[monthKey]?.count == 2)
    }
}
