//
//  SmallWidgetView.swift
//  OfficeTrackerWidget
//
//  Small widget (2x2) - Minimal display with just circular progress
//  Updated for MFP-style design
//

import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let data: WidgetData

    private var weekly: WeeklyComplianceResult? {
        data.trackingCadence.includesWeekly ? data.weeklyResult : nil
    }

    var body: some View {
        VStack(spacing: 8) {
            // Month name (compact), or "This Week" when weekly tracking is primary
            Text(weekly != nil ? "This Week" : monthAbbreviation)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(WidgetDesignTokens.textSecondary)

            // Circular Progress — weekly days/required when weekly tracking is active,
            // otherwise the existing monthly current/goal ring.
            if let weekly {
                CircularProgressViewWidget(
                    current: weekly.officeDaysCompleted,
                    goal: weekly.requiredDays,
                    percentage: weeklyPercentage(weekly),
                    gradient: weekly.status == .complete ? .celebration : .standard
                )
                .frame(width: 80, height: 80)
            } else {
                CircularProgressViewWidget(
                    current: data.current,
                    goal: data.goal,
                    percentage: data.safePercentage,
                    gradient: data.progressGradient
                )
                .frame(width: 80, height: 80)
            }

            // Status indicator dot — weekly compliance status when active, else in-office/away
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                Text(statusLabel)
                    .font(.caption2)
                    .foregroundColor(WidgetDesignTokens.textSecondary)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            // Minimal background with status-aware border
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .stroke(statusColor.opacity(0.4), lineWidth: 1.5)
        }
    }

    private var monthAbbreviation: String {
        let components = data.monthName.split(separator: " ")
        if let month = components.first {
            let monthStr = String(month)
            return String(monthStr.prefix(3)) // Oct, Nov, etc.
        }
        return "Month"
    }

    private func weeklyPercentage(_ weekly: WeeklyComplianceResult) -> Double {
        guard weekly.requiredDays > 0 else { return 0 }
        return min(Double(weekly.officeDaysCompleted) / Double(weekly.requiredDays), 1.0)
    }

    private var statusLabel: String {
        if let weekly {
            return WeeklyStatusPresentation.title(for: weekly.status)
        }
        return data.isCurrentlyInOffice ? "In Office" : "Away"
    }

    private var statusColor: Color {
        if let weekly {
            return WeeklyStatusPresentation.color(for: weekly.status)
        }
        switch data.statusColor {
        case .green:
            return WidgetDesignTokens.statusInOffice
        case .orange:
            return WidgetDesignTokens.statusAway
        case .blue:
            return WidgetDesignTokens.cyanAccent
        }
    }
}

#Preview(as: .systemSmall) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleWeekly)
}