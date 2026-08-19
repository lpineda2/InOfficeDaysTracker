//
//  PTOHolidayAdjustmentTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for reducing the weekly in-office requirement when PTO, sick days,
//  or company holidays fall within the week.
//

import XCTest
import CoreLocation
@testable import InOfficeDaysTracker

final class PTOHolidayAdjustmentTests: XCTestCase {

    // MARK: - Fixtures

    /// Fixed calendar so week boundaries are deterministic.
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return cal
    }()

    /// The week of Sept 7-11, 2026 (Mon-Fri), matching WeeklyPolicyTests.
    private func day(_ d: Int, month: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: d))!
    }

    private var monday: Date { day(7) }
    private var tuesday: Date { day(8) }
    private var wednesday: Date { day(9) }
    private var thursday: Date { day(10) }
    private var friday: Date { day(11) }

    /// 3 days/week, anchor Monday-or-Friday, honoring time away with no
    /// allowance (every unavailable day reduces the requirement).
    private func adjustingPolicy(allowance: Int = 0) -> WeeklyPolicy {
        WeeklyPolicy(
            weeklyMinimumDays: 3,
            anchorDayGroups: [[.monday, .friday]],
            honorsHolidaysAndPTO: true,
            unavailabilityAllowance: allowance
        )
    }

    private func evaluate(
        _ policy: WeeklyPolicy,
        inOffice: [Date],
        unavailable: [Date] = [],
        reference: Date,
        evaluationDate: Date? = nil
    ) -> WeeklyComplianceResult {
        WeeklyComplianceEvaluator.evaluate(
            policy: policy,
            weekContaining: reference,
            inOfficeDates: inOffice,
            evaluationDate: evaluationDate ?? reference,
            unavailableDates: unavailable,
            calendar: calendar
        )
    }

    // MARK: - Adjustment arithmetic (WeeklyPolicy)

    func testNoAdjustmentWhenFeatureDisabled() {
        var policy = adjustingPolicy()
        policy.honorsHolidaysAndPTO = false

        // Even a full week away leaves the requirement untouched.
        XCTAssertEqual(policy.adjustedWeeklyMinimum(unavailableDayCount: 5), 3)
    }

    func testEachUnavailableDayReducesRequirementWithNoAllowance() {
        let policy = adjustingPolicy(allowance: 0)
        XCTAssertEqual(policy.adjustedWeeklyMinimum(unavailableDayCount: 0), 3)
        XCTAssertEqual(policy.adjustedWeeklyMinimum(unavailableDayCount: 1), 2)
        XCTAssertEqual(policy.adjustedWeeklyMinimum(unavailableDayCount: 2), 1)
        XCTAssertEqual(policy.adjustedWeeklyMinimum(unavailableDayCount: 3), 0)
    }

    func testAllowanceAbsorbsFirstDaysBeforeReducing() {
        let policy = adjustingPolicy(allowance: 2)
        XCTAssertEqual(policy.adjustedWeeklyMinimum(unavailableDayCount: 1), 3, "Within allowance")
        XCTAssertEqual(policy.adjustedWeeklyMinimum(unavailableDayCount: 2), 3, "Still within allowance")
        XCTAssertEqual(policy.adjustedWeeklyMinimum(unavailableDayCount: 3), 2)
        XCTAssertEqual(policy.adjustedWeeklyMinimum(unavailableDayCount: 4), 1)
        XCTAssertEqual(policy.adjustedWeeklyMinimum(unavailableDayCount: 5), 0)
    }

    func testRequirementNeverGoesNegative() {
        let policy = adjustingPolicy(allowance: 0)
        XCTAssertEqual(policy.adjustedWeeklyMinimum(unavailableDayCount: 10), 0)
    }

    func testNegativeAllowanceIsClampedToZero() {
        let policy = WeeklyPolicy(honorsHolidaysAndPTO: true, unavailabilityAllowance: -5)
        XCTAssertEqual(policy.unavailabilityAllowance, 0)
    }

    // MARK: - Evaluator integration

    func testRequiredDaysReflectsTimeAway() {
        // Two days of PTO, none attended yet, evaluated at the week's start.
        let result = evaluate(
            adjustingPolicy(),
            inOffice: [],
            unavailable: [tuesday, wednesday],
            reference: monday
        )
        XCTAssertEqual(result.requiredDays, 1, "3 minus 2 days away")
    }

    func testWeekIsCompleteWhenAdjustedRequirementIsMet() {
        // Away Tue-Wed (2 days), so 3 - 2 = 1 office day required;
        // Monday attended, which also satisfies the anchor rule.
        let result = evaluate(
            adjustingPolicy(),
            inOffice: [monday],
            unavailable: [tuesday, wednesday],
            reference: monday
        )
        XCTAssertEqual(result.requiredDays, 1)
        XCTAssertTrue(result.weeklyMinimumSatisfied)
        XCTAssertEqual(result.status, .complete)
    }

    func testFullWeekAwayRequiresNoOfficeDays() {
        let result = evaluate(
            adjustingPolicy(),
            inOffice: [],
            unavailable: [monday, tuesday, wednesday, thursday, friday],
            reference: monday
        )
        XCTAssertEqual(result.requiredDays, 0)
        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(result.guidanceMessage, "No office days required this week.",
                       "Shouldn't imply the user earned a completed week")
    }

    func testAnchorRequirementIsWaivedWhenRequirementDropsToZero() {
        // Away all week: no anchor day is attendable, so the anchor rule must
        // not drag the week to `.missed`. Without the waiver this reports
        // "0 days required" and "missed" simultaneously.
        var policy = adjustingPolicy()
        policy.requiredWeekdays = [.wednesday] // also waived

        let result = evaluate(
            policy,
            inOffice: [],
            unavailable: [monday, tuesday, wednesday, thursday, friday],
            reference: monday
        )
        XCTAssertEqual(result.requiredDays, 0)
        XCTAssertTrue(result.anchorDaysSatisfied)
        XCTAssertTrue(result.requiredWeekdaysSatisfied)
        XCTAssertNotEqual(result.status, .missed)
    }

    func testAnchorRequirementStillAppliesWhenRequirementIsAboveZero() {
        // Away Tue-Wed leaves a requirement of 1 and Mon/Fri both attendable,
        // so the anchor rule is NOT waived.
        let result = evaluate(
            adjustingPolicy(),
            inOffice: [thursday],
            unavailable: [tuesday, wednesday],
            reference: monday,
            evaluationDate: thursday
        )
        XCTAssertEqual(result.requiredDays, 1)
        XCTAssertFalse(result.anchorDaysSatisfied,
                       "Thursday isn't an anchor day and Friday is still available")
    }

    func testUnavailableDaysAreNotSuggestedAsOfficeDays() {
        // Away Wed-Fri; the only day left to attend is Tuesday.
        let result = evaluate(
            adjustingPolicy(),
            inOffice: [],
            unavailable: [wednesday, thursday, friday],
            reference: monday,
            evaluationDate: tuesday
        )
        XCTAssertNotEqual(result.suggestedWeekday, .wednesday)
        XCTAssertNotEqual(result.suggestedWeekday, .thursday)
        XCTAssertNotEqual(result.suggestedWeekday, .friday)
    }

    func testAttendingOnADayBookedAsPTOStillCounts() {
        // Came in on Tuesday despite having booked it as PTO. The day should
        // count as attended rather than reducing the requirement.
        let result = evaluate(
            adjustingPolicy(),
            inOffice: [tuesday],
            unavailable: [tuesday],
            reference: monday
        )
        XCTAssertEqual(result.officeDaysCompleted, 1)
        XCTAssertEqual(result.requiredDays, 3, "The attended day shouldn't also count as away")
    }

    func testUnavailableDatesIgnoredWhenPolicyDoesNotHonorThem() {
        var policy = adjustingPolicy()
        policy.honorsHolidaysAndPTO = false

        let result = evaluate(
            policy,
            inOffice: [],
            unavailable: [tuesday, wednesday, thursday],
            reference: monday
        )
        XCTAssertEqual(result.requiredDays, 3, "Existing behavior preserved when the feature is off")
    }

    func testWeekendUnavailableDaysDoNotReduceRequirement() {
        // Saturday is excluded from the policy, so PTO there is irrelevant.
        let saturday = day(12)
        let result = evaluate(
            adjustingPolicy(),
            inOffice: [],
            unavailable: [saturday],
            reference: monday
        )
        XCTAssertEqual(result.requiredDays, 3)
    }

    func testDuplicateUnavailableDatesCountOnce() {
        // Same day passed twice (e.g. PTO booked on a company holiday).
        let result = evaluate(
            adjustingPolicy(),
            inOffice: [],
            unavailable: [tuesday, tuesday],
            reference: monday
        )
        XCTAssertEqual(result.requiredDays, 2, "A day away should count once, not twice")
    }

    // MARK: - Week-scoped queries (AppData)

    @MainActor
    private func makeAppData() -> AppData {
        let suiteName = "test.ptoadjust.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppData(sharedUserDefaults: defaults)
    }

    @MainActor
    func testPTOQueryFindsDaysAcrossAMonthBoundary() {
        let appData = makeAppData()

        // Week of Mon Aug 31 - Fri Sep 4, 2026: PTO on both sides of the boundary.
        let aug31 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        let sep2 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 2))!

        var settings = appData.settings
        settings.ptoSickDays = [
            "2026-08": [aug31],
            "2026-09": [sep2]
        ]
        appData.updateSettings(settings)

        let found = appData.getPTODays(inWeekOf: sep2, calendar: calendar)
        XCTAssertEqual(found.count, 2,
                       "A week spanning two months must read both month buckets")
    }

    @MainActor
    func testPTOQueryExcludesDaysOutsideTheWeek() {
        let appData = makeAppData()

        var settings = appData.settings
        settings.ptoSickDays = ["2026-09": [tuesday, day(21)]] // second is two weeks later
        appData.updateSettings(settings)

        let found = appData.getPTODays(inWeekOf: monday, calendar: calendar)
        XCTAssertEqual(found.count, 1)
    }

    // MARK: - Persistence
    //
    // WeeklyPolicy has a hand-written init(from:), so a missed decodeIfPresent
    // would silently reset these settings on every launch rather than failing
    // loudly. Round-trip them explicitly.

    func testNewPolicyFieldsSurviveCodableRoundTrip() throws {
        var policy = WeeklyPolicy(
            weeklyMinimumDays: 3,
            anchorDayGroups: [[.monday, .friday]],
            honorsHolidaysAndPTO: true,
            unavailabilityAllowance: 2
        )
        policy.waivesAnchorDaysOnHolidayWeeks = true

        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(WeeklyPolicy.self, from: data)

        XCTAssertEqual(decoded.honorsHolidaysAndPTO, true)
        XCTAssertEqual(decoded.unavailabilityAllowance, 2)
        XCTAssertEqual(decoded.waivesAnchorDaysOnHolidayWeeks, true)
        XCTAssertEqual(decoded, policy)
    }

    func testPolicyDecodedFromOlderPayloadUsesSafeDefaults() throws {
        // A payload written before these fields existed must decode with the
        // feature off, not crash or enable it.
        let legacy = """
        {"weeklyMinimumDays":3,"requiredWeekdays":[],"anchorDayGroups":[[2,6]],"excludedWeekdays":[7,1]}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WeeklyPolicy.self, from: legacy)

        XCTAssertFalse(decoded.honorsHolidaysAndPTO)
        XCTAssertEqual(decoded.unavailabilityAllowance, 0)
        XCTAssertFalse(decoded.waivesAnchorDaysOnHolidayWeeks)
        XCTAssertEqual(decoded.weeklyMinimumDays, 3, "Existing fields still decode")
    }

    func testNegativeAllowanceIsClampedOnDecode() throws {
        let payload = """
        {"weeklyMinimumDays":3,"honorsHolidaysAndPTO":true,"unavailabilityAllowance":-3}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WeeklyPolicy.self, from: payload)
        XCTAssertEqual(decoded.unavailabilityAllowance, 0,
                       "A negative allowance would otherwise inflate the requirement")
    }

    // MARK: - Year-boundary weeks

    @MainActor
    func testPTOQueryFindsDaysAcrossAYearBoundary() {
        let appData = makeAppData()

        // Week containing Wed Dec 30, 2026 spans Dec 2026 and Jan 2027.
        let dec30 = calendar.date(from: DateComponents(year: 2026, month: 12, day: 30))!
        let jan1 = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!

        var settings = appData.settings
        settings.ptoSickDays = [
            "2026-12": [dec30],
            "2027-01": [jan1]
        ]
        appData.updateSettings(settings)

        let found = appData.getPTODays(inWeekOf: dec30, calendar: calendar)
        XCTAssertEqual(found.count, 2,
                       "A week spanning a year boundary must read both month buckets")
    }

    @MainActor
    func testHolidayQueryFindsDaysAcrossAYearBoundary() {
        let appData = makeAppData()

        // Holidays are fetched per-year, so a Dec/Jan week must query both.
        let dec30 = calendar.date(from: DateComponents(year: 2026, month: 12, day: 30))!
        let holidays = appData.getHolidays(inWeekOf: dec30, calendar: calendar)

        guard let week = calendar.dateInterval(of: .weekOfYear, for: dec30) else {
            return XCTFail("Could not resolve the week interval")
        }
        for holiday in holidays {
            XCTAssertTrue(holiday >= week.start && holiday < week.end,
                          "Returned holidays must fall inside the requested week")
        }

        // New Year's Day is a default holiday and lands in this week.
        let containsNewYears = holidays.contains { calendar.component(.month, from: $0) == 1 }
        XCTAssertTrue(containsNewYears,
                      "Should find January holidays for a week that crosses into the next year")
    }

    @MainActor
    func testHolidayQueryExcludesNonTrackingDays() {
        let appData = makeAppData()

        var settings = appData.settings
        settings.trackingDays = [2, 3, 4, 5, 6] // Mon-Fri
        appData.updateSettings(settings)

        let holidays = appData.getHolidays(inWeekOf: monday, calendar: calendar)
        for holiday in holidays {
            let weekday = calendar.component(.weekday, from: holiday)
            XCTAssertTrue(settings.trackingDays.contains(weekday),
                          "A holiday on a non-tracking day shouldn't reduce anything")
        }
    }

    @MainActor
    func testUnavailableDaysDeduplicatesPTOOnAHoliday() throws {
        let appData = makeAppData()

        // Book PTO on a date that is also a holiday, and confirm it counts once.
        let holidays = appData.getHolidays(inWeekOf: monday, calendar: calendar)
        guard let holiday = holidays.first else {
            throw XCTSkip("No holiday in the fixture week; nothing to deduplicate")
        }

        var settings = appData.settings
        let monthKey = "2026-09"
        settings.ptoSickDays = [monthKey: [holiday]]
        appData.updateSettings(settings)

        let unavailable = appData.getUnavailableDays(inWeekOf: monday, calendar: calendar)
        let distinct = Set(unavailable.map { calendar.startOfDay(for: $0) })
        XCTAssertEqual(unavailable.count, distinct.count, "No day should appear twice")
    }
}
