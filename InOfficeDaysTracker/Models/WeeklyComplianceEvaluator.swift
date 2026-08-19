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
struct WeeklyComplianceResult: Equatable, Codable {
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
    ///   - unavailableDates: Days the user can't be in the office (PTO, sick
    ///     days, company holidays). When the policy honors them, these reduce
    ///     the weekly requirement, excuse anchor/required days that fall on
    ///     them, and are removed from the days still achievable. Ignored when
    ///     `policy.honorsHolidaysAndPTO` is false.
    ///   - holidayDates: The subset of `unavailableDates` that are company
    ///     holidays. Only needed for `policy.waivesAnchorDaysOnHolidayWeeks`,
    ///     which drops anchor rules for the whole week when a holiday is
    ///     present. Pass holidays here *and* in `unavailableDates`.
    ///   - calendar: Calendar used for all date math.
    static func evaluate(
        policy: WeeklyPolicy,
        weekContaining referenceDate: Date,
        inOfficeDates: [Date],
        evaluationDate: Date? = nil,
        unavailableDates: [Date] = [],
        holidayDates: [Date] = [],
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

        // Days the user is unavailable (PTO, sick, holidays), limited to
        // eligible days of this week. A day already attended isn't counted as
        // unavailable — being in the office beats a PTO booking on the same day.
        let unavailableStarts: Set<Date> = policy.honorsHolidaysAndPTO
            ? Set(unavailableDates.map { calendar.startOfDay(for: $0) })
                .intersection(eligibleStarts)
                .subtracting(completedStarts)
            : []

        // The requirement for this specific week, reduced for time away.
        let requiredDays = policy.adjustedWeeklyMinimum(unavailableDayCount: unavailableStarts.count)

        // When time away reduces the requirement to zero there is nothing left
        // to satisfy — including anchor days. Without this, a week spent
        // entirely on PTO would report "0 days required" and "missed" at the
        // same time, because no anchor day was attendable.
        let requirementWaived = requiredDays == 0

        // Optional stricter rule: a holiday anywhere in the week drops anchor
        // rules entirely, not just on the holiday's own weekday.
        let holidayStarts = Set(holidayDates.map { calendar.startOfDay(for: $0) })
            .intersection(eligibleStarts)
        let anchorsWaivedByHoliday = policy.honorsHolidaysAndPTO
            && policy.waivesAnchorDaysOnHolidayWeeks
            && !holidayStarts.isEmpty

        // Weekdays the user can't attend, used to excuse anchor and required
        // days rather than failing them.
        let unavailableWeekdays: Set<PolicyWeekday> = Set(unavailableStarts.compactMap {
            PolicyWeekday(rawValue: calendar.component(.weekday, from: $0))
        })

        /// A weekday counts as excused when the user was unavailable that day,
        /// or when a holiday in the week waives anchors outright.
        func isExcused(_ weekday: PolicyWeekday) -> Bool {
            anchorsWaivedByHoliday || unavailableWeekdays.contains(weekday)
        }

        // Requirement checks.
        let minSatisfied = officeDaysCompleted >= requiredDays
        let requiredSatisfied = requirementWaived || policy.requiredWeekdays.allSatisfy {
            completedWeekdays.contains($0) || isExcused($0)
        }
        // A group is satisfied if any day in it was attended, or if every day
        // in it was excused — the user cannot attend a day they're away.
        let anchorSatisfied = requirementWaived || policy.anchorDayGroups.allSatisfy { group in
            group.contains { completedWeekdays.contains($0) } || group.allSatisfy(isExcused)
        }

        // Remaining achievable days: eligible, not yet attended, today or later,
        // and not a day the user is away — you can't be told to come in on a
        // day you're on PTO.
        let evalDayStart = calendar.startOfDay(for: evalDate)
        let remainingDays: [Date] = eligibleDays
            .filter { day in
                let start = calendar.startOfDay(for: day)
                return start >= evalDayStart
                    && !completedStarts.contains(start)
                    && !unavailableStarts.contains(start)
            }
            .sorted()
        let remainingWeekdaysOrdered: [PolicyWeekday] = remainingDays.compactMap {
            PolicyWeekday(rawValue: calendar.component(.weekday, from: $0))
        }

        // Feasibility: can the week still be completed from here?
        let maxAchievable = officeDaysCompleted + remainingDays.count
        let minFeasible = maxAchievable >= requiredDays
        // Excused days count as feasible: a week isn't "missed" because the
        // user couldn't attend an anchor day they were away for.
        let anchorFeasible = policy.anchorDayGroups.allSatisfy { group in
            group.contains { completedWeekdays.contains($0) } ||
            group.contains { remainingWeekdaysOrdered.contains($0) } ||
            group.allSatisfy(isExcused)
        }
        let requiredFeasible = policy.requiredWeekdays.allSatisfy { weekday in
            completedWeekdays.contains(weekday)
                || remainingWeekdaysOrdered.contains(weekday)
                || isExcused(weekday)
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
            let needed = requiredDays - officeDaysCompleted
            let slack = remainingDays.count - needed
            return slack > 0 ? .onTrack : .needsOfficeDays
        }()

        // Build guidance message + suggested next weekday.
        let todayWeekday = PolicyWeekday(rawValue: calendar.component(.weekday, from: evalDate))
        let (message, suggested) = guidance(
            for: status,
            policy: policy,
            completedWeekdays: completedWeekdays,
            remainingWeekdaysOrdered: remainingWeekdaysOrdered,
            officeDaysCompleted: officeDaysCompleted,
            requiredDays: requiredDays,
            todayWeekday: todayWeekday,
            isExcused: isExcused,
            calendar: calendar
        )

        return WeeklyComplianceResult(
            weekStart: weekStart,
            weekEnd: weekEnd,
            isApplicable: isApplicable,
            officeDaysCompleted: officeDaysCompleted,
            requiredDays: requiredDays,
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
        requiredDays: Int,
        todayWeekday: PolicyWeekday?,
        isExcused: (PolicyWeekday) -> Bool,
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
            // A requirement reduced to zero means time away covered the whole
            // week — saying "complete" alone would imply they earned it.
            if requiredDays == 0 && officeDaysCompleted == 0 {
                return ("No office days required this week.", nil)
            }
            return ("This week is complete.", nil)

        case .notApplicable:
            if let start = policy.effectiveStartDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                return ("Weekly tracking begins \(formatter.string(from: start)).", nil)
            }
            return ("Weekly tracking isn't in effect this week.", nil)

        case .missed:
            // If an anchor group is unsatisfied and no anchor day remains this
            // week, call that out specifically (e.g. after Friday has passed).
            // A fully excused group isn't "missed" — the user couldn't attend.
            let anchorMissed = policy.anchorDayGroups.contains { group in
                !group.contains { completedWeekdays.contains($0) } &&
                !group.contains { remainingWeekdaysOrdered.contains($0) } &&
                !group.allSatisfy(isExcused)
            }
            if anchorMissed {
                return ("This week's anchor-day requirement was missed.", nil)
            }
            return ("This week's office-day goal can no longer be met.", nil)

        case .needsAnchorDay:
            // First unsatisfied anchor group, and the anchor days within it that
            // are still achievable (today or later), in date order. Skip groups
            // that are fully excused — those aren't asking anything of the user.
            let unsatisfied = policy.anchorDayGroups.first { group in
                !group.contains { completedWeekdays.contains($0) } && !group.allSatisfy(isExcused)
            } ?? policy.anchorDayGroups.first ?? []
            let remainingAnchorDays = remainingWeekdaysOrdered.filter { unsatisfied.contains($0) }
            let suggested = remainingAnchorDays.first

            if remainingAnchorDays.count >= 2 {
                // More than one anchor day still ahead (e.g. before Monday).
                let names = remainingAnchorDays.map(\.fullName).joined(separator: " or ")
                return ("You need an office day on \(names) to meet your anchor-day requirement.", suggested)
            } else if let only = remainingAnchorDays.first {
                // Exactly one anchor day left (e.g. Friday after Monday passed).
                if only == todayWeekday {
                    return ("Today (\(only.fullName)) must be an office day to meet your anchor-day requirement.", suggested)
                }
                return ("You need an office day on \(only.fullName) to meet your anchor-day requirement.", suggested)
            } else {
                // No anchor day remains — defensive; feasibility routes this to
                // .missed. Never name a day the user is away for.
                let attendable = unsatisfied.filter { !isExcused($0) }
                let names = (attendable.isEmpty ? unsatisfied : attendable)
                    .map(\.fullName)
                    .joined(separator: " or ")
                return ("You need an office day on \(names) to meet your anchor-day requirement.", nil)
            }

        case .needsOfficeDays, .onTrack:
            // A mandatory specific weekday takes priority in the message —
            // unless it's a day the user is away, which is already excused.
            let pendingRequired = policy.requiredWeekdays.first {
                !completedWeekdays.contains($0) && !isExcused($0)
            }
            if let pendingRequired {
                return (
                    "You have a required office day on \(pendingRequired.fullName).",
                    pendingRequired
                )
            }
            let needed = max(0, requiredDays - officeDaysCompleted)
            let dayWord = needed == 1 ? "day" : "days"
            let suggested = firstRemaining()
            return (
                "You need \(needed) more office \(dayWord) this week.",
                suggested
            )
        }
    }
}
