//
//  TimeAwayPromptCard.swift
//  InOfficeDaysTracker
//
//  One-time dashboard prompt introducing PTO/holiday goal adjustment.
//

import SwiftUI

/// Tells weekly-tracking users that their goal can adjust for time off, and
/// lets them turn it on without leaving the dashboard.
///
/// Weekly tracking shipped before this capability existed, so users who
/// already enabled it have no reason to revisit their policy settings. This
/// surfaces the option where they actually look, and disappears for good once
/// enabled or dismissed.
struct TimeAwayPromptCard: View {
    /// Enables time-away handling.
    let onEnable: () -> Void
    /// Permanently dismisses the prompt.
    let onDismiss: () -> Void
    /// Opens weekly policy settings for fine-tuning after enabling.
    let onOpenSettings: () -> Void

    /// Set once the user enables from here, so the card confirms what changed
    /// rather than vanishing and leaving them unsure whether it worked.
    @State private var didEnable = false

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

            HStack(spacing: 16) {
                if didEnable {
                    Button(action: onOpenSettings) {
                        Text("Adjust Settings")
                            .font(Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.cyanAccent)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDismiss) {
                        Text("Done")
                            .font(Typography.caption)
                            .foregroundColor(DesignTokens.textSecondary)
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
        .accessibilityLabel(didEnable
            ? "Time off now lowers your goal. \(bodyText)"
            : "Taking time off? \(bodyText)")
    }

    private var bodyText: String {
        didEnable
            ? "PTO, sick days, and holidays will lower that week's goal. Fine-tune how much in Weekly Policy."
            : "Your weekly goal can drop for PTO, sick days, and holidays instead of counting them against you."
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
    VStack(spacing: 16) {
        TimeAwayPromptCard(onEnable: {}, onDismiss: {}, onOpenSettings: {})
        Spacer()
    }
    .padding()
    .background(DesignTokens.appBackground)
}
