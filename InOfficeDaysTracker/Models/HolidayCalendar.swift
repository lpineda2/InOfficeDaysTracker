//
//  HolidayCalendar.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 1/13/26.
//

import Foundation

/// Represents a holiday calendar configuration with presets and custom overrides
struct HolidayCalendar: Codable, Equatable {
    var preset: HolidayPreset = .nyse
    var customRemovals: [HolidayDate] = []   // Holidays from preset to exclude
    var customAdditions: [HolidayDate] = []  // Custom holidays to add
    
    /// Get all holidays for a specific year
    func getHolidays(for year: Int) -> [Date] {
        var holidays = preset.getHolidays(for: year)
        
        // Remove custom removals
        let removalDates = Set(customRemovals.compactMap { $0.date(for: year) })
        holidays = holidays.filter { !removalDates.contains($0) }
        
        // Add custom additions
        let additionDates = customAdditions.compactMap { $0.date(for: year) }
        holidays.append(contentsOf: additionDates)
        
        return holidays.sorted()
    }
    
    /// Get holidays that fall within a specific month
    func getHolidays(for month: Date) -> [Date] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: month)
        let monthNum = calendar.component(.month, from: month)
        
        return getHolidays(for: year).filter { date in
            calendar.component(.month, from: date) == monthNum
        }
    }
    
    /// Total holiday count for a year (for display)
    func holidayCount(for year: Int) -> Int {
        return getHolidays(for: year).count
    }
    
    /// Get the preset holidays with their enabled/disabled state
    func getPresetHolidaysWithState(for year: Int) -> [(holiday: USHoliday, date: Date, isEnabled: Bool)] {
        let removalSet = Set(customRemovals.map { $0.holiday })
        
        return preset.holidays.compactMap { holiday in
            guard let date = holiday.date(for: year) else { return nil }
            let isEnabled = !removalSet.contains(holiday)
            return (holiday, date, isEnabled)
        }
    }
}

/// Represents a holiday that can be serialized (for custom additions/removals)
struct HolidayDate: Codable, Equatable, Hashable {
    var holiday: USHoliday?      // For preset holidays
    var customDate: DateComponents?  // For custom holidays (month, day)
    var customName: String?      // Name for custom holidays
    
    init(holiday: USHoliday) {
        self.holiday = holiday
    }
    
    init(month: Int, day: Int, name: String) {
        self.customDate = DateComponents(month: month, day: day)
        self.customName = name
    }
    
    func date(for year: Int) -> Date? {
        if let holiday = holiday {
            return holiday.date(for: year)
        } else if var components = customDate {
            components.year = year
            return Calendar.current.date(from: components)
        }
        return nil
    }
    
    var displayName: String {
        holiday?.rawValue ?? customName ?? "Unknown Holiday"
    }
}

/// Holiday calendar presets
enum HolidayPreset: String, Codable, CaseIterable, Identifiable {
    case nyse = "nyse"
    case usFederal = "us_federal"
    case none = "none"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .nyse: return "NYSE / Stock Exchange"
        case .usFederal: return "US Federal"
        case .none: return "None"
        }
    }
    
    var description: String {
        switch self {
        case .nyse: return "10 holidays - Stock exchange schedule"
        case .usFederal: return "11 holidays - Government schedule"
        case .none: return "No preset holidays"
        }
    }
    
    var holidayCount: String {
        switch self {
        case .nyse: return "10 days"
        case .usFederal: return "11 days"
        case .none: return "0 days"
        }
    }
    
    /// The holidays included in this preset
    var holidays: [USHoliday] {
        switch self {
        case .nyse:
            return [.newYearsDay, .mlkDay, .presidentsDay, .goodFriday,
                    .memorialDay, .juneteenth, .independenceDay, .laborDay,
                    .thanksgiving, .christmas]
        case .usFederal:
            return [.newYearsDay, .mlkDay, .presidentsDay, .memorialDay,
                    .juneteenth, .independenceDay, .laborDay, .columbusDay,
                    .veteransDay, .thanksgiving, .christmas]
        case .none:
            return []
        }
    }
    
    /// Get actual dates for all holidays in this preset for a given year
    func getHolidays(for year: Int) -> [Date] {
        return holidays.compactMap { $0.date(for: year) }
    }
}

/// US Federal and Market Holidays with date calculation logic
enum USHoliday: String, Codable, CaseIterable, Identifiable {
    case newYearsDay = "New Year's Day"
    case mlkDay = "Martin Luther King Jr. Day"
    case presidentsDay = "Presidents Day"
    case goodFriday = "Good Friday"
    case memorialDay = "Memorial Day"
    case juneteenth = "Juneteenth"
    case independenceDay = "Independence Day"
    case laborDay = "Labor Day"
    case columbusDay = "Columbus Day"
    case veteransDay = "Veterans Day"
    case thanksgiving = "Thanksgiving Day"
    case christmas = "Christmas Day"
    
    var id: String { rawValue }
    
    /// Calculate the actual date for this holiday in a given year
    func date(for year: Int) -> Date? {
        switch self {
        case .newYearsDay:
            // January 1 (observed on Monday if falls on weekend)
            return observedDate(month: 1, day: 1, year: year)
            
        case .mlkDay:
            // Third Monday in January
            return nthWeekday(nth: 3, weekday: .monday, month: 1, year: year)
            
        case .presidentsDay:
            // Third Monday in February
            return nthWeekday(nth: 3, weekday: .monday, month: 2, year: year)
            
        case .goodFriday:
            // Friday before Easter Sunday
            return goodFridayDate(year: year)
            
        case .memorialDay:
            // Last Monday in May
            return lastWeekday(weekday: .monday, month: 5, year: year)
            
        case .juneteenth:
            // June 19 (observed on Monday/Friday if weekend)
            return observedDate(month: 6, day: 19, year: year)
            
        case .independenceDay:
            // July 4 (observed on Monday/Friday if weekend)
            return observedDate(month: 7, day: 4, year: year)
            
        case .laborDay:
            // First Monday in September
            return nthWeekday(nth: 1, weekday: .monday, month: 9, year: year)
            
        case .columbusDay:
            // Second Monday in October
            return nthWeekday(nth: 2, weekday: .monday, month: 10, year: year)
            
        case .veteransDay:
            // November 11 (observed on Monday/Friday if weekend)
            return observedDate(month: 11, day: 11, year: year)
            
        case .thanksgiving:
            // Fourth Thursday in November
            return nthWeekday(nth: 4, weekday: .thursday, month: 11, year: year)
            
        case .christmas:
            // December 25 (observed on Monday/Friday if weekend)
            return observedDate(month: 12, day: 25, year: year)
        }
    }
    
    // MARK: - Date Calculation Helpers
    
    /// Get the nth occurrence of a weekday in a month
    private func nthWeekday(nth: Int, weekday: Weekday, month: Int, year: Int) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents(year: year, month: month)
        components.weekday = weekday.calendarValue
        components.weekdayOrdinal = nth
        return calendar.date(from: components)
    }
    
    /// Get the last occurrence of a weekday in a month
    private func lastWeekday(weekday: Weekday, month: Int, year: Int) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents(year: year, month: month)
        components.weekday = weekday.calendarValue
        components.weekdayOrdinal = -1  // Last occurrence
        return calendar.date(from: components)
    }
    
    /// Get a fixed date with observed date adjustment for weekends
    private func observedDate(month: Int, day: Int, year: Int) -> Date? {
        let calendar = Calendar.current
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return nil
        }
        
        let weekday = calendar.component(.weekday, from: date)
        
        switch weekday {
        case 1: // Sunday -> observed Monday
            return calendar.date(byAdding: .day, value: 1, to: date)
        case 7: // Saturday -> observed Friday
            return calendar.date(byAdding: .day, value: -1, to: date)
        default:
            return date
        }
    }
    
    /// Calculate Good Friday (Friday before Easter)
    private func goodFridayDate(year: Int) -> Date? {
        guard let easter = easterSunday(year: year) else { return nil }
        return Calendar.current.date(byAdding: .day, value: -2, to: easter)
    }
    
    /// Calculate Easter Sunday using the Anonymous Gregorian algorithm
    private func easterSunday(year: Int) -> Date? {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }
}

/// Helper enum for weekday calculations
private enum Weekday {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday
    
    var calendarValue: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}
