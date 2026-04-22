//
//  CalendarSettings.swift
//  InOfficeDaysTracker
//
//  Simplified calendar integration settings
//

import Foundation
import EventKit

// MARK: - Calendar Settings

struct CalendarSettings: Codable {
    /// Whether calendar integration is enabled
    var isEnabled: Bool = false
    
    /// The identifier of the selected calendar
    var selectedCalendarId: String?
    
    /// Custom title for office events
    var officeEventTitle: String = "In Office Day"
    
    // MARK: - Validation
    
    var isValidConfiguration: Bool {
        return !officeEventTitle.isEmpty && officeEventTitle.count <= 50
    }
    
    // MARK: - Factory
    
    static var `default`: CalendarSettings {
        return CalendarSettings()
    }
    
    mutating func resetToDefaults() {
        self = CalendarSettings.default
    }
}

// MARK: - Calendar Event UID Generation

struct CalendarEventUID {
    /// Generate a simple date-based UID for office events
    static func generate(for date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        return "iod-\(dateString)-office"
    }
}
