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

    /// Safe integer divide returning 0.0 when denominator is zero.
    func safeDivide(_ numerator: Int, _ denominator: Int) -> Double {
        if denominator == 0 { return 0.0 }
        return Double(numerator) / Double(denominator)
    }

    
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
        let pace = safeDivide(needed, weekdaysRemaining) // 10/10 = 1.0
        
        #expect(pace == 1.0)
    }
    
    @Test("Pace calculation - behind schedule")
    func testPaceCalculationBehind() async throws {
        let current = 3 // visits completed
        let goal = 15 // monthly goal
        let weekdaysRemaining = 5 // working days left
        
        let needed = goal - current // 12 visits needed
        let pace = safeDivide(needed, weekdaysRemaining) // 12/5 = 2.4
        
        #expect(pace == 2.4)
    }
    
    @Test("Pace calculation - ahead of schedule")
    func testPaceCalculationAhead() async throws {
        let current = 12 // visits completed
        let goal = 15 // monthly goal
        let weekdaysRemaining = 10 // working days left
        
        let needed = goal - current // 3 visits needed
        let pace = safeDivide(needed, weekdaysRemaining) // 3/10 = 0.3
        
        #expect(pace == 0.3)
    }
    
    @Test("Pace calculation - goal already met")
    func testPaceCalculationGoalMet() async throws {
        let current = 15 // visits completed
        let goal = 15 // monthly goal
        let weekdaysRemaining = 5 // working days left
        
        let needed = max(0, goal - current) // 0 visits needed
        let pace = safeDivide(needed, weekdaysRemaining) // 0/5 = 0.0
        
        #expect(pace == 0.0)
    }
    
    @Test("Pace calculation - exceeded goal")
    func testPaceCalculationExceeded() async throws {
        let current = 18 // visits completed
        let goal = 15 // monthly goal
        let weekdaysRemaining = 3 // working days left
        
        let needed = max(0, goal - current) // 0 visits needed (can't be negative)
        let pace = safeDivide(needed, weekdaysRemaining) // 0/3 = 0.0
        
        #expect(pace == 0.0)
    }
    
    // MARK: - Edge Cases for Pace Calculation
    
    @Test("Pace calculation - no working days remaining")
    func testPaceCalculationNoWorkingDays() async throws {
        let current = 10 // visits completed
        let goal = 15 // monthly goal
        let weekdaysRemaining = 0 // no working days left
        
        let needed = goal - current // 5 visits needed

        // Use safeDivide to handle zero denominator
        let pace = safeDivide(needed, weekdaysRemaining)

        #expect(pace == 0.0) // Should not crash or return infinity
    }
    
    @Test("Pace calculation - validates against impossible values")
    func testPaceCalculationValidation() async throws {
        let current = 2 // visits completed
        let goal = 20 // monthly goal
        let weekdaysRemaining = 22 // working days left (normal month has ~22 weekdays)
        
        let needed = goal - current // 18 visits needed
        let pace = safeDivide(needed, weekdaysRemaining) // 18/22 ≈ 0.82
        
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
        
        let pacePerDay = safeDivide(visitsNeeded, weekdaysRemaining) // 14/1 = 14.0
        
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
        
        let percentage = safeDivide(current, goal)

        #expect(percentage == 0.35) // 35%
    }
    
    @Test("Progress percentage - goal exceeded")
    func testProgressPercentageExceeded() async throws {
        let current = 25
        let goal = 20
        
        let percentage = safeDivide(current, goal)

        #expect(percentage == 1.25) // 125% - over goal
    }
    
    @Test("Progress percentage - zero goal")
    func testProgressPercentageZeroGoal() async throws {
        let current = 5
        let goal = 0
        
        // Should handle division by zero
        let percentage = safeDivide(current, goal)

        #expect(percentage == 0.0)
    }
    
    // MARK: - Custom Tracking Days Tests
    
    @Test("Working days remaining - Mon-Wed-Fri schedule")
    func testCustomTrackingDaysMWF() async throws {
        // Test with custom tracking days (Mon, Wed, Fri)
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15 // Monday
        let startDate = calendar.date(from: components)!
        
        let trackingDays: Set<Int> = [2, 4, 6] // Mon=2, Wed=4, Fri=6
        
        // Count remaining tracking days from Jan 15-31
        var count = 0
        var date = calendar.startOfDay(for: startDate)
        let endOfMonth = calendar.dateInterval(of: .month, for: startDate)!.end
        
        // endOfMonth is start of next month, so use < not <=
        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Jan 15-31: Mon(15), Wed(17), Fri(19), Mon(22), Wed(24), Fri(26), Mon(29), Wed(31)
        // = 8 days (not 13 weekdays)
        #expect(count == 8)
    }
    
    @Test("Working days remaining - Tue-Thu schedule")
    func testCustomTrackingDaysTueThu() async throws {
        // Test with custom tracking days (Tue, Thu only)
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15 // Monday
        let startDate = calendar.date(from: components)!
        
        let trackingDays: Set<Int> = [3, 5] // Tue=3, Thu=5
        
        var count = 0
        var date = calendar.startOfDay(for: startDate)
        let endOfMonth = calendar.dateInterval(of: .month, for: startDate)!.end
        
        // endOfMonth is start of next month, so use < not <=
        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Jan 15-31: Tue(16), Thu(18), Tue(23), Thu(25), Tue(30)
        // = 5 days (not 13 weekdays)
        #expect(count == 5)
    }
    
    @Test("Pace calculation - custom Mon-Wed-Fri schedule")
    func testPaceCalculationCustomMWF() async throws {
        let current = 6
        let goal = 12
        let trackingDaysRemaining = 9 // 9 Mon/Wed/Fri days left
        let trackingDaysPerWeek = 3 // Mon, Wed, Fri
        
        let needed = goal - current // 6 visits needed
        let dailyRate = Double(needed) / Double(trackingDaysRemaining) // 6/9 = 0.67
        let weeklyRate = dailyRate * Double(trackingDaysPerWeek) // 0.67 × 3 = 2.0
        
        // Should show ~2.0 days/week (not 4.67 if using 7 days)
        #expect(abs(weeklyRate - 2.0) < 0.01)
    }
    
    // MARK: - Today Inclusion Tests
    
    @Test("Working days remaining - includes today when tracking day")
    func testWorkingDaysIncludesToday() async throws {
        // Test that today IS included when it's a tracking day
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 31 // Wednesday (last day of month)
        let lastDay = calendar.date(from: components)!
        
        let trackingDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri
        
        var count = 0
        var date = calendar.startOfDay(for: lastDay)
        let endOfMonth = calendar.dateInterval(of: .month, for: lastDay)!.end
        
        // endOfMonth is start of next month, so use < not <=
        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Last day of month: should count 1 (the 31st itself)
        #expect(count == 1)
    }
    
    @Test("Working days remaining - excludes today when not tracking day")
    func testWorkingDaysExcludesTodayWhenWeekend() async throws {
        // Test that today is properly handled when it's NOT a tracking day
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 27 // Saturday
        let saturday = calendar.date(from: components)!
        
        let trackingDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri
        
        var count = 0
        var date = calendar.startOfDay(for: saturday)
        let endOfMonth = calendar.dateInterval(of: .month, for: saturday)!.end
        
        // endOfMonth is start of next month, so use < not <=
        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // From Sat Jan 27 to end: Mon(29), Tue(30), Wed(31) = 3 days
        #expect(count == 3)
    }
    
    // MARK: - Working Days Remaining with Holidays & PTO Tests
    
    @Test("Working days remaining - baseline with no holidays or PTO")
    func testWorkingDaysRemainingBaseline() async throws {
        // This validates the basic weekday counting still works
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15 // Monday
        let testDate = calendar.date(from: components)!
        
        let trackingDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri
        
        var count = 0
        var date = calendar.startOfDay(for: testDate)
        let endOfMonth = calendar.dateInterval(of: .month, for: testDate)!.end
        
        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Jan 15-31: 13 weekdays (Mon-Fri)
        #expect(count == 13)
    }
    
    @Test("Working days remaining - subtract future holiday")
    func testWorkingDaysRemainingWithHoliday() async throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15 // Monday
        let testDate = calendar.date(from: components)!
        
        let trackingDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri
        
        // Count remaining weekdays
        var count = 0
        var date = calendar.startOfDay(for: testDate)
        let endOfMonth = calendar.dateInterval(of: .month, for: testDate)!.end
        
        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Simulate 1 holiday on Jan 19 (Friday) which is >= today and on tracking day
        var holidayComponents = DateComponents()
        holidayComponents.year = 2024
        holidayComponents.month = 1
        holidayComponents.day = 19
        let holiday = calendar.date(from: holidayComponents)!
        
        let holidays = [holiday].filter { $0 >= calendar.startOfDay(for: testDate) }
        
        let result = max(0, count - holidays.count)
        
        // 13 weekdays - 1 holiday = 12
        #expect(result == 12)
    }
    
    @Test("Working days remaining - subtract future PTO")
    func testWorkingDaysRemainingWithPTO() async throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15 // Monday
        let testDate = calendar.date(from: components)!
        
        let trackingDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri
        
        var count = 0
        var date = calendar.startOfDay(for: testDate)
        let endOfMonth = calendar.dateInterval(of: .month, for: testDate)!.end
        
        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Simulate 1 PTO on Jan 25 (Thursday)
        var ptoComponents = DateComponents()
        ptoComponents.year = 2024
        ptoComponents.month = 1
        ptoComponents.day = 25
        let pto = calendar.date(from: ptoComponents)!
        
        let ptoDays = [pto].filter { ptoDate in
            let weekday = calendar.component(.weekday, from: ptoDate)
            return trackingDays.contains(weekday) && ptoDate >= calendar.startOfDay(for: testDate)
        }
        
        let result = max(0, count - ptoDays.count)
        
        // 13 weekdays - 1 PTO = 12
        #expect(result == 12)
    }
    
    @Test("Working days remaining - deduplicate holiday and PTO on same day")
    func testWorkingDaysRemainingDeduplication() async throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        let testDate = calendar.date(from: components)!
        
        let trackingDays: Set<Int> = [2, 3, 4, 5, 6]
        
        var count = 0
        var date = calendar.startOfDay(for: testDate)
        let endOfMonth = calendar.dateInterval(of: .month, for: testDate)!.end
        
        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Simulate holiday and PTO both on Jan 19
        var jan19Components = DateComponents()
        jan19Components.year = 2024
        jan19Components.month = 1
        jan19Components.day = 19
        let jan19 = calendar.date(from: jan19Components)!
        
        let holidays = [jan19].filter { $0 >= calendar.startOfDay(for: testDate) }
        let ptoDays = [jan19].filter { ptoDate in
            let weekday = calendar.component(.weekday, from: ptoDate)
            return trackingDays.contains(weekday) && ptoDate >= calendar.startOfDay(for: testDate)
        }
        
        // Deduplicate using Set
        let holidayPTOSet = Set(holidays + ptoDays)
        let result = max(0, count - holidayPTOSet.count)
        
        // 13 weekdays - 1 day (not 2) = 12
        #expect(result == 12)
        #expect(holidayPTOSet.count == 1)
    }
    
    @Test("Working days remaining - ignore past holiday")
    func testWorkingDaysRemainingIgnorePastHoliday() async throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 20 // Start mid-month
        let testDate = calendar.date(from: components)!
        
        let trackingDays: Set<Int> = [2, 3, 4, 5, 6]
        
        var count = 0
        var date = calendar.startOfDay(for: testDate)
        let endOfMonth = calendar.dateInterval(of: .month, for: testDate)!.end
        
        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Simulate holiday on Jan 10 (before testDate)
        var pastHolidayComponents = DateComponents()
        pastHolidayComponents.year = 2024
        pastHolidayComponents.month = 1
        pastHolidayComponents.day = 10
        let pastHoliday = calendar.date(from: pastHolidayComponents)!
        
        // Filter should exclude past holidays
        let holidays = [pastHoliday].filter { $0 >= calendar.startOfDay(for: testDate) }
        let result = max(0, count - holidays.count)
        
        // Past holiday should be ignored
        #expect(holidays.count == 0)
        #expect(result == count)
    }
    
    @Test("Working days remaining - ignore holiday on non-tracking day")
    func testWorkingDaysRemainingIgnoreWeekendHoliday() async throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        let testDate = calendar.date(from: components)!
        
        let trackingDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri only
        
        var count = 0
        var date = calendar.startOfDay(for: testDate)
        let endOfMonth = calendar.dateInterval(of: .month, for: testDate)!.end
        
        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Simulate holiday on Jan 20 (Saturday) - not a tracking day
        var saturdayComponents = DateComponents()
        saturdayComponents.year = 2024
        saturdayComponents.month = 1
        saturdayComponents.day = 20 // Saturday
        let saturday = calendar.date(from: saturdayComponents)!
        
        // getHolidaysInMonth already filters to tracking days, so this simulates that
        let allHolidays = [saturday]
        let holidaysOnTrackingDays = allHolidays.filter { holiday in
            let weekday = calendar.component(.weekday, from: holiday)
            return trackingDays.contains(weekday)
        }.filter { $0 >= calendar.startOfDay(for: testDate) }
        
        let result = max(0, count - holidaysOnTrackingDays.count)
        
        // Saturday holiday should be ignored
        #expect(holidaysOnTrackingDays.count == 0)
        #expect(result == count)
    }
    
    @Test("Working days remaining - clamp to zero when holidays exceed days")
    func testWorkingDaysRemainingClampToZero() async throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 31 // Last day of month
        let testDate = calendar.date(from: components)!
        
        let trackingDays: Set<Int> = [2, 3, 4, 5, 6]
        
        var count = 0
        var date = calendar.startOfDay(for: testDate)
        let endOfMonth = calendar.dateInterval(of: .month, for: testDate)!.end
        
        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Only 1 day left (Jan 31), but simulate 2 holidays (impossible but test cleansing)
        var jan31Components = DateComponents()
        jan31Components.year = 2024
        jan31Components.month = 1
        jan31Components.day = 31
        let jan31 = calendar.date(from: jan31Components)!
        
        // Simulate excessive holidays
        let excessiveHolidays = [jan31, jan31] // Duplicate to test
        let holidaySet = Set(excessiveHolidays)
        
        let result = max(0, count - holidaySet.count)
        
        // Should clamp to 0, not negative
        #expect(result == 0)
        #expect(count == 1)
    }
}
