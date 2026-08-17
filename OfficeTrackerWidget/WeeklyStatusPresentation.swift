//
//  WeeklyStatusPresentation.swift
//  OfficeTrackerWidget
//
//  Status -> color/icon/title mapping for WeeklyComplianceStatus, mirroring
//  InOfficeDaysTracker/Components/WeeklyComplianceCard.swift so widget views
//  don't reinvent the same switch statements.
//

import SwiftUI

enum WeeklyStatusPresentation {
    static func color(for status: WeeklyComplianceStatus) -> Color {
        switch status {
        case .complete: return WidgetDesignTokens.successGreen
        case .onTrack: return WidgetDesignTokens.cyanAccent
        case .needsOfficeDays, .needsAnchorDay: return WidgetDesignTokens.orangeAccent
        case .missed: return WidgetDesignTokens.statusAway
        case .notApplicable: return WidgetDesignTokens.textSecondary
        }
    }

    static func icon(for status: WeeklyComplianceStatus) -> String {
        switch status {
        case .complete: return "checkmark.circle.fill"
        case .onTrack: return "arrow.forward.circle.fill"
        case .needsOfficeDays: return "calendar.badge.exclamationmark"
        case .needsAnchorDay: return "flag.circle.fill"
        case .missed: return "xmark.circle.fill"
        case .notApplicable: return "info.circle"
        }
    }

    static func title(for status: WeeklyComplianceStatus) -> String {
        switch status {
        case .complete: return "Complete"
        case .onTrack: return "On Track"
        case .needsOfficeDays: return "Action Needed"
        case .needsAnchorDay: return "Anchor Day Needed"
        case .missed: return "Missed"
        case .notApplicable: return "Not Active"
        }
    }
}
