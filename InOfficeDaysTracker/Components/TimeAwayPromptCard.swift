//
//  TimeAwayPromptCard.swift
//  InOfficeDaysTracker
//
//  One-time dashboard prompt introducing PTO/holiday goal adjustment.
//

import SwiftUI

/// Tells weekly-tracking users that their goal can adjust for time off, lets
/// them turn it on, and exposes the two follow-up settings inline.
///
/// Weekly tracking shipped before this capability existed, so users who
/// already enabled it have no reason to revisit their policy settings. This
/// surfaces the option where they actually look, and disappears for good once
/// enabled and confirmed, or dismissed.
struct TimeAwayPromptCard: View {
    /// Enables time-away handling.
    let onEnable: () -> Void
    /// Permanently dismisses the prompt.
    let onDismiss: () -> Void

    /// Days away tolerated before the weekly goal starts dropping.
    @Binding var unavailabilityAllowance: Int
    /// Whether a holiday anywhere in the week waives the anchor-day rule.
    @Binding var waivesAnchorDaysOnHolidayWeeks: Bool
    /// Whether the policy has an anchor-day rule at all; the waiver control is
    /// meaningless without one.
    let hasAnchorDay: Bool

    /// Set once the user enables from here, so the card confirms what changed
    /// rather than vanishing and leaving them unsure whether it worked.
    @State private var didEnable = false

    /// Largest allowance worth offering — a full working week.
    private let maximumAllowance = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: didEnable ? "checkmark.circle.fill" : "calendar.badge.minus")
                    .iconBackground(color: didEnable ? DesignTokens.successGreen : DesignTokens.cyanAccent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(didEnable ? "Time off now lowers your goal" : "Taking time off?")
                        .font(Typography.cardTitle)
                        .foregroundColor(DesignTokens.textPrimary)

                    Text(bodyText)
                        .font(Typography.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if didEnable {
                settingsControls
            }

            HStack(spacing: 16) {
                if didEnable {
                    Button(action: onDismiss) {
                        Text("Done")
                            .font(Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.cyanAccent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: enable) {
                        Text("Turn On")
                            .font(Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.cyanAccent)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDismiss) {
                        Text("Not Now")
                            .font(Typography.caption)
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    /// The two settings worth tuning immediately, shown inline so the user
    /// doesn't have to go hunting for them in Settings.
    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Stepper(value: $unavailabilityAllowance, in: 0...maximumAllowance) {
                HStack {
                    Text("Days away before reducing")
                        .font(Typography.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                    Spacer()
                    Text("\(unavailabilityAllowance)")
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.cyanAccent)
                }
            }
            .accessibilityLabel("Days away before the goal is reduced")
            .accessibilityValue("\(unavailabilityAllowance)")

            if hasAnchorDay {
                Toggle(isOn: $waivesAnchorDaysOnHolidayWeeks) {
                    Text("Waive anchor day in holiday weeks")
                        .font(Typography.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.switch)
            }

            Text(allowanceExplanation)
                .font(Typography.caption)
                .foregroundColor(DesignTokens.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bodyText: String {
        didEnable
            ? "PTO, sick days, and holidays will lower that week's goal."
            : "Your weekly goal can drop for PTO, sick days, and holidays instead of counting them against you."
    }

    private var allowanceExplanation: String {
        switch unavailabilityAllowance {
        case 0:
            return "Each day away lowers that week's goal by one."
        case 1:
            return "The first day away each week won't change your goal."
        default:
            return "The first \(unavailabilityAllowance) days away each week won't change your goal."
        }
    }

    private func enable() {
        withAnimation {
            didEnable = true
        }
        onEnable()

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
}

// MARK: - Preview

#Preview("Time Away Prompt") {
    struct PreviewWrapper: View {
        @State private var allowance = 0
        @State private var waives = false

        var body: some View {
            VStack(spacing: 16) {
                TimeAwayPromptCard(
                    onEnable: {},
                    onDismiss: {},
                    unavailabilityAllowance: $allowance,
                    waivesAnchorDaysOnHolidayWeeks: $waives,
                    hasAnchorDay: true
                )
                Spacer()
            }
            .padding()
            .background(DesignTokens.appBackground)
        }
    }

    return PreviewWrapper()
}
