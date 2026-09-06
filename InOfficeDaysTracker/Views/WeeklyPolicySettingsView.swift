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
    @State private var honorsHolidaysAndPTO: Bool
    @State private var unavailabilityAllowance: Int
    @State private var holidayAllowance: Int
    @State private var waivesAnchorDaysOnHolidayWeeks: Bool

    /// Weekdays offered for selection (eligible, non-weekend by default).
    private let selectableWeekdays = PolicyWeekday.weekdays

    /// Suppresses `savePolicy()` while `syncFromSettings()` assigns to the
    /// `@State` mirrors, so resyncing doesn't write the values straight back.
    @State private var isSyncing = false

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
        _honorsHolidaysAndPTO = State(initialValue: policy.honorsHolidaysAndPTO)
        _unavailabilityAllowance = State(initialValue: policy.unavailabilityAllowance)
        _holidayAllowance = State(initialValue: policy.holidayAllowance)
        _waivesAnchorDaysOnHolidayWeeks = State(initialValue: policy.waivesAnchorDaysOnHolidayWeeks)
    }

    var body: some View {
        Form {
            minimumDaysSection
            anchorDaySection
            requiredDaysSection
            timeAwaySection
            effectiveDateSection
        }
        .navigationTitle("Weekly Policy")
        .navigationBarTitleDisplayMode(.inline)
        // SwiftUI only uses @State initial values the first time it creates the
        // view, so these mirrors go stale if the policy changes elsewhere (for
        // example the dashboard's time-away prompt). Without this, returning
        // here would show old values and the next edit would write them back,
        // silently reverting the change.
        .onAppear { syncFromSettings() }
        .onChange(of: weeklyMinimumDays) { _, _ in savePolicy() }
        .onChange(of: requireAnchorDay) { _, _ in savePolicy() }
        .onChange(of: anchorWeekdays) { _, _ in savePolicy() }
        .onChange(of: requiredWeekdays) { _, _ in savePolicy() }
        .onChange(of: hasEffectiveDate) { _, _ in savePolicy() }
        .onChange(of: effectiveDate) { _, _ in savePolicy() }
        .onChange(of: honorsHolidaysAndPTO) { _, _ in savePolicy() }
        .onChange(of: unavailabilityAllowance) { _, _ in savePolicy() }
        .onChange(of: holidayAllowance) { _, _ in savePolicy() }
        .onChange(of: waivesAnchorDaysOnHolidayWeeks) { _, _ in savePolicy() }
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

    private var timeAwaySection: some View {
        Section {
            Toggle("Reduce goal for time away", isOn: $honorsHolidaysAndPTO)

            if honorsHolidaysAndPTO {
                Stepper(value: $unavailabilityAllowance, in: 0...selectableWeekdays.count) {
                    HStack {
                        Text("PTO/sick days allowed per week")
                            .font(.body)
                        Spacer()
                        Text("\(unavailabilityAllowance)")
                            .foregroundColor(DesignTokens.cyanAccent)
                            .fontWeight(.medium)
                    }
                }
                .accessibilityLabel("PTO or sick days allowed per week before the goal is reduced")
                .accessibilityValue("\(unavailabilityAllowance)")

                Stepper(value: $holidayAllowance, in: 0...selectableWeekdays.count) {
                    HStack {
                        Text("Holidays allowed per week")
                            .font(.body)
                        Spacer()
                        Text("\(holidayAllowance)")
                            .foregroundColor(DesignTokens.cyanAccent)
                            .fontWeight(.medium)
                    }
                }
                .accessibilityLabel("Holidays allowed per week before the goal is reduced")
                .accessibilityValue("\(holidayAllowance)")

                if requireAnchorDay {
                    Toggle("Waive anchor day in holiday weeks", isOn: $waivesAnchorDaysOnHolidayWeeks)
                }
            }
        } header: {
            Text("PTO & Holidays")
        } footer: {
            Text(timeAwayFooter)
        }
    }

    /// Describes one allowance in plain language. PTO and holidays each get
    /// their own sentence, since they can be configured independently.
    private func allowanceSentence(for allowance: Int, singular: String, plural: String) -> String {
        switch allowance {
        case 0:
            return "Each \(singular) in a week lowers that week's goal by one."
        case 1:
            // "The first 1 day" is grammatical but reads badly; English drops
            // the numeral at one.
            return "The first \(singular) each week won't change your goal; "
                 + "each one after that lowers it by one."
        default:
            return "The first \(allowance) \(plural) each week won't change your goal; "
                 + "each one after that lowers it by one."
        }
    }

    private var timeAwayFooter: String {
        guard honorsHolidaysAndPTO else {
            return "Your weekly goal stays the same regardless of PTO, sick days, or company holidays."
        }

        var lines: [String] = []

        lines.append(allowanceSentence(
            for: unavailabilityAllowance,
            singular: "PTO or sick day",
            plural: "PTO and sick days"
        ))
        lines.append(allowanceSentence(
            for: holidayAllowance,
            singular: "company holiday",
            plural: "company holidays"
        ))

        // Day-level excusal always applies when the feature is on, so state it
        // unconditionally. The toggle adds a broader whole-week waiver on top;
        // describing only the toggle would hide the automatic behavior.
        if requireAnchorDay {
            lines.append("Anchor days you're away for are excused automatically.")

            if waivesAnchorDaysOnHolidayWeeks {
                lines.append(
                    "A company holiday anywhere in the week waives the anchor-day rule, "
                    + "even if the holiday isn't an anchor day."
                )
            }
        }

        return lines.joined(separator: "\n\n")
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

    // MARK: - Sync

    /// Refreshes the `@State` mirrors from the stored policy.
    ///
    /// Needed because `@State` initial values are captured once at first
    /// creation; anything that changes the policy elsewhere would otherwise be
    /// invisible here, and the next edit would overwrite it.
    private func syncFromSettings() {
        let policy = appData.settings.weeklyPolicy

        // Cleared asynchronously rather than with `defer`: SwiftUI delivers the
        // onChange callbacks these assignments trigger after this function
        // returns, so an immediate reset would come too early to suppress them.
        isSyncing = true
        defer {
            DispatchQueue.main.async { isSyncing = false }
        }

        weeklyMinimumDays = policy.weeklyMinimumDays
        requireAnchorDay = !policy.anchorDayGroups.isEmpty
        let firstAnchorGroup = policy.anchorDayGroups.first ?? []
        anchorWeekdays = Set(firstAnchorGroup.isEmpty ? [.monday, .friday] : firstAnchorGroup)
        requiredWeekdays = Set(policy.requiredWeekdays)
        hasEffectiveDate = policy.effectiveStartDate != nil
        if let start = policy.effectiveStartDate {
            effectiveDate = start
        }
        honorsHolidaysAndPTO = policy.honorsHolidaysAndPTO
        unavailabilityAllowance = policy.unavailabilityAllowance
        holidayAllowance = policy.holidayAllowance
        waivesAnchorDaysOnHolidayWeeks = policy.waivesAnchorDaysOnHolidayWeeks
    }

    // MARK: - Save

    private func savePolicy() {
        // Assignments made by syncFromSettings() trigger onChange; writing them
        // back would be a no-op at best and could clobber a concurrent change.
        guard !isSyncing else { return }

        var newSettings = appData.settings
        var policy = newSettings.weeklyPolicy

        policy.weeklyMinimumDays = weeklyMinimumDays
        policy.anchorDayGroups = (requireAnchorDay && !anchorWeekdays.isEmpty)
            ? [anchorWeekdays.sorted()]
            : []
        policy.requiredWeekdays = requiredWeekdays.sorted()
        policy.effectiveStartDate = hasEffectiveDate ? effectiveDate : nil
        let wasEnabled = policy.honorsHolidaysAndPTO
        policy.honorsHolidaysAndPTO = honorsHolidaysAndPTO
        policy.unavailabilityAllowance = unavailabilityAllowance
        policy.holidayAllowance = holidayAllowance
        policy.waivesAnchorDaysOnHolidayWeeks = waivesAnchorDaysOnHolidayWeeks

        // Turning the feature off puts the user back in the state the dashboard
        // prompt exists for, so make it eligible again. Without this, a
        // dismissal is permanent and there's no way to see the explanation
        // again — a poor property for a discovery affordance.
        if wasEnabled && !honorsHolidaysAndPTO {
            newSettings.hasSeenTimeAwayPrompt = false
        }

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
