//
//  AppGroupKeys.swift
//  InOfficeDaysTracker
//
//  Centralized source of truth for all shared UserDefaults keys across app and widget.
//  The widget target has a duplicate copy of this file.
//

import Foundation

struct AppGroupKeys {
    // App Group identifier for shared UserDefaults
    static let appGroupSuiteName = "group.com.lpineda.InOfficeDaysTracker"

    // Core data persistence keys
    static let settingsKey = "AppSettings"
    static let visitsKey = "OfficeVisits"
    static let currentVisitKey = "CurrentVisit"
    static let widgetDataKey = "WidgetData"

    // Office status
    static let isCurrentlyInOfficeKey = "IsCurrentlyInOffice"

    // Exit grace period persistence (shared between AppData and LocationService)
    static let pendingExitTimeKey = "PendingExitTime"
    static let pendingExitRegionIdKey = "PendingExitRegionId"
    static let gracePeriodExpiresKey = "GracePeriodExpires"
}
