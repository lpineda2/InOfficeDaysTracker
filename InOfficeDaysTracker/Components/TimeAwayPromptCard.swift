//
//  TimeAwayPromptCard.swift
//  InOfficeDaysTracker
//
//  One-time dashboard prompt introducing PTO/holiday goal adjustment.
//

import SwiftUI

/// Tells weekly-tracking users that their goal can adjust for time off.
///
/// Weekly tracking shipped before this capability existed, so users who
/// already enabled it have no reason to revisit their policy settings. This
/// surfaces the option where they actually look, and disappears for good once
/// dismissed or acted on.
struct TimeAwayPromptCard: View {
    /// Opens the weekly policy settings.
    let onSetUp: () -> Void
    /// Permanently dismisses the prompt.
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "calendar.badge.minus")
                    .iconBackground(color: DesignTokens.cyanAccent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Taking time off?")
                        .font(Typography.cardTitle)
                        .foregroundColor(DesignTokens.textPrimary)

                    Text("Your weekly goal can drop for PTO, sick days, and holidays instead of counting them against you.")
                        .font(Typography.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                Button(action: onSetUp) {
                    Text("Set Up")
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

                Spacer()
            }
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Taking time off? Your weekly goal can drop for PTO, sick days, and holidays.")
    }
}

// MARK: - Preview

#Preview("Time Away Prompt") {
    VStack {
        TimeAwayPromptCard(onSetUp: {}, onDismiss: {})
        Spacer()
    }
    .padding()
    .background(DesignTokens.appBackground)
}
