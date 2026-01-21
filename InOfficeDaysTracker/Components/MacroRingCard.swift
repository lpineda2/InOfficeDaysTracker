//
//  MacroRingCard.swift
//  InOfficeDaysTracker
//
//  Created for MFP-style redesign
//  Hero card with 3 circular progress rings similar to MyFitnessPal's macros card
//

import SwiftUI

/// A hero card displaying three progress rings for Days, Goal Progress, and Pace
/// Styled similar to MyFitnessPal's macros dashboard card
struct MacroRingCard: View {
    let daysCompleted: Int
    let daysGoal: Int
    let daysRemaining: Int
    let paceNeeded: Double // days per week needed to meet goal
    let weeksRemaining: Int
    
    private var daysPercentage: Double {
        guard daysGoal > 0 else { return 0 }
        return min(Double(daysCompleted) / Double(daysGoal), 1.0)
    }
    
    private var pacePercentage: Double {
        // Show how close current pace is to needed pace (capped at 100%)
        guard paceNeeded > 0 else { return 1.0 }
        let maxPace = 5.0 // Max reasonable days per week
        return min(paceNeeded / maxPace, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress")
                .font(Typography.cardTitle)
                .foregroundColor(DesignTokens.textPrimary)
            
            HStack(spacing: 0) {
                // Days Completed Ring
                MacroRingItem(
                    title: "Days",
                    value: daysCompleted,
                    subtitle: "/\(daysGoal)",
                    bottomLabel: "\(daysRemaining) left",
                    percentage: daysPercentage,
                    gradient: DesignTokens.accentCyan,
                    accentColor: DesignTokens.cyanAccent
                )
                
                Spacer()
                
                // Goal Progress Ring
                MacroRingItem(
                    title: "Goal",
                    value: Int(daysPercentage * 100),
                    subtitle: "%",
                    bottomLabel: goalStatusLabel,
                    percentage: daysPercentage,
                    gradient: DesignTokens.accentPurple,
                    accentColor: DesignTokens.purpleAccent
                )
                
                Spacer()
                
                // Pace Ring
                MacroRingItem(
                    title: "Pace",
                    value: Int(paceNeeded.rounded()),
                    subtitle: "/wk",
                    bottomLabel: paceLabel,
                    percentage: 1.0 - pacePercentage, // Invert: lower pace needed = better
                    gradient: DesignTokens.accentOrange,
                    accentColor: DesignTokens.orangeAccent
                )
            }
        }
        .cardStyle()
    }
    
    private var goalStatusLabel: String {
        if daysPercentage >= 1.0 {
            return "Complete!"
        } else if daysPercentage >= 0.75 {
            return "Almost there"
        } else if daysPercentage >= 0.5 {
            return "On track"
        } else {
            return "Keep going"
        }
    }
    
    private var paceLabel: String {
        if daysRemaining <= 0 {
            return "Month over"
        } else if paceNeeded <= 0 {
            return "Goal met!"
        } else if paceNeeded > 5 {
            return "Challenging"
        } else {
            return "\(daysRemaining)d left"
        }
    }
}

/// Individual ring item within the MacroRingCard
struct MacroRingItem: View {
    let title: String
    let value: Int
    let subtitle: String
    let bottomLabel: String
    let percentage: Double
    let gradient: LinearGradient
    let accentColor: Color
    
    private let ringSize: CGFloat = 80
    private let strokeWidth: CGFloat = 10
    
    private var safePercentage: Double {
        guard !percentage.isNaN && !percentage.isInfinite && percentage >= 0 else { return 0.0 }
        return min(percentage, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Title label
            Text(title)
                .font(Typography.accentLabel)
                .foregroundColor(accentColor)
            
            // Progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(DesignTokens.ringBackground, lineWidth: strokeWidth)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: safePercentage)
                    .stroke(
                        gradient,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: safePercentage)
                
                // Center content
                VStack(spacing: 0) {
                    HStack(alignment: .lastTextBaseline, spacing: 1) {
                        Text("\(value)")
                            .font(Typography.statNumber)
                            .foregroundColor(DesignTokens.textPrimary)
                        Text(subtitle)
                            .font(Typography.captionSmall)
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                }
            }
            .frame(width: ringSize, height: ringSize)
            
            // Bottom label
            Text(bottomLabel)
                .font(Typography.caption)
                .foregroundColor(DesignTokens.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview("Macro Ring Card") {
    VStack(spacing: 20) {
        MacroRingCard(
            daysCompleted: 8,
            daysGoal: 12,
            daysRemaining: 4,
            paceNeeded: 2.0,
            weeksRemaining: 2
        )
        
        MacroRingCard(
            daysCompleted: 12,
            daysGoal: 12,
            daysRemaining: 0,
            paceNeeded: 0,
            weeksRemaining: 1
        )
    }
    .padding()
    .background(DesignTokens.appBackground)
}
