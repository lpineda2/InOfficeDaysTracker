//
//  WidgetData.swift
//  Shared between app and widget
//
//  Data model for widget consumption
//

import Foundation

struct WidgetData: Codable {
    let current: Int
    let goal: Int
    let percentage: Double
    let monthName: String
    let isCurrentlyInOffice: Bool
    let currentVisitDuration: TimeInterval?
    let visitStartTime: Date?
    let weeklyProgress: Int
    let averageDuration: Double
    let daysRemaining: Int
    let paceNeeded: String
    let lastUpdated: Date
    let statusMessage: String
    let daysLeftInMonth: Int

    /// How the user tracks their office-day goal. `.monthly` preserves all
    /// existing behavior above; `.weekly`/`.both` also populate `weeklyResult`.
    let trackingCadence: TrackingCadence
    /// Current-week compliance against `WeeklyPolicy`, present whenever
    /// `trackingCadence.includesWeekly`; `nil` for monthly-only users.
    let weeklyResult: WeeklyComplianceResult?
    /// Human-readable anchor-day rule (e.g. "Monday or Friday"), if the
    /// active weekly policy defines one.
    let weeklyAnchorDescription: String?

    /// Compute visit duration dynamically based on a given date (for timeline entries)
    func visitDuration(at date: Date) -> TimeInterval? {
        guard isCurrentlyInOffice, let startTime = visitStartTime else { return nil }
        return max(0, date.timeIntervalSince(startTime))
    }
    
    // Computed properties matching your MainProgressView
    var safePercentage: Double {
        guard !percentage.isNaN && !percentage.isInfinite && percentage >= 0 else { return 0.0 }
        return min(percentage, 1.0)
    }
    
    var safePercentageDisplay: Int {
        let displayValue = Int(safePercentage * 100)
        return max(0, min(100, displayValue))
    }
    
    var isGoalComplete: Bool {
        return current >= goal
    }
    
    var statusColor: StatusColor {
        if isGoalComplete {
            return .green  // Goal achieved
        } else if isCurrentlyInOffice {
            return .green  // Currently in office
        } else {
            return .orange // Away from office
        }
    }
    
    var progressGradient: ProgressGradient {
        if isGoalComplete {
            return .celebration  // Gold/green for goal complete
        } else {
            return .standard     // Blue/cyan standard
        }
    }
    
    enum StatusColor {
        case green, orange, blue
    }
    
    enum ProgressGradient {
        case standard    // Blue to cyan
        case celebration // Gold to green
    }
}

// MARK: - Sample Data
extension WidgetData {
    static let placeholder = WidgetData(
        current: 8,
        goal: 12,
        percentage: 0.67,
        monthName: "October 2025",
        isCurrentlyInOffice: false,
        currentVisitDuration: nil,
        visitStartTime: nil,
        weeklyProgress: 3,
        averageDuration: 7.5,
        daysRemaining: 4,
        paceNeeded: "2.0 days/week",
        lastUpdated: Date(),
        statusMessage: "5 more days needed",
        daysLeftInMonth: 28,
        trackingCadence: .monthly,
        weeklyResult: nil,
        weeklyAnchorDescription: nil
    )

    static let sampleProgress = WidgetData(
        current: 15,
        goal: 12,
        percentage: 1.25,
        monthName: "October 2025",
        isCurrentlyInOffice: true,
        currentVisitDuration: 14400, // 4 hours
        visitStartTime: Date().addingTimeInterval(-14400),
        weeklyProgress: 4,
        averageDuration: 8.2,
        daysRemaining: 0,
        paceNeeded: "Goal complete!",
        lastUpdated: Date(),
        statusMessage: "Goal achieved! 🎉",
        daysLeftInMonth: 28,
        trackingCadence: .monthly,
        weeklyResult: nil,
        weeklyAnchorDescription: nil
    )

    /// Sample data for a user tracking weekly-only, mid-week, on track.
    static let sampleWeekly = WidgetData(
        current: 8,
        goal: 12,
        percentage: 0.67,
        monthName: "October 2025",
        isCurrentlyInOffice: false,
        currentVisitDuration: nil,
        visitStartTime: nil,
        weeklyProgress: 2,
        averageDuration: 7.5,
        daysRemaining: 4,
        paceNeeded: "2.0 days/week",
        lastUpdated: Date(),
        statusMessage: "5 more days needed",
        daysLeftInMonth: 28,
        trackingCadence: .weekly,
        weeklyResult: WeeklyComplianceResult(
            weekStart: Date(),
            weekEnd: Date().addingTimeInterval(7 * 86400),
            isApplicable: true,
            officeDaysCompleted: 2,
            requiredDays: 3,
            weeklyMinimumSatisfied: false,
            requiredWeekdaysSatisfied: true,
            anchorDaysSatisfied: true,
            status: .onTrack,
            guidanceMessage: "You need 1 more office day this week.",
            suggestedWeekday: .wednesday
        ),
        weeklyAnchorDescription: "Monday or Friday"
    )

    static let noData = WidgetData(
        current: 0,
        goal: 12,
        percentage: 0.0,
        monthName: "October 2025",
        isCurrentlyInOffice: false,
        currentVisitDuration: nil,
        visitStartTime: nil,
        weeklyProgress: 0,
        averageDuration: 0.0,
        daysRemaining: 12,
        paceNeeded: "Open app to start",
        lastUpdated: Date(),
        statusMessage: "12 more days needed",
        daysLeftInMonth: 28,
        trackingCadence: .monthly,
        weeklyResult: nil,
        weeklyAnchorDescription: nil
    )
}