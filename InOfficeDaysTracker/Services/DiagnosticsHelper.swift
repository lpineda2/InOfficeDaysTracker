//
//  DiagnosticsHelper.swift
//  InOfficeDaysTracker
//
//  Helper for generating and managing app diagnostics
//

import Foundation
import UIKit
import CoreLocation
import EventKit

struct DiagnosticsHelper {
    
    /// Generate comprehensive app diagnostics for troubleshooting
    @MainActor
    static func generateAppDiagnostics(appData: AppData) -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let deviceModel = UIDevice.current.model
        let iosVersion = UIDevice.current.systemVersion
        let deviceName = UIDevice.current.name
        
        // Get current state
        let isInOffice = appData.isCurrentlyInOffice
        let hasCurrentVisit = appData.currentVisit != nil
        let visitsCount = appData.visits.count
        let validVisitsThisMonth = appData.getValidVisits(for: Date()).count
        
        // Get current visit details if exists
        var currentVisitInfo = "None"
        if let visit = appData.currentVisit {
            let entryTime = ISO8601DateFormatter().string(from: visit.entryTime)
            let isActive = visit.isActiveSession
            currentVisitInfo = "Entry: \(entryTime), Active: \(isActive)"
        }
        
        // Get location permissions
        let locationAuth = CLLocationManager().authorizationStatus
        let locationAuthString: String
        switch locationAuth {
        case .notDetermined: locationAuthString = "Not Determined"
        case .restricted: locationAuthString = "Restricted"
        case .denied: locationAuthString = "Denied"
        case .authorizedAlways: locationAuthString = "Always"
        case .authorizedWhenInUse: locationAuthString = "When In Use"
        @unknown default: locationAuthString = "Unknown"
        }
        
        // Get calendar permissions
        let calendarAuth = EKEventStore.authorizationStatus(for: .event)
        let calendarAuthString: String
        switch calendarAuth {
        case .notDetermined: calendarAuthString = "Not Determined"
        case .restricted: calendarAuthString = "Restricted"
        case .denied: calendarAuthString = "Denied"
        case .fullAccess: calendarAuthString = "Full Access"
        case .writeOnly: calendarAuthString = "Write Only"
        @unknown default: calendarAuthString = "Unknown"
        }
        
        // Get settings
        let calendarEnabled = appData.settings.calendarSettings.isEnabled
        let notificationsEnabled = appData.settings.notificationsEnabled
        let officeLocationsCount = appData.settings.officeLocations.count
        let trackingDays = appData.settings.trackingDays.sorted()
        let monthlyGoal = appData.getGoalForMonth(Date())
        
        // Get office hours
        let startHour = Calendar.current.component(.hour, from: appData.settings.officeHours.startTime)
        let endHour = Calendar.current.component(.hour, from: appData.settings.officeHours.endTime)
        
        let diagnostics = """
        InOfficeDaysTracker Diagnostics
        ================================
        
        App Information:
        - Version: \(appVersion) (Build \(buildNumber))
        - Generated: \(ISO8601DateFormatter().string(from: Date()))
        
        Device Information:
        - Device: \(deviceName)
        - Model: \(deviceModel)
        - iOS Version: \(iosVersion)
        
        Permissions:
        - Location: \(locationAuthString)
        - Calendar: \(calendarAuthString)
        
        Current State:
        - Currently In Office: \(isInOffice)
        - Has Active Visit: \(hasCurrentVisit)
        - Current Visit: \(currentVisitInfo)
        - Total Visits: \(visitsCount)
        - Valid Visits This Month: \(validVisitsThisMonth)
        
        Settings:
        - Calendar Integration: \(calendarEnabled ? "Enabled" : "Disabled")
        - Notifications: \(notificationsEnabled ? "Enabled" : "Disabled")
        - Office Locations: \(officeLocationsCount)
        - Tracking Days: \(trackingDays.map { dayName(for: $0) }.joined(separator: ", "))
        - Office Hours: \(startHour):00 - \(endHour):00
        - Monthly Goal: \(monthlyGoal) days
        
        ================================
        """
        
        return diagnostics
    }
    
    /// Copy text to system clipboard
    static func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
    
    /// Convert weekday number to name
    private static func dayName(for weekday: Int) -> String {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard weekday >= 1 && weekday <= 7 else { return "Unknown" }
        return days[weekday - 1]
    }
}
