//
//  AnchorDayExcusalTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for excusing anchor days and required weekdays that fall on PTO,
//  sick days, or company holidays.
//

import XCTest
@testable import InOfficeDaysTracker

final class AnchorDayExcusalTests: XCTestCase {

    // MARK: - Fixtures

    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return cal
    }()

    /// Week of Sept 7-11, 2026 (Mon-Fri).
    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: d))!
    }

    private var monday: Date { day(7) }
    private var tuesday: Date { day(8) }
    private var wednesday: Date { day(9) }
    private var thursday: Date { day(10) }
    private var friday: Date { day(11) }

    /// 3 days/week, anchor Monday-or-Friday, honoring time away. A generous
    /// allowance keeps the weekly minimum at 3 so these tests isolate anchor
    /// behavior from the requirement reduction covered elsewhere.
    private func anchorPolicy(
        waivesOnHolidayWeeks: Bool = false,
        honors: Bool = true
    ) -> WeeklyPolicy {
        WeeklyPolicy(
            weeklyMinimumDays: 3,
            anchorDayGroups: [[.monday, .friday]],
            honorsHolidaysAndPTO: honors,
            unavailabilityAllowance: 5,
            waivesAnchorDaysOnHolidayWeeks: waivesOnHolidayWeeks
        )
    }

    private func evaluate(
        _ policy: WeeklyPolicy,
        inOffice: [Date],
        unavailable: [Date] = [],
        holidays: [Date] = [],
        reference: Date,
        evaluationDate: Date? = nil
    ) -> WeeklyComplianceResult {
        WeeklyComplianceEvaluator.evaluate(
            policy: policy,
            weekContaining: reference,
            inOfficeDates: inOffice,
            evaluationDate: evaluationDate ?? reference,
            unavailableDates: unavailable,
            holidayDates: holidays,
            calendar: calendar
        )
    }

    // MARK: - Case 1: some anchor days excused, others available

    func testAnchorNarrowsToRemainingDayWhenOneIsExcused() {
        // PTO Monday. Friday is still attendable, so the anchor rule stands
        // and should point at Friday only.
        let result = evaluate(
            anchorPolicy(),
            inOffice: [tuesday, wednesday, thursday],
            unavailable: [monday],
            reference: monday,
            evaluationDate: thursday
        )

        XCTAssertFalse(result.anchorDaysSatisfied, "Friday remains attendable, so the rule still applies")
        XCTAssertEqual(result.status, .needsAnchorDay)
        XCTAssertEqual(result.suggestedWeekday, .friday)
        XCTAssertTrue(result.guidanceMessage.contains("Friday"))
        XCTAssertFalse(result.guidanceMessage.contains("Monday"),
                       "Never suggest a day the user is away for")
    }

    func testAttendingTheAvailableAnchorDaySatisfiesTheGroup() {
        // PTO Monday, attended Friday.
        let result = evaluate(
            anchorPolicy(),
            inOffice: [wednesday, thursday, friday],
            unavailable: [monday],
            reference: monday,
            evaluationDate: friday
        )
        XCTAssertTrue(result.anchorDaysSatisfied)
        XCTAssertEqual(result.status, .complete)
    }

    // MARK: - Case 2: all anchor days excused

    func testAnchorGroupIsSatisfiedWhenEveryAnchorDayIsExcused() {
        // PTO both Monday and Friday; attended Tue/Wed/Thu.
        let result = evaluate(
            anchorPolicy(),
            inOffice: [tuesday, wednesday, thursday],
            unavailable: [monday, friday],
            reference: monday,
            evaluationDate: friday
        )

        XCTAssertTrue(result.anchorDaysSatisfied,
                      "The user couldn't attend any anchor day, so the group is excused")
        XCTAssertEqual(result.status, .complete)
    }

    func testFullyExcusedAnchorDoesNotMarkTheWeekMissed() {
        // Away both anchor days, evaluated after both have passed. Previously
        // anchorFeasible would be false and the week would report .missed.
        let result = evaluate(
            anchorPolicy(),
            inOffice: [tuesday, wednesday, thursday],
            unavailable: [monday, friday],
            reference: monday,
            evaluationDate: friday
        )
        XCTAssertNotEqual(result.status, .missed)
        XCTAssertFalse(result.guidanceMessage.contains("anchor-day requirement was missed"))
    }

    // MARK: - Case 3: holiday-week waiver

    func testHolidayWeekWaivesAnchorWhenConfigured() {
        // Holiday on Wednesday — not an anchor day — but the policy waives
        // anchors for any week containing a holiday.
        let result = evaluate(
            anchorPolicy(waivesOnHolidayWeeks: true),
            inOffice: [tuesday, thursday],
            unavailable: [wednesday],
            holidays: [wednesday],
            reference: monday,
            evaluationDate: friday
        )
        XCTAssertTrue(result.anchorDaysSatisfied,
                      "A midweek holiday waives the anchor rule under this setting")
    }

    func testHolidayWeekDoesNotWaiveAnchorByDefault() {
        // Same scenario with the setting off: Monday/Friday were attendable
        // and unattended, so the anchor rule still applies.
        let result = evaluate(
            anchorPolicy(waivesOnHolidayWeeks: false),
            inOffice: [tuesday, thursday],
            unavailable: [wednesday],
            holidays: [wednesday],
            reference: monday,
            evaluationDate: friday
        )
        XCTAssertFalse(result.anchorDaysSatisfied)
    }

    func testHolidayWaiverRequiresAnActualHolidayInTheWeek() {
        // Setting on, but the time away is PTO rather than a holiday.
        let result = evaluate(
            anchorPolicy(waivesOnHolidayWeeks: true),
            inOffice: [tuesday, thursday],
            unavailable: [wednesday],
            holidays: [],
            reference: monday,
            evaluationDate: friday
        )
        XCTAssertFalse(result.anchorDaysSatisfied,
                       "PTO alone shouldn't trigger the holiday-week waiver")
    }

    // MARK: - Required weekdays

    func testRequiredWeekdayIsExcusedWhenUnavailable() {
        var policy = anchorPolicy()
        policy.requiredWeekdays = [.wednesday]

        // Away Wednesday; attended Monday (anchor) plus two others.
        let result = evaluate(
            policy,
            inOffice: [monday, tuesday, thursday],
            unavailable: [wednesday],
            reference: monday,
            evaluationDate: friday
        )
        XCTAssertTrue(result.requiredWeekdaysSatisfied,
                      "A required day the user was away for shouldn't fail the week")
        XCTAssertEqual(result.status, .complete)
    }

    func testGuidanceDoesNotDemandAnExcusedRequiredWeekday() {
        var policy = anchorPolicy()
        policy.requiredWeekdays = [.wednesday]

        // Away Wednesday, anchor met, but still short of the 3-day minimum.
        let result = evaluate(
            policy,
            inOffice: [monday],
            unavailable: [wednesday],
            reference: monday,
            evaluationDate: tuesday
        )
        XCTAssertFalse(result.guidanceMessage.contains("Wednesday"),
                       "Shouldn't ask for a required day the user is away for")
    }

    // MARK: - Feature disabled

    func testExcusalDoesNothingWhenPolicyDoesNotHonorTimeAway() {
        let result = evaluate(
            anchorPolicy(honors: false),
            inOffice: [tuesday, wednesday, thursday],
            unavailable: [monday, friday],
            reference: monday,
            evaluationDate: friday
        )
        XCTAssertFalse(result.anchorDaysSatisfied,
                       "Existing behavior preserved when the feature is off")
    }

    // MARK: - Regression

    func testNormalAnchorBehaviorIsUnchangedWithNoTimeAway() {
        // No PTO at all: the anchor rule behaves exactly as before.
        let unmet = evaluate(
            anchorPolicy(),
            inOffice: [tuesday, wednesday, thursday],
            reference: monday,
            evaluationDate: friday
        )
        XCTAssertFalse(unmet.anchorDaysSatisfied)

        let met = evaluate(
            anchorPolicy(),
            inOffice: [monday, tuesday, wednesday],
            reference: monday,
            evaluationDate: friday
        )
        XCTAssertTrue(met.anchorDaysSatisfied)
    }
}
