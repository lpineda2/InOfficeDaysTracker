//
//  WeeklyPolicySettingsView.swift
//  InOfficeDaysTracker
//
//  Configuration for the general-purpose weekly hybrid policy.
//

import SwiftUI

struct WeeklyPolicySettingsView: View {
    @ObservedObject var appData: AppData

    @State private var weeklyMinimumDays: Int
    @State private var requireAnchorDay: Bool
    @State private var anchorWeekdays: Set<PolicyWeekday>
    @State private var requiredWeekdays: Set<PolicyWeekday>
    @State private var hasEffectiveDate: Bool
    @State private var effectiveDate: Date

    /// Weekdays offered for selection (eligible, non-weekend by default).
    private let selectableWeekdays = PolicyWeekday.weekdays

    init(appData: AppData) {
        self.appData = appData
        let policy = appData.settings.weeklyPolicy
        _weeklyMinimumDays = State(initialValue: policy.weeklyMinimumDays)
        let firstAnchorGroup = policy.anchorDayGroups.first ?? []
        _requireAnchorDay = State(initialValue: !policy.anchorDayGroups.isEmpty)
        _anchorWeekdays = State(initialValue: Set(firstAnchorGroup.isEmpty ? [.monday, .friday] : firstAnchorGroup))
        _requiredWeekdays = State(initialValue: Set(policy.requiredWeekdays))
        _hasEffectiveDate = State(initialValue: policy.effectiveStartDate != nil)
        _effectiveDate = State(initialValue: policy.effectiveStartDate ?? Date())
    }

    var body: some View {
        Form {
            minimumDaysSection
            anchorDaySection
            requiredDaysSection
            effectiveDateSection
        }
        .navigationTitle("Weekly Policy")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: weeklyMinimumDays) { _, _ in savePolicy() }
        .onChange(of: requireAnchorDay) { _, _ in savePolicy() }
        .onChange(of: anchorWeekdays) { _, _ in savePolicy() }
        .onChange(of: requiredWeekdays) { _, _ in savePolicy() }
        .onChange(of: hasEffectiveDate) { _, _ in savePolicy() }
        .onChange(of: effectiveDate) { _, _ in savePolicy() }
    }

    // MARK: - Sections

    private var minimumDaysSection: some View {
        Section {
            Stepper(value: $weeklyMinimumDays, in: 1...selectableWeekdays.count) {
                HStack {
                    Text("Minimum days per week")
                        .font(.body)
                    Spacer()
                    Text("\(weeklyMinimumDays)")
                        .foregroundColor(DesignTokens.cyanAccent)
                        .fontWeight(.medium)
                }
            }
            .accessibilityLabel("Minimum office days per week")
            .accessibilityValue("\(weeklyMinimumDays)")
        } header: {
            Text("Weekly Goal")
        } footer: {
            Text("The number of in-office days required each week.")
        }
    }

    private var anchorDaySection: some View {
        Section {
            Toggle("Require an anchor day", isOn: $requireAnchorDay)

            if requireAnchorDay {
                PolicyWeekdaySelector(
                    title: "Anchor days",
                    selection: $anchorWeekdays,
                    options: selectableWeekdays
                )
            }
        } header: {
            Text("Anchor Day")
        } footer: {
            Text(requireAnchorDay
                 ? "At least one of the selected days must be an office day each week (e.g. Monday or Friday)."
                 : "No specific weekday is required.")
        }
    }

    private var requiredDaysSection: some View {
        Section {
            PolicyWeekdaySelector(
                title: "Required days",
                selection: $requiredWeekdays,
                options: selectableWeekdays
            )
        } header: {
            Text("Always Required (Optional)")
        } footer: {
            Text("Selected weekdays must always be office days. Leave empty if none.")
        }
    }

    private var effectiveDateSection: some View {
        Section {
            Toggle("Set an effective date", isOn: $hasEffectiveDate)

            if hasEffectiveDate {
                DatePicker(
                    "Effective from",
                    selection: $effectiveDate,
                    displayedComponents: .date
                )
            }
        } header: {
            Text("Effective Date")
        } footer: {
            Text(hasEffectiveDate
                 ? "The weekly policy applies on and after this date."
                 : "The weekly policy applies immediately.")
        }
    }

    // MARK: - Save

    private func savePolicy() {
        var newSettings = appData.settings
        var policy = newSettings.weeklyPolicy

        policy.weeklyMinimumDays = weeklyMinimumDays
        policy.anchorDayGroups = (requireAnchorDay && !anchorWeekdays.isEmpty)
            ? [anchorWeekdays.sorted()]
            : []
        policy.requiredWeekdays = requiredWeekdays.sorted()
        policy.effectiveStartDate = hasEffectiveDate ? effectiveDate : nil

        newSettings.weeklyPolicy = policy
        appData.updateSettings(newSettings)
    }
}

// MARK: - PolicyWeekday Selector

/// A row of toggleable weekday chips backed by a `Set<PolicyWeekday>`.
struct PolicyWeekdaySelector: View {
    let title: String
    @Binding var selection: Set<PolicyWeekday>
    let options: [PolicyWeekday]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(DesignTokens.textSecondary)

            HStack(spacing: 8) {
                ForEach(options) { weekday in
                    chip(for: weekday)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func chip(for weekday: PolicyWeekday) -> some View {
        let isSelected = selection.contains(weekday)
        return Button {
            if isSelected {
                selection.remove(weekday)
            } else {
                selection.insert(weekday)
            }
        } label: {
            Text(weekday.shortName)
                .font(Typography.caption)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? DesignTokens.cyanAccent : DesignTokens.surfaceElevated)
                .foregroundColor(isSelected ? .white : DesignTokens.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weekday.fullName)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    NavigationView {
        WeeklyPolicySettingsView(appData: AppData())
    }
}
