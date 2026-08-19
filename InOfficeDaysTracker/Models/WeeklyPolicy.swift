//
//  WeeklyPolicy.swift
//  InOfficeDaysTracker
//
//  General-purpose weekly hybrid in-office policy model.
//
//  This is intentionally employer-agnostic: it can express many weekly
//  hybrid policies (a minimum number of office days per week, mandatory
//  specific weekdays, "at least one of" anchor-day groups, excluded days,
//  and an effective date window). Business logic that evaluates a week
//  against a policy lives in `WeeklyComplianceEvaluator` — this file only
//  describes the policy and its configuration.
//

import Foundation

/// How attendance goals are tracked for a user.
///
/// Existing users default to `.monthly`, which preserves the original
/// month-based goal behavior. Weekly evaluation is opt-in.
enum TrackingCadence: String, Codable, CaseIterable, Identifiable {
    case monthly
    case weekly
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .both: return "Monthly & Weekly"
        }
    }

    var description: String {
        switch self {
        case .monthly: return "Track a monthly office-day goal."
        case .weekly: return "Track a weekly office-day policy."
        case .both: return "Track both a monthly goal and a weekly policy."
        }
    }

    /// Whether weekly policy evaluation should be applied.
    var includesWeekly: Bool { self == .weekly || self == .both }

    /// Whether the monthly goal should be applied.
    var includesMonthly: Bool { self == .monthly || self == .both }
}

/// A weekday using `Calendar`'s weekday numbering (1 = Sunday … 7 = Saturday).
///
/// This matches `AppSettings.trackingDays`, which already uses the same
/// numbering, so the two stay consistent.
enum PolicyWeekday: Int, Codable, CaseIterable, Identifiable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    /// Full localized-style name (e.g. "Monday").
    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    /// Short name (e.g. "Mon").
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    static func < (lhs: PolicyWeekday, rhs: PolicyWeekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The five standard work weekdays (Monday–Friday).
    static let weekdays: [PolicyWeekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]

    /// Weekend days (Saturday & Sunday).
    static let weekend: [PolicyWeekday] = [.saturday, .sunday]
}

/// A general-purpose weekly hybrid in-office policy.
///
/// Example — "at least 3 office days per week, one of which must be Monday
/// or Friday, effective September 1":
/// ```
/// WeeklyPolicy(
///     weeklyMinimumDays: 3,
///     anchorDayGroups: [[.monday, .friday]],
///     effectiveStartDate: septemberFirst
/// )
/// ```
struct WeeklyPolicy: Codable, Equatable {

    // MARK: - Effective window

    /// The first day the policy applies. `nil` means "always in effect".
    var effectiveStartDate: Date?

    /// The last day the policy applies. `nil` means "no end".
    var effectiveEndDate: Date?

    // MARK: - Weekly requirements

    /// Minimum number of in-office days required each week.
    var weeklyMinimumDays: Int

    /// Optional monthly minimum, used only when the cadence includes monthly
    /// tracking driven by this policy. The existing monthly goal engine
    /// (`CompanyPolicy`) remains the default monthly source; this is a hook
    /// for future "both" refinements and is not required for weekly tracking.
    var monthlyMinimumDays: Int?

    /// Specific weekdays that must always be in-office (e.g. every Wednesday).
    var requiredWeekdays: [PolicyWeekday]

    /// "At least one of" groups. Each group is satisfied when the user is
    /// in office on at least one weekday in that group. The classic
    /// anchor-day rule "Monday or Friday" is `[[.monday, .friday]]`.
    var anchorDayGroups: [[PolicyWeekday]]

    /// Weekdays that never count toward the policy (typically the weekend).
    var excludedWeekdays: [PolicyWeekday]

    // MARK: - PTO / holiday handling

    /// When true, the weekly minimum is reduced for PTO/sick days and company
    /// holidays falling in the week, per `unavailabilityAllowance`.
    var honorsHolidaysAndPTO: Bool

    /// Number of PTO/sick days tolerated in a week before the weekly minimum
    /// starts to drop.
    ///
    /// Employers differ here: some reduce the requirement from the first day
    /// away, others absorb a day or two before adjusting. A value of 0 means
    /// every PTO day reduces the requirement; 2 means the first two are
    /// absorbed and the third begins reducing it.
    ///
    /// Only consulted when `honorsHolidaysAndPTO` is true.
    var unavailabilityAllowance: Int

    /// Number of company holidays tolerated in a week before the weekly
    /// minimum starts to drop.
    ///
    /// Tracked separately from `unavailabilityAllowance` because policies
    /// commonly treat the two differently — absorbing a couple of PTO days
    /// while reducing the goal on the very first holiday. Pooling them made
    /// such a policy impossible to express: an allowance high enough for PTO
    /// left holiday weeks unreduced, and one low enough for holidays wrongly
    /// reduced the goal on a single PTO day.
    ///
    /// Defaults to 0, so each holiday reduces the requirement immediately.
    /// Only consulted when `honorsHolidaysAndPTO` is true.
    var holidayAllowance: Int

    /// When true, any company holiday in the week waives anchor-day rules for
    /// that whole week, regardless of which weekday the holiday falls on.
    ///
    /// This is stricter than the day-level excusal that always applies when
    /// `honorsHolidaysAndPTO` is on (where only the specific anchor days you're
    /// away are excused). Some policies drop the anchor requirement entirely in
    /// a short week; others keep it. Off by default since it isn't universal.
    ///
    /// Only consulted when `honorsHolidaysAndPTO` is true.
    var waivesAnchorDaysOnHolidayWeeks: Bool

    // MARK: - Init

    init(
        effectiveStartDate: Date? = nil,
        effectiveEndDate: Date? = nil,
        weeklyMinimumDays: Int = 3,
        monthlyMinimumDays: Int? = nil,
        requiredWeekdays: [PolicyWeekday] = [],
        anchorDayGroups: [[PolicyWeekday]] = [[.monday, .friday]],
        excludedWeekdays: [PolicyWeekday] = PolicyWeekday.weekend,
        honorsHolidaysAndPTO: Bool = false,
        unavailabilityAllowance: Int = 0,
        holidayAllowance: Int = 0,
        waivesAnchorDaysOnHolidayWeeks: Bool = false
    ) {
        self.effectiveStartDate = effectiveStartDate
        self.effectiveEndDate = effectiveEndDate
        self.weeklyMinimumDays = weeklyMinimumDays
        self.monthlyMinimumDays = monthlyMinimumDays
        self.requiredWeekdays = requiredWeekdays
        self.anchorDayGroups = anchorDayGroups
        self.excludedWeekdays = excludedWeekdays
        self.honorsHolidaysAndPTO = honorsHolidaysAndPTO
        self.unavailabilityAllowance = max(0, unavailabilityAllowance)
        self.holidayAllowance = max(0, holidayAllowance)
        self.waivesAnchorDaysOnHolidayWeeks = waivesAnchorDaysOnHolidayWeeks
    }

    // MARK: - Codable (forward/backward compatible)

    enum CodingKeys: String, CodingKey {
        case effectiveStartDate, effectiveEndDate
        case weeklyMinimumDays, monthlyMinimumDays
        case requiredWeekdays, anchorDayGroups, excludedWeekdays
        case honorsHolidaysAndPTO, unavailabilityAllowance, holidayAllowance
        case waivesAnchorDaysOnHolidayWeeks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Every field uses decodeIfPresent so partially-written or older
        // payloads decode safely with sensible defaults.
        effectiveStartDate = try container.decodeIfPresent(Date.self, forKey: .effectiveStartDate)
        effectiveEndDate = try container.decodeIfPresent(Date.self, forKey: .effectiveEndDate)
        weeklyMinimumDays = try container.decodeIfPresent(Int.self, forKey: .weeklyMinimumDays) ?? 3
        monthlyMinimumDays = try container.decodeIfPresent(Int.self, forKey: .monthlyMinimumDays)
        requiredWeekdays = try container.decodeIfPresent([PolicyWeekday].self, forKey: .requiredWeekdays) ?? []
        anchorDayGroups = try container.decodeIfPresent([[PolicyWeekday]].self, forKey: .anchorDayGroups) ?? [[.monday, .friday]]
        excludedWeekdays = try container.decodeIfPresent([PolicyWeekday].self, forKey: .excludedWeekdays) ?? PolicyWeekday.weekend
        honorsHolidaysAndPTO = try container.decodeIfPresent(Bool.self, forKey: .honorsHolidaysAndPTO) ?? false
        unavailabilityAllowance = max(0, try container.decodeIfPresent(Int.self, forKey: .unavailabilityAllowance) ?? 0)
        holidayAllowance = max(0, try container.decodeIfPresent(Int.self, forKey: .holidayAllowance) ?? 0)
        waivesAnchorDaysOnHolidayWeeks = try container.decodeIfPresent(Bool.self, forKey: .waivesAnchorDaysOnHolidayWeeks) ?? false
    }

    // MARK: - Derived configuration

    /// All weekdays that can count toward the policy (everything not excluded).
    var eligibleWeekdays: [PolicyWeekday] {
        PolicyWeekday.allCases.filter { !excludedWeekdays.contains($0) }
    }

    /// The weekly minimum after accounting for days the user is unavailable
    /// (PTO, sick days, company holidays) in a given week.
    ///
    /// Days beyond `unavailabilityAllowance` each reduce the requirement by
    /// one, floored at zero. Returns `weeklyMinimumDays` unchanged when
    /// `honorsHolidaysAndPTO` is off, so existing users see no change.
    ///
    /// - Parameter unavailableDayCount: Distinct unavailable days in the week.
    func adjustedWeeklyMinimum(ptoDayCount: Int, holidayCount: Int = 0) -> Int {
        guard honorsHolidaysAndPTO else { return weeklyMinimumDays }

        // Each kind is measured against its own allowance, then the surpluses
        // are summed. Pooling the counts first would let a policy's PTO
        // allowance absorb holidays (or vice versa), which is exactly the case
        // a single shared allowance couldn't express.
        let reducingPTO = max(0, ptoDayCount - unavailabilityAllowance)
        let reducingHolidays = max(0, holidayCount - holidayAllowance)

        return max(0, weeklyMinimumDays - reducingPTO - reducingHolidays)
    }

    /// Whether the policy is in effect on a specific calendar day.
    func isEffective(on date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        if let start = effectiveStartDate, day < calendar.startOfDay(for: start) {
            return false
        }
        if let end = effectiveEndDate, day > calendar.startOfDay(for: end) {
            return false
        }
        return true
    }

    /// A human-readable summary of the anchor-day rule (e.g. "Monday or Friday").
    var anchorDaysDescription: String? {
        guard !anchorDayGroups.isEmpty else { return nil }
        return anchorDayGroups
            .map { group in group.map(\.fullName).joined(separator: " or ") }
            .joined(separator: ", and ")
    }
}
