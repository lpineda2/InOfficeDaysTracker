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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Streak")
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

/// Specialized card for displaying average duration
struct DurationMetricCard: View {
    let hours: Double
    let minutes: Int
    
    init(averageHours: Double) {
        self.hours = averageHours
        self.minutes = Int((averageHours * 60).truncatingRemainder(dividingBy: 60))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Avg Duration")
                    .font(Typography.cardTitle)
                    .foregroundColor(DesignTokens.textPrimary)
                
                Spacer()
            }
            
            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .iconBackground(color: DesignTokens.purpleAccent)
                
                Text(formattedDuration)
                    .font(Typography.miniNumber)
                    .foregroundColor(DesignTokens.textPrimary)
            }
            
            Text("Per office visit")
                .font(Typography.caption)
                .foregroundColor(DesignTokens.textSecondary)
        }
        .cardStyle()
    }
    
    private var formattedDuration: String {
        let wholeHours = Int(hours)
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
                DurationMetricCard(averageHours: 0)
            }
            
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
