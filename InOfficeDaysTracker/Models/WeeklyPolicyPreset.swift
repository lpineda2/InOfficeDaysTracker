//
//  WeeklyPolicyPreset.swift
//  InOfficeDaysTracker
//
//  Ready-made weekly policy configurations for common hybrid arrangements.
//
//  These exist so a user doesn't have to assemble a multi-part policy by hand.
//  They're described by their shape ("3 days, anchor day, adjusts for time
//  away") rather than by any particular employer, and applying one is always
//  an explicit user action — nothing here changes the shipped defaults or
//  alters an existing policy on its own.
//

import Foundation

/// A named starting point for a `WeeklyPolicy`.
enum WeeklyPolicyPreset: String, CaseIterable, Identifiable {
    /// Minimum days only — no anchor day, no time-away handling.
    case simpleMinimum
    /// Minimum days plus a start/end-of-week anchor requirement.
    case anchoredWeek
    /// Anchored week that also reduces the goal for PTO and holidays.
    case anchoredWeekWithTimeAway

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simpleMinimum: return "3 days per week"
        case .anchoredWeek: return "3 days with anchor day"
        case .anchoredWeekWithTimeAway: return "3 days, anchor day, adjusts for time away"
        }
    }

    var detail: String {
        switch self {
        case .simpleMinimum:
            return "Three office days each week, any weekdays."
        case .anchoredWeek:
            return "Three office days each week, at least one on Monday or Friday."
        case .anchoredWeekWithTimeAway:
            return "Three office days each week with a Monday or Friday anchor. "
                 + "PTO, sick days, and holidays lower that week's goal, and holiday weeks skip the anchor rule."
        }
    }

    /// Builds the policy this preset describes.
    ///
    /// - Parameter existing: The current policy, so settings this preset
    ///   doesn't speak to (such as the effective date) are preserved.
    func policy(basedOn existing: WeeklyPolicy = WeeklyPolicy()) -> WeeklyPolicy {
        var policy = existing
        policy.weeklyMinimumDays = 3
        policy.requiredWeekdays = []
        policy.excludedWeekdays = PolicyWeekday.weekend

        switch self {
        case .simpleMinimum:
            policy.anchorDayGroups = []
            policy.honorsHolidaysAndPTO = false
            policy.unavailabilityAllowance = 0
            policy.waivesAnchorDaysOnHolidayWeeks = false

        case .anchoredWeek:
            policy.anchorDayGroups = [[.monday, .friday]]
            policy.honorsHolidaysAndPTO = false
            policy.unavailabilityAllowance = 0
            policy.waivesAnchorDaysOnHolidayWeeks = false

        case .anchoredWeekWithTimeAway:
            policy.anchorDayGroups = [[.monday, .friday]]
            policy.honorsHolidaysAndPTO = true
            // Absorb the first couple of days away before reducing the goal —
            // a common shape where short absences don't change expectations.
            policy.unavailabilityAllowance = 2
            policy.waivesAnchorDaysOnHolidayWeeks = true
        }

        return policy
    }

    /// Whether `policy` already matches what this preset would produce,
    /// ignoring settings the preset doesn't control.
    func matches(_ policy: WeeklyPolicy) -> Bool {
        let expected = self.policy(basedOn: policy)
        return expected.weeklyMinimumDays == policy.weeklyMinimumDays
            && expected.anchorDayGroups == policy.anchorDayGroups
            && expected.requiredWeekdays == policy.requiredWeekdays
            && expected.honorsHolidaysAndPTO == policy.honorsHolidaysAndPTO
            && expected.unavailabilityAllowance == policy.unavailabilityAllowance
            && expected.waivesAnchorDaysOnHolidayWeeks == policy.waivesAnchorDaysOnHolidayWeeks
    }
}
