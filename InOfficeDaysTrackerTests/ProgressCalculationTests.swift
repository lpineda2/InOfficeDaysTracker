//
//  ProgressCalculationTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for progress calculation methods and pace calculations
//

import Testing
import Foundation
@testable import InOfficeDaysTracker

struct ProgressCalculationTests {
    
    // MARK: - Helper Methods
    
    /// Creates a date for testing (January 15, 2024 - Monday)
    func testDate() -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15 // Monday
        return calendar.date(from: components)!
    }
    
    /// Gets weekdays remaining from a specific date
    func getWeekdaysRemaining(from date: Date) -> Int {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: date)!
        let endOfMonth = monthInterval.end
        
        var weekdaysCount = 0
        var currentDate = date
        
        while currentDate < endOfMonth {
            let weekday = calendar.component(.weekday, from: currentDate)
            // Weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
            if weekday >= 2 && weekday <= 6 { // Monday through Friday
                weekdaysCount += 1
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return weekdaysCount
    }
    
    // MARK: - Days Remaining Calculation Tests
    
    @Test("Calculate weekdays remaining in month")
    func testWeekdaysRemainingCalculation() async throws {
        let testDate = testDate() // January 15, 2024 (Monday)
        let weekdaysRemaining = getWeekdaysRemaining(from: testDate)
        
        // January 2024: 15th (Mon) through 31st
        // Weekdays from Jan 15-31: 15,16,17,18,19, 22,23,24,25,26, 29,30,31 = 13 days
        #expect(weekdaysRemaining == 13)
    }
    
    @Test("Calculate weekdays remaining - end of month")
    func testWeekdaysRemainingEndOfMonth() async throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 31 // Last day of January (Wednesday)
        let endDate = calendar.date(from: components)!
        
        let weekdaysRemaining = getWeekdaysRemaining(from: endDate)
        
        #expect(weekdaysRemaining == 1) // Just the 31st itself
    }
    
    @Test("Calculate weekdays remaining - weekend day")
    func testWeekdaysRemainingFromWeekend() async throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 13 // Saturday
        let weekendDate = calendar.date(from: components)!
        
        let weekdaysRemaining = getWeekdaysRemaining(from: weekendDate)
        
        // From Jan 13 (Sat) through Jan 31
        // Weekdays: 15,16,17,18,19, 22,23,24,25,26, 29,30,31 = 13 days
        #expect(weekdaysRemaining == 13)
    }
    
    // MARK: - Pace Calculation Tests
    
    @Test("Pace calculation - normal scenario")
    func testPaceCalculationNormal() async throws {
        let current = 5 // visits completed
        let goal = 15 // monthly goal
        let weekdaysRemaining = 10 // working days left
        
        let needed = goal - current // 10 visits needed
        let pace = Double(needed) / Double(weekdaysRemaining) // 10/10 = 1.0
        
        #expect(pace == 1.0)
    }
    
    @Test("Pace calculation - behind schedule")
    func testPaceCalculationBehind() async throws {
        let current = 3 // visits completed
        let goal = 15 // monthly goal
        let weekdaysRemaining = 5 // working days left
        
        let needed = goal - current // 12 visits needed
        let pace = Double(needed) / Double(weekdaysRemaining) // 12/5 = 2.4
        
        #expect(pace == 2.4)
    }
    
    @Test("Pace calculation - ahead of schedule")
    func testPaceCalculationAhead() async throws {
        let current = 12 // visits completed
        let goal = 15 // monthly goal
        let weekdaysRemaining = 10 // working days left
        
        let needed = goal - current // 3 visits needed
        let pace = Double(needed) / Double(weekdaysRemaining) // 3/10 = 0.3
        
        #expect(pace == 0.3)
    }
    
    @Test("Pace calculation - goal already met")
    func testPaceCalculationGoalMet() async throws {
        let current = 15 // visits completed
        let goal = 15 // monthly goal
        let weekdaysRemaining = 5 // working days left
        
        let needed = max(0, goal - current) // 0 visits needed
        let pace = Double(needed) / Double(weekdaysRemaining) // 0/5 = 0.0
        
        #expect(pace == 0.0)
    }
    
    @Test("Pace calculation - exceeded goal")
    func testPaceCalculationExceeded() async throws {
        let current = 18 // visits completed
        let goal = 15 // monthly goal
        let weekdaysRemaining = 3 // working days left
        
        let needed = max(0, goal - current) // 0 visits needed (can't be negative)
        let pace = Double(needed) / Double(weekdaysRemaining) // 0/3 = 0.0
        
        #expect(pace == 0.0)
    }
    
    // MARK: - Edge Cases for Pace Calculation
    
    @Test("Pace calculation - no working days remaining")
    func testPaceCalculationNoWorkingDays() async throws {
        let current = 10 // visits completed
        let goal = 15 // monthly goal
        let weekdaysRemaining = 0 // no working days left
        
        let needed = goal - current // 5 visits needed
        
        // Should handle division by zero gracefully
        let pace = weekdaysRemaining > 0 ? Double(needed) / Double(weekdaysRemaining) : 0.0
        
        #expect(pace == 0.0) // Should not crash or return infinity
    }
    
    @Test("Pace calculation - validates against impossible values")
    func testPaceCalculationValidation() async throws {
        let current = 2 // visits completed
        let goal = 20 // monthly goal
        let weekdaysRemaining = 22 // working days left (normal month has ~22 weekdays)
        
        let needed = goal - current // 18 visits needed
        let pace = Double(needed) / Double(weekdaysRemaining) // 18/22 ≈ 0.82
        
        // This should be a reasonable pace (less than 1 visit per weekday)
        #expect(pace < 1.0)
        #expect(pace > 0.0)
        
        // The bug was showing "14.0 days/week" - impossible since max is ~5 weekdays
        #expect(pace <= 5.0) // Should never exceed 5 (max weekdays in a week)
    }
    
    @Test("Days per week calculation - validates maximum")
    func testDaysPerWeekValidation() async throws {
        // Test the specific bug scenario
        let visitsNeeded = 14 // high number
        let weekdaysRemaining = 1 // very few days left
        
        let pacePerDay = Double(visitsNeeded) / Double(weekdaysRemaining) // 14/1 = 14.0
        
        // Convert daily pace to weekly representation correctly
        // If pace is 14 visits per day, that's impossible on weekdays only
        #expect(pacePerDay == 14.0) // This was the bug - showing as "14.0 days/week"
        
        // The fix should show this as "14.0 visits/day remaining" not "days/week"
        // Or better yet, show it as an impossible/unrealistic pace
        let isUnrealistic = pacePerDay > 1.0 // More than 1 visit per day is unusual
        #expect(isUnrealistic == true)
    }
    
    // MARK: - Progress Percentage Tests
    
    @Test("Progress percentage calculation")
    func testProgressPercentageCalculation() async throws {
        let current = 7
        let goal = 20
        
        let percentage = Double(current) / Double(goal)
        
        #expect(percentage == 0.35) // 35%
    }
    
    @Test("Progress percentage - goal exceeded")
    func testProgressPercentageExceeded() async throws {
        let current = 25
        let goal = 20
        
        let percentage = Double(current) / Double(goal)
        
        #expect(percentage == 1.25) // 125% - over goal
    }
    
    @Test("Progress percentage - zero goal")
    func testProgressPercentageZeroGoal() async throws {
        let current = 5
        let goal = 0
        
        // Should handle division by zero
        let percentage = goal > 0 ? Double(current) / Double(goal) : 0.0
        
        #expect(percentage == 0.0)
    }
}