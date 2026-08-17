//
//  MediumWidgetView.swift
//  OfficeTrackerWidget
//
//  Medium widget (4x2) - Core widget with circular progress and key status
//  Updated for MFP-style design
//

import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let data: WidgetData
    var entryDate: Date = Date()

    private var weekly: WeeklyComplianceResult? {
        data.trackingCadence.includesWeekly ? data.weeklyResult : nil
    }

    var body: some View {
        HStack(spacing: 16) {
            // Circular Progress (adapted from MainProgressView)
            if let weekly {
                CircularProgressViewWidget(
                    current: weekly.officeDaysCompleted,
                    goal: weekly.requiredDays,
                    percentage: weeklyPercentage(weekly),
                    gradient: weekly.status == .complete ? .celebration : .standard
                )
                .frame(width: 100, height: 100)
            } else {
                CircularProgressViewWidget(
                    current: data.current,
                    goal: data.goal,
                    percentage: data.safePercentage,
                    gradient: data.progressGradient
                )
                .frame(width: 100, height: 100)
            }

            // Status Information
            VStack(alignment: .leading, spacing: 8) {
                // Month name, or "This Week" label when weekly tracking is primary
                Text(weekly != nil ? "This Week" : data.monthName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(WidgetDesignTokens.textPrimary)

                // Current status
                HStack(spacing: 6) {
                    Image(systemName: data.isCurrentlyInOffice ? "clock.badge.fill" : "figure.walk")
                        .font(.caption)
                        .foregroundColor(statusColor)

                    Text(data.isCurrentlyInOffice ? "In Office" : "Away")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                }

                if let weekly {
                    // Weekly compliance status + days completed/required
                    HStack(spacing: 6) {
                        Image(systemName: WeeklyStatusPresentation.icon(for: weekly.status))
                            .foregroundColor(WeeklyStatusPresentation.color(for: weekly.status))
                            .font(.caption)

                        Text("\(WeeklyStatusPresentation.title(for: weekly.status)) · \(weekly.officeDaysCompleted) of \(weekly.requiredDays)")
                            .font(.subheadline)
                            .foregroundColor(WidgetDesignTokens.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    // Anchor-day indicator, if the policy defines one
                    if let anchorDescription = data.weeklyAnchorDescription {
                        HStack(spacing: 6) {
                            Image(systemName: weekly.anchorDaysSatisfied ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundColor(weekly.anchorDaysSatisfied ? WidgetDesignTokens.successGreen : WidgetDesignTokens.orangeAccent)

                            Text(weekly.anchorDaysSatisfied ? "Anchor day met" : "Anchor day needed (\(anchorDescription))")
                                .font(.caption)
                                .foregroundColor(WidgetDesignTokens.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                } else {
                    // Weekly progress (monthly-only cadence: raw visit count for the week)
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(WidgetDesignTokens.cyanAccent)
                            .font(.caption)

                        Text("This Week: \(data.weeklyProgress)")
                            .font(.subheadline)
                            .foregroundColor(WidgetDesignTokens.textSecondary)
                    }
                }

                // Current visit duration (if in office)
                if data.isCurrentlyInOffice, let duration = data.visitDuration(at: entryDate) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(WidgetDesignTokens.cyanAccent)
                            .font(.caption)

                        Text(formatDuration(duration))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(WidgetDesignTokens.cyanAccent)
                    }
                }

                Spacer()
            }

            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            // Widget background with subtle status-aware accent
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .stroke(statusColor.opacity(0.3), lineWidth: 2)
        }
    }

    private func weeklyPercentage(_ weekly: WeeklyComplianceResult) -> Double {
        guard weekly.requiredDays > 0 else { return 0 }
        return min(Double(weekly.officeDaysCompleted) / Double(weekly.requiredDays), 1.0)
    }

    private var statusColor: Color {
        switch data.statusColor {
        case .green:
            return WidgetDesignTokens.statusInOffice
        case .orange:
            return WidgetDesignTokens.statusAway
        case .blue:
            return WidgetDesignTokens.cyanAccent
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours == 0 && minutes == 0 && duration > 0 {
            return "< 1m"
        } else if hours == 0 {
            return "\(minutes)m"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
}

#Preview(as: .systemMedium) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleWeekly)
}