//
//  WeeklyComplianceCard.swift
//  InOfficeDaysTracker
//
//  Dashboard card summarizing the current week against a weekly hybrid policy.
//

import SwiftUI

/// Displays the current week's compliance: status, days completed vs. required,
/// whether the anchor-day requirement is met, and the next action to take.
struct WeeklyComplianceCard: View {
    let result: WeeklyComplianceResult
    let policy: WeeklyPolicy

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            // Days completed vs. required
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .iconBackground(color: statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(result.officeDaysCompleted)")
                        .font(Typography.miniNumber)
                        .foregroundColor(DesignTokens.textPrimary)
                    + Text(" of \(result.requiredDays) office days")
                        .font(Typography.bodySecondary)
                        .foregroundColor(DesignTokens.textSecondary)

                    Spacer().frame(height: 0)
                }
                Spacer()
            }

            ProgressBarView(progress: progress, color: statusColor)

            // Anchor-day indicator
            if policy.anchorDaysDescription != nil {
                anchorRow
            }

            // Next-action guidance
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.caption)
                    .foregroundColor(statusColor)
                Text(result.guidanceMessage)
                    .font(Typography.caption)
                    .foregroundColor(DesignTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("This Week")
                .font(Typography.cardTitle)
                .foregroundColor(DesignTokens.textPrimary)
            Spacer()
            Text(statusTitle)
                .font(Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(statusColor)
        }
    }

    private var anchorRow: some View {
        HStack(spacing: 4) {
            Image(systemName: result.anchorDaysSatisfied ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(result.anchorDaysSatisfied ? DesignTokens.successGreen : DesignTokens.orangeAccent)
            Text(anchorText)
                .font(Typography.caption)
                .foregroundColor(DesignTokens.textSecondary)
        }
    }

    // MARK: - Derived values

    private var progress: Double {
        guard result.requiredDays > 0 else { return 0 }
        return Double(result.officeDaysCompleted) / Double(result.requiredDays)
    }

    private var anchorText: String {
        let desc = policy.anchorDaysDescription ?? ""
        return result.anchorDaysSatisfied
            ? "Anchor day met (\(desc))"
            : "Anchor day needed (\(desc))"
    }

    private var statusColor: Color {
        switch result.status {
        case .complete: return DesignTokens.successGreen
        case .onTrack: return DesignTokens.cyanAccent
        case .needsOfficeDays, .needsAnchorDay: return DesignTokens.orangeAccent
        case .missed: return DesignTokens.statusAway
        case .notApplicable: return DesignTokens.textSecondary
        }
    }

    private var statusIcon: String {
        switch result.status {
        case .complete: return "checkmark.circle.fill"
        case .onTrack: return "arrow.forward.circle.fill"
        case .needsOfficeDays: return "calendar.badge.exclamationmark"
        case .needsAnchorDay: return "flag.circle.fill"
        case .missed: return "xmark.circle.fill"
        case .notApplicable: return "info.circle"
        }
    }

    private var statusTitle: String {
        switch result.status {
        case .complete: return "Complete"
        case .onTrack: return "On Track"
        case .needsOfficeDays: return "Action Needed"
        case .needsAnchorDay: return "Anchor Day Needed"
        case .missed: return "Missed"
        case .notApplicable: return "Not Active"
        }
    }

    private var accessibilityLabel: String {
        var parts = [
            "This week. \(statusTitle).",
            "\(result.officeDaysCompleted) of \(result.requiredDays) office days completed."
        ]
        if policy.anchorDaysDescription != nil {
            parts.append(anchorText + ".")
        }
        parts.append(result.guidanceMessage)
        return parts.joined(separator: " ")
    }
}
