//
//  WeeklyComplianceEvaluator.swift
//  InOfficeDaysTracker
//
//  Pure business logic that evaluates a single week against a `WeeklyPolicy`.
//
//  This type is deliberately free of SwiftUI and of `AppData`: it takes a
//  policy, a week, and the set of in-office dates, and returns a structured
//  result. Keeping it pure makes it cheap to unit-test and keeps complex
//  calculation logic out of the high-blast-radius `AppData` singleton.
//

import Foundation

/// Overall compliance status for a week.
enum WeeklyComplianceStatus: String, Codable {
    /// All requirements (minimum, required weekdays, anchor groups) are met.
    case complete
    /// Requirements aren't met yet but the user is comfortably on pace.
    case onTrack
    /// More office days are needed (minimum and/or a required weekday).
    case needsOfficeDays
    /// An anchor-day group (e.g. "Monday or Friday") is not yet satisfied.
    case needsAnchorDay
    /// The week's requirements can no longer be met.
    case missed
    /// The policy is not in effect for this week.
    case notApplicable
}

/// The structured outcome of evaluating a week against a `WeeklyPolicy`.
struct WeeklyComplianceResult: Equatable {
    let weekStart: Date
    let weekEnd: Date

    /// Whether the policy applies to this week at all (effective window).
    let isApplicable: Bool

    /// Distinct in-office days completed this week (on eligible weekdays).
    let officeDaysCompleted: Int
    /// The weekly minimum target.
    let requiredDays: Int

    let weeklyMinimumSatisfied: Bool
    let requiredWeekdaysSatisfied: Bool
    let anchorDaysSatisfied: Bool

    let status: WeeklyComplianceStatus

    /// User-facing guidance describing the next action.
    let guidanceMessage: String
    /// The suggested next weekday to go in (if any).
    let suggestedWeekday: PolicyWeekday?

    /// Remaining office days needed to hit the weekly minimum.
    var daysRemainingToGoal: Int { max(0, requiredDays - officeDaysCompleted) }
}

/// Evaluates weeks against weekly hybrid policies.
enum WeeklyComplianceEvaluator {

    /// Evaluate a single week against a policy.
    ///
    /// - Parameters:
    ///   - policy: The weekly policy to evaluate.
    ///   - referenceDate: Any date within the week to evaluate.
    ///   - inOfficeDates: Dates the user was in office. Days outside the week
    ///     or on excluded weekdays are ignored.
    ///   - evaluationDate: "Now" — used to decide which eligible days are still
    ///     in the future (and therefore still achievable). Defaults to
    ///     `referenceDate`, which treats the whole week as still ahead and is
    ///     ideal for planning. Pass the actual current date for live status.
    ///   - calendar: Calendar used for all date math.
    static func evaluate(
        policy: WeeklyPolicy,
        weekContaining referenceDate: Date,
        inOfficeDates: [Date],
        evaluationDate: Date? = nil,
        calendar: Calendar = .current
    ) -> WeeklyComplianceResult {

        let evalDate = evaluationDate ?? referenceDate

        // Resolve the 7-day week interval containing the reference date.
        let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
        let weekStart = interval?.start ?? calendar.startOfDay(for: referenceDate)
        // `dateInterval` end is exclusive; expose an inclusive last-instant end.
        let weekEnd = interval?.end ?? calendar.date(byAdding: .day, value: 7, to: weekStart) ?? referenceDate

        // Build the eligible days of the week: not excluded and within the
        // policy's effective window.
        let weekDays: [Date] = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
        let eligibleDays: [Date] = weekDays.filter { date in
            guard let weekday = PolicyWeekday(rawValue: calendar.component(.weekday, from: date)) else { return false }
            return !policy.excludedWeekdays.contains(weekday) && policy.isEffective(on: date, calendar: calendar)
        }

        let isApplicable = !eligibleDays.isEmpty

        // Map completed in-office dates onto eligible days (by calendar day).
        let eligibleStarts = Set(eligibleDays.map { calendar.startOfDay(for: $0) })
        let completedStarts = Set(inOfficeDates.map { calendar.startOfDay(for: $0) })
            .intersection(eligibleStarts)
        let officeDaysCompleted = completedStarts.count
        let completedWeekdays: Set<PolicyWeekday> = Set(completedStarts.compactMap {
            PolicyWeekday(rawValue: calendar.component(.weekday, from: $0))
        })

        // Requirement checks.
        let minSatisfied = officeDaysCompleted >= policy.weeklyMinimumDays
        let requiredSatisfied = policy.requiredWeekdays.allSatisfy { completedWeekdays.contains($0) }
        let anchorSatisfied = policy.anchorDayGroups.allSatisfy { group in
            group.contains { completedWeekdays.contains($0) }
        }

        // Remaining achievable days: eligible, not yet attended, today or later.
        let evalDayStart = calendar.startOfDay(for: evalDate)
        let remainingDays: [Date] = eligibleDays
            .filter { calendar.startOfDay(for: $0) >= evalDayStart && !completedStarts.contains(calendar.startOfDay(for: $0)) }
            .sorted()
        let remainingWeekdaysOrdered: [PolicyWeekday] = remainingDays.compactMap {
            PolicyWeekday(rawValue: calendar.component(.weekday, from: $0))
        }

        // Feasibility: can the week still be completed from here?
        let maxAchievable = officeDaysCompleted + remainingDays.count
        let minFeasible = maxAchievable >= policy.weeklyMinimumDays
        let anchorFeasible = policy.anchorDayGroups.allSatisfy { group in
            group.contains { completedWeekdays.contains($0) } ||
            group.contains { remainingWeekdaysOrdered.contains($0) }
        }
        let requiredFeasible = policy.requiredWeekdays.allSatisfy { weekday in
            completedWeekdays.contains(weekday) || remainingWeekdaysOrdered.contains(weekday)
        }
        let feasible = minFeasible && anchorFeasible && requiredFeasible

        // Resolve status.
        let status: WeeklyComplianceStatus = {
            guard isApplicable else { return .notApplicable }
            if minSatisfied && requiredSatisfied && anchorSatisfied { return .complete }
            guard feasible else { return .missed }
            if !anchorSatisfied { return .needsAnchorDay }
            if !requiredSatisfied { return .needsOfficeDays }
            // Only the minimum remains unmet.
            let needed = policy.weeklyMinimumDays - officeDaysCompleted
            let slack = remainingDays.count - needed
            return slack > 0 ? .onTrack : .needsOfficeDays
        }()

        // Build guidance message + suggested next weekday.
        let (message, suggested) = guidance(
            for: status,
            policy: policy,
            completedWeekdays: completedWeekdays,
            remainingWeekdaysOrdered: remainingWeekdaysOrdered,
            officeDaysCompleted: officeDaysCompleted,
            calendar: calendar
        )

        return WeeklyComplianceResult(
            weekStart: weekStart,
            weekEnd: weekEnd,
            isApplicable: isApplicable,
            officeDaysCompleted: officeDaysCompleted,
            requiredDays: policy.weeklyMinimumDays,
            weeklyMinimumSatisfied: minSatisfied,
            requiredWeekdaysSatisfied: requiredSatisfied,
            anchorDaysSatisfied: anchorSatisfied,
            status: status,
            guidanceMessage: message,
            suggestedWeekday: suggested
        )
    }

    // MARK: - Guidance

    private static func guidance(
        for status: WeeklyComplianceStatus,
        policy: WeeklyPolicy,
        completedWeekdays: Set<PolicyWeekday>,
        remainingWeekdaysOrdered: [PolicyWeekday],
        officeDaysCompleted: Int,
        calendar: Calendar
    ) -> (message: String, suggested: PolicyWeekday?) {

        /// First remaining eligible weekday, optionally limited to a candidate set.
        func firstRemaining(in candidates: [PolicyWeekday]? = nil) -> PolicyWeekday? {
            for weekday in remainingWeekdaysOrdered {
                if let candidates {
                    if candidates.contains(weekday) { return weekday }
                } else {
                    return weekday
                }
            }
            return nil
        }

        switch status {
        case .complete:
            return ("This week is complete.", nil)

        case .notApplicable:
            if let start = policy.effectiveStartDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                return ("Weekly tracking begins \(formatter.string(from: start)).", nil)
            }
            return ("Weekly tracking isn't in effect this week.", nil)

        case .missed:
            return ("This week's office-day goal can no longer be met.", nil)

        case .needsAnchorDay:
            // Find the first unsatisfied anchor group and suggest the soonest
            // remaining eligible day within it (e.g. Friday after Monday passes).
            let unsatisfied = policy.anchorDayGroups.first { group in
                !group.contains { completedWeekdays.contains($0) }
            } ?? policy.anchorDayGroups.first ?? []
            let names = unsatisfied.map(\.fullName).joined(separator: " or ")
            let suggested = firstRemaining(in: unsatisfied)
            return (
                "You need an office day on \(names) to meet your anchor-day requirement.",
                suggested
            )

        case .needsOfficeDays, .onTrack:
            // A mandatory specific weekday takes priority in the message.
            let pendingRequired = policy.requiredWeekdays.first { !completedWeekdays.contains($0) }
            if let pendingRequired {
                return (
                    "You have a required office day on \(pendingRequired.fullName).",
                    pendingRequired
                )
            }
            let needed = max(0, policy.weeklyMinimumDays - officeDaysCompleted)
            let dayWord = needed == 1 ? "day" : "days"
            let suggested = firstRemaining()
            return (
                "You need \(needed) more office \(dayWord) this week.",
                suggested
            )
        }
    }
}
