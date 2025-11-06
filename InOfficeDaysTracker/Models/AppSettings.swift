//
//  AppSettings.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import Foundation
import CoreLocation

struct AppSettings: Codable {
    var officeLocation: CLLocationCoordinate2D?
    var officeAddress: String = ""
    var detectionRadius: Double = 1609.34 // 1 mile in meters
    var trackingDays: [Int] = [2, 3, 4, 5, 6] // Monday-Friday (1=Sunday, 7=Saturday)
    var officeHours: OfficeHours = OfficeHours()
    var monthlyGoal: Int = 12
    var notificationsEnabled: Bool = true
    var isSetupComplete: Bool = false
    
    // Calendar Integration (v1.8.0)
    var calendarSettings: CalendarSettings = CalendarSettings.default
    var hasSeenCalendarSetup: Bool = false
    
    struct OfficeHours: Codable {
        var startTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        var endTime: Date = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
        
        var startTimeFormatted: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: startTime)
        }
        
        var endTimeFormatted: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: endTime)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case officeAddress, detectionRadius, trackingDays, officeHours, monthlyGoal, notificationsEnabled, isSetupComplete
        case officeLatitude, officeLongitude
        case calendarSettings, hasSeenCalendarSetup
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        officeAddress = try container.decode(String.self, forKey: .officeAddress)
        detectionRadius = try container.decode(Double.self, forKey: .detectionRadius)
        trackingDays = try container.decode([Int].self, forKey: .trackingDays)
        officeHours = try container.decode(OfficeHours.self, forKey: .officeHours)
        monthlyGoal = try container.decode(Int.self, forKey: .monthlyGoal)
        notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        isSetupComplete = try container.decode(Bool.self, forKey: .isSetupComplete)
        
        if let latitude = try container.decodeIfPresent(Double.self, forKey: .officeLatitude),
           let longitude = try container.decodeIfPresent(Double.self, forKey: .officeLongitude),
           latitude.isFinite && longitude.isFinite,
           latitude >= -90 && latitude <= 90,
           longitude >= -180 && longitude <= 180 {
            officeLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        // Calendar settings (added in v1.8.0)
        calendarSettings = try container.decodeIfPresent(CalendarSettings.self, forKey: .calendarSettings) ?? CalendarSettings.default
        hasSeenCalendarSetup = try container.decodeIfPresent(Bool.self, forKey: .hasSeenCalendarSetup) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(officeAddress, forKey: .officeAddress)
        try container.encode(detectionRadius, forKey: .detectionRadius)
        try container.encode(trackingDays, forKey: .trackingDays)
        try container.encode(officeHours, forKey: .officeHours)
        try container.encode(monthlyGoal, forKey: .monthlyGoal)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(isSetupComplete, forKey: .isSetupComplete)
        
        if let location = officeLocation,
           location.latitude.isFinite && location.longitude.isFinite,
           location.latitude >= -90 && location.latitude <= 90,
           location.longitude >= -180 && location.longitude <= 180 {
            try container.encode(location.latitude, forKey: .officeLatitude)
            try container.encode(location.longitude, forKey: .officeLongitude)
        }
        
        // Calendar settings (added in v1.8.0)
        try container.encode(calendarSettings, forKey: .calendarSettings)
        try container.encode(hasSeenCalendarSetup, forKey: .hasSeenCalendarSetup)
    }
    
    var trackingDaysFormatted: String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let selectedDays = trackingDays.compactMap { dayIndex in
            dayIndex >= 1 && dayIndex <= 7 ? dayNames[dayIndex - 1] : nil
        }
        return selectedDays.joined(separator: ", ")
    }
}
