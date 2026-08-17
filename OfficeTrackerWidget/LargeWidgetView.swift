//
//  LargeWidgetView.swift
//  OfficeTrackerWidget
//
//  Large widget (4x4) - Comprehensive display with detailed statistics
//  Updated for MFP-style design
//

import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let data: WidgetData
    var entryDate: Date = Date()

    private var weekly: WeeklyComplianceResult? {
        data.trackingCadence.includesWeekly ? data.weeklyResult : nil
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with month/week and current status
            headerView

            // Main progress section
            mainProgressSection

            // Weekly guidance message, when weekly tracking is primary
            if let weekly {
                weeklyGuidanceRow(weekly)
            }

            // Statistics grid
            statisticsGrid

            Spacer()
        }
        .padding(20)
        .containerBackground(for: .widget) {
            // Rich gradient background based on status
            LinearGradient(
                gradient: Gradient(colors: [
                    statusColor.opacity(0.15),
                    statusColor.opacity(0.05),
                    Color.clear
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(.background)
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(weekly != nil ? "This Week" : data.monthName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(WidgetDesignTokens.textPrimary)

                HStack(spacing: 6) {
                    Image(systemName: data.isCurrentlyInOffice ? "clock.badge.fill" : "figure.walk")
                        .font(.caption)
                        .foregroundColor(statusColor)

                    Text(data.isCurrentlyInOffice ? "Currently in office" : "Currently away")
                        .font(.caption)
                        .foregroundColor(WidgetDesignTokens.textSecondary)
                }
            }

            Spacer()

            // Goal/status badge
            if let weekly {
                VStack {
                    Text(WeeklyStatusPresentation.title(for: weekly.status))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(WeeklyStatusPresentation.color(for: weekly.status))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(weekly.officeDaysCompleted)/\(weekly.requiredDays) days")
                        .font(.caption2)
                        .foregroundColor(WidgetDesignTokens.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(WidgetDesignTokens.ringBackground.opacity(0.5))
                .cornerRadius(8)
            } else {
                VStack {
                    Text("\(data.goal)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(WidgetDesignTokens.textPrimary)
                    Text("goal")
                        .font(.caption2)
                        .foregroundColor(WidgetDesignTokens.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(WidgetDesignTokens.ringBackground.opacity(0.5))
                .cornerRadius(8)
            }
        }
    }

    private var mainProgressSection: some View {
        HStack(spacing: 20) {
            // Circular progress — weekly days/required when weekly tracking is primary,
            // otherwise the existing monthly current/goal ring.
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

            // Additional context: visit duration and anchor-day status
            VStack(alignment: .leading, spacing: 8) {
                if data.isCurrentlyInOffice, let duration = data.visitDuration(at: entryDate) {
                    let hours = Int(duration / 3600)
                    let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
                    Text("Visit duration: \(hours)h \(minutes)m")
                        .font(.caption)
                        .foregroundColor(WidgetDesignTokens.textSecondary)
                }

                if let weekly, let anchorDescription = data.weeklyAnchorDescription {
                    HStack(spacing: 4) {
                        Image(systemName: weekly.anchorDaysSatisfied ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundColor(weekly.anchorDaysSatisfied ? WidgetDesignTokens.successGreen : WidgetDesignTokens.orangeAccent)
                        Text(weekly.anchorDaysSatisfied ? "Anchor day met (\(anchorDescription))" : "Anchor day needed (\(anchorDescription))")
                            .font(.caption)
                            .foregroundColor(WidgetDesignTokens.textSecondary)
                    }
                }
            }

            Spacer()
        }
    }

    private func weeklyGuidanceRow(_ weekly: WeeklyComplianceResult) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: WeeklyStatusPresentation.icon(for: weekly.status))
                .font(.caption)
                .foregroundColor(WeeklyStatusPresentation.color(for: weekly.status))
            Text(weekly.guidanceMessage)
                .font(.caption)
                .foregroundColor(WidgetDesignTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var statisticsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            if weekly != nil {
                // Weekly tracking is primary: demote monthly info to a compact stat card.
                StatisticCard(
                    title: "Monthly",
                    value: "\(data.current)/\(data.goal)",
                    subtitle: "days this month",
                    color: WidgetDesignTokens.cyanAccent
                )
                .frame(height: 60)

                StatisticCard(
                    title: "Days Left",
                    value: "\(data.daysLeftInMonth)",
                    subtitle: "in month",
                    color: WidgetDesignTokens.cyanAccent
                )
                .frame(height: 60)
            } else {
                StatisticCard(
                    title: "Days Left",
                    value: "\(data.daysLeftInMonth)",
                    subtitle: "in month",
                    color: WidgetDesignTokens.cyanAccent
                )
                .frame(height: 60)

                StatisticCard(
                    title: "Pace",
                    value: data.paceNeeded,
                    subtitle: "needed",
                    color: data.paceNeeded.contains("Complete") ? WidgetDesignTokens.successGreen : WidgetDesignTokens.orangeAccent
                )
                .frame(height: 60)
            }
        }
    }

    private func weeklyPercentage(_ weekly: WeeklyComplianceResult) -> Double {
        guard weekly.requiredDays > 0 else { return 0 }
        return min(Double(weekly.officeDaysCompleted) / Double(weekly.requiredDays), 1.0)
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

struct StatisticCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(WidgetDesignTokens.textSecondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(WidgetDesignTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(WidgetDesignTokens.ringBackground.opacity(0.3))
        .cornerRadius(10)
    }
}

#Preview(as: .systemLarge) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleWeekly)
}