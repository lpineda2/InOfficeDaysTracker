//
//  LocationAccessCard.swift
//  InOfficeDaysTracker
//
//  Dashboard banner shown when automatic tracking can't run because of the
//  location access state (never asked, denied, "While Using" only, ...).
//

import SwiftUI

/// Explains why automatic tracking isn't running and offers the one action
/// that can fix it. Shown only after setup, so users who finished setup (or
/// restored an install) without ever granting access aren't left silently
/// untracked.
struct LocationAccessCard: View {
    let state: LocationAccessState
    /// Runs the state's primary action (request permission or open Settings).
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "location.slash.fill")
                    .iconBackground(color: DesignTokens.orangeAccent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.title)
                        .font(Typography.cardTitle)
                        .foregroundColor(DesignTokens.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text(state.message)
                        .font(Typography.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if let actionTitle = state.actionTitle {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.cyanAccent)
                }
                .buttonStyle(.plain)
                .accessibilityHint(state.action == .openSettings
                                   ? "Opens the Settings app"
                                   : "Shows the system location prompt")
            }
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
    }
}

#Preview("Location Access - Needs Prompt") {
    LocationAccessCard(state: .needsPrompt, onAction: {})
        .padding()
}

#Preview("Location Access - Monitoring Unavailable") {
    LocationAccessCard(state: .monitoringUnavailable, onAction: {})
        .padding()
}
