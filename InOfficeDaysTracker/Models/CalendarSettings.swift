//
//  CalendarSettings.swift
//  InOfficeDaysTracker
//
//  Calendar integration settings and configuration
//

import Foundation
import EventKit

enum CalendarEventType {
    case office, remote
}

struct CalendarSettings: Codable {
    // Core Settings
    var isEnabled: Bool = false
    var selectedCalendarId: String?
    
    // Event Customization
    var officeEventTitle: String = "Office Day"
    var remoteEventTitle: String = "Remote Work"
    
    // Timing & Display
    var useActualTimes: Bool = true // true = actual visit times, false = standard work hours
    var showAsBusy: Bool = false // false = Free (default), true = Busy
    var createAllDayEvents: Bool = false
    var includeRemoteEvents: Bool = true
    
    // Time Zone Handling
    var timeZoneMode: TimeZoneMode = .device
    var homeOfficeTimeZoneId: String?
    
    // Batch Processing
    var batchMode: BatchMode = .standard
    
    enum TimeZoneMode: String, Codable, CaseIterable {
        case device = "device"
        case homeOffice = "homeOffice"
        
        var displayName: String {
            switch self {
            case .device:
                return "Device Time Zone"
            case .homeOffice:
                return "Home Office Time Zone"
            }
        }
    }
    
    enum BatchMode: String, Codable, CaseIterable {
        case immediate = "immediate"
        case standard = "standard"
        case endOfVisit = "endOfVisit"
        
        var displayName: String {
            switch self {
            case .immediate:
                return "Immediate Updates"
            case .standard:
                return "Smart Batching (10s)"
            case .endOfVisit:
                return "End of Visit"
            }
        }
    }
    
    // Computed Properties
    var effectiveTimeZone: TimeZone {
        switch timeZoneMode {
        case .device:
            return TimeZone.current
        case .homeOffice:
            if let tzId = homeOfficeTimeZoneId,
               let homeTimeZone = TimeZone(identifier: tzId) {
                return homeTimeZone
            }
            return TimeZone.current
        }
    }
    
    // Validation
    var isValidConfiguration: Bool {
        return !officeEventTitle.isEmpty && 
               !remoteEventTitle.isEmpty &&
               officeEventTitle.count <= 50 &&
               remoteEventTitle.count <= 50
    }
    
    // Default Factory
    static var `default`: CalendarSettings {
        return CalendarSettings()
    }
    
    // Reset to defaults
    mutating func resetToDefaults() {
        let defaults = CalendarSettings.default
        self.officeEventTitle = defaults.officeEventTitle
        self.remoteEventTitle = defaults.remoteEventTitle
        self.useActualTimes = defaults.useActualTimes
        self.showAsBusy = defaults.showAsBusy
        self.createAllDayEvents = defaults.createAllDayEvents
        self.includeRemoteEvents = defaults.includeRemoteEvents
        self.timeZoneMode = defaults.timeZoneMode
        self.batchMode = defaults.batchMode
    }
}

// MARK: - Time Zone Detection Helper

class TimeZoneDetectionHelper {
    static func detectTimeZone(from address: String) async -> TimeZone? {
        guard !address.isEmpty else { return nil }
        
        do {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.geocodeAddressString(address)
            return placemarks.first?.timeZone
        } catch {
            print("Time zone detection failed: \(error)")
            return nil
        }
    }
}

// MARK: - Calendar Event UID Generation

struct CalendarEventUID {
    static func generate(date: Date, type: CalendarEventType, workHours: (start: Date, end: Date)?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let typeString = type == .office ? "office" : "remote"
        
        // Create hash from work hours for deterministic UIDs
        let hoursHash: String
        if let hours = workHours {
            let combined = "\(hours.start.timeIntervalSince1970)|\(hours.end.timeIntervalSince1970)"
            hoursHash = String(combined.hashValue % 10000) // Keep it short
        } else {
            hoursHash = "std"
        }
        
        return "iod-\(dateString)-\(typeString)-\(hoursHash)"
    }
}