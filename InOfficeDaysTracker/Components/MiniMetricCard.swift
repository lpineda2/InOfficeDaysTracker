//
//  MiniMetricCard.swift
//  InOfficeDaysTracker
//
//  Created for MFP-style redesign
//  Compact metric cards for streak, duration, and other stats
//

import SwiftUI

/// A compact metric card with icon, title, value, and optional progress bar
/// Similar to MyFitnessPal's Steps and Exercise cards
struct MiniMetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    let progress: Double?
    let progressColor: Color?
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        iconColor: Color,
        progress: Double? = nil,
        progressColor: Color? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.progress = progress
        self.progressColor = progressColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and optional add button
            HStack {
                Text(title)
                    .font(Typography.cardTitle)
                    .foregroundColor(DesignTokens.textPrimary)
                
                Spacer()
            }
            
            // Icon and value
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .iconBackground(color: iconColor)
                
                Text(value)
                    .font(Typography.miniNumber)
                    .foregroundColor(DesignTokens.textPrimary)
            }
            
            // Subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundColor(DesignTokens.textSecondary)
            }
            
            // Progress bar
            if let progress = progress, let progressColor = progressColor {
                ProgressBarView(
                    progress: progress,
                    color: progressColor
                )
            }
        }
        .cardStyle()
    }
}

/// A horizontal progress bar with rounded ends
struct ProgressBarView: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 6
    
    private var safeProgress: Double {
        guard !progress.isNaN && !progress.isInfinite && progress >= 0 else { return 0 }
        return min(progress, 1.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(DesignTokens.ringBackground)
                
                // Progress
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * safeProgress)
                    .animation(.easeInOut(duration: 0.5), value: safeProgress)
            }
        }
        .frame(height: height)
    }
}

/// Specialized card for displaying streak information
struct StreakMetricCard: View {
    let streakMonths: Int
    let isOnTrack: Bool
    var title: String = "Streak"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(Typography.cardTitle)
                    .foregroundColor(DesignTokens.textPrimary)
                
                Spacer()
            }
            
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .iconBackground(color: DesignTokens.orangeAccent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streakMonths)")
                        .font(Typography.miniNumber)
                        .foregroundColor(DesignTokens.textPrimary)
                    + Text(" month\(streakMonths == 1 ? "" : "s")")
                        .font(Typography.bodySecondary)
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
            
            // On track indicator
            if isOnTrack {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(DesignTokens.successGreen)
                    Text("On track this month")
                        .font(Typography.caption)
                        .foregroundColor(DesignTokens.successGreen)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundColor(DesignTokens.orangeAccent)
                    Text("Goal not yet met")
                        .font(Typography.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
        }
        .cardStyle()
    }
}

/// Specialized card for displaying average duration.
///
/// `isFullWidth` renders a slightly more prominent variant (larger number,
/// horizontally centered) for contexts where this card appears alone in a
/// row instead of paired with `StreakMetricCard` — e.g. weekly-only tracking
/// cadence, where there's no monthly streak to show alongside it.
struct DurationMetricCard: View {
    /// Average visit length in hours. `nil` means "no completed visits yet" —
    /// distinct from a genuine average of zero, so the card can say so instead
    /// of rendering a bare "0h" that reads as broken.
    let averageHours: Double?
    var isFullWidth: Bool = false
    /// Describes the window the average covers (e.g. "Per office visit (all time)").
    var subtitle: String = "Per office visit"

    init(averageHours: Double?, isFullWidth: Bool = false, subtitle: String = "Per office visit") {
        self.averageHours = averageHours
        self.isFullWidth = isFullWidth
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: isFullWidth ? .center : .leading, spacing: 12) {
            HStack {
                if isFullWidth { Spacer() }
                Text("Avg Duration")
                    .font(Typography.cardTitle)
                    .foregroundColor(DesignTokens.textPrimary)
                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .iconBackground(color: DesignTokens.purpleAccent)

                Text(formattedDuration)
                    .font(hasData ? (isFullWidth ? Typography.statNumber : Typography.miniNumber) : Typography.bodySecondary)
                    .foregroundColor(hasData ? DesignTokens.textPrimary : DesignTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(hasData ? subtitle : "Finish a visit to see your average")
                .font(Typography.caption)
                .foregroundColor(DesignTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var hasData: Bool { averageHours != nil }

    private var accessibilityLabel: String {
        guard hasData else {
            return "Average duration. No completed visits yet. Finish a visit to see your average."
        }
        return "Average duration, \(formattedDuration). \(subtitle)."
    }

    private var formattedDuration: String {
        guard let averageHours else { return "No completed visits yet" }

        let wholeHours = Int(averageHours)
        let minutes = Int((averageHours * 60).truncatingRemainder(dividingBy: 60))

        if wholeHours > 0 && minutes > 0 {
            return "\(wholeHours)h \(minutes)m"
        } else if wholeHours > 0 {
            return "\(wholeHours) hours"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "0h"
        }
    }
}

// MARK: - Preview

#Preview("Mini Metric Cards") {
    ScrollView {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                StreakMetricCard(streakMonths: 5, isOnTrack: true)
                DurationMetricCard(averageHours: 7.5)
            }

            HStack(spacing: 12) {
                StreakMetricCard(streakMonths: 0, isOnTrack: false)
                DurationMetricCard(averageHours: nil)
            }

            // Weekly cadence: full-width, all-time window, and the empty state
            DurationMetricCard(
                averageHours: 8.2,
                isFullWidth: true,
                subtitle: "Per office visit (all time)"
            )

            DurationMetricCard(
                averageHours: nil,
                isFullWidth: true,
                subtitle: "Per office visit (all time)"
            )

            MiniMetricCard(
                title: "This Week",
                value: "3 days",
                subtitle: "Goal: 3 days/week",
                icon: "calendar",
                iconColor: DesignTokens.cyanAccent,
                progress: 1.0,
                progressColor: DesignTokens.cyanAccent
            )
        }
        .padding()
    }
    .background(DesignTokens.appBackground)
}
