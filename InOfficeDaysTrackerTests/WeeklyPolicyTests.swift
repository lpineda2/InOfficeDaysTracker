//
//  WeeklyPolicyTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for the general-purpose weekly hybrid policy engine (v1.10.0).
//

import XCTest
import CoreLocation
@testable import InOfficeDaysTracker

final class WeeklyPolicyTests: XCTestCase {

    // MARK: - Fixtures

    /// Gregorian calendar with a fixed first weekday so week math is deterministic.
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return cal
    }()

    /// The week of Sept 7–11, 2026 (Mon–Fri).
    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: d))!
    }

    private var monday: Date { day(7) }
    private var tuesday: Date { day(8) }
    private var wednesday: Date { day(9) }
    private var thursday: Date { day(10) }
    private var friday: Date { day(11) }
    private var saturday: Date { day(12) }

    /// Standard target policy: 3 days/week, anchor Monday-or-Friday.
    private func standardPolicy(effectiveStart: Date? = nil) -> WeeklyPolicy {
        WeeklyPolicy(
            effectiveStartDate: effectiveStart,
            weeklyMinimumDays: 3,
            anchorDayGroups: [[.monday, .friday]]
        )
    }

    // MARK: - Test Setup Helper

    /// Creates a clean AppData instance for testing with isolated UserDefaults
    @MainActor
    func createTestAppData() -> AppData {
        let testSuiteName = "test.weeklypolicy.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removePersistentDomain(forName: testSuiteName)

        return AppData(sharedUserDefaults: testDefaults)
    }

    private func evaluate(
        _ policy: WeeklyPolicy,
        inOffice: [Date],
        reference: Date,
        evaluationDate: Date? = nil
    ) -> WeeklyComplianceResult {
        WeeklyComplianceEvaluator.evaluate(
            policy: policy,
            weekContaining: reference,
            inOfficeDates: inOffice,
            evaluationDate: evaluationDate ?? reference,
            calendar: calendar
        )
    }

    // MARK: - Weekly minimum

    func testWeeklyMinimumSatisfiedWith3OfficeDays() {
        let result = evaluate(
            standardPolicy(),
            inOffice: [monday, tuesday, wednesday],
            reference: wednesday
        )
        XCTAssertEqual(result.officeDaysCompleted, 3)
        XCTAssertTrue(result.weeklyMinimumSatisfied)
        XCTAssertTrue(result.anchorDaysSatisfied)
        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(result.guidanceMessage, "This week is complete.")
    }

    func testWeeklyMinimumNotSatisfiedWith2OfficeDays() {
        let result = evaluate(
            standardPolicy(),
            inOffice: [monday, tuesday],
            reference: monday
        )
        XCTAssertEqual(result.officeDaysCompleted, 2)
        XCTAssertFalse(result.weeklyMinimumSatisfied)
        XCTAssertEqual(result.daysRemainingToGoal, 1)
    }

    // MARK: - Anchor day rule

    func testAnchorSatisfiedWithMonday() {
        let result = evaluate(
            standardPolicy(),
            inOffice: [monday, tuesday, wednesday],
            reference: wednesday
        )
        XCTAssertTrue(result.anchorDaysSatisfied)
    }

    func testAnchorSatisfiedWithFriday() {
        let result = evaluate(
            standardPolicy(),
            inOffice: [wednesday, thursday, friday],
            reference: friday
        )
        XCTAssertTrue(result.anchorDaysSatisfied)
    }

    func testAnchorNotSatisfiedWithMidweekOnly() {
        // Evaluated at the start of the week so Monday/Friday are still ahead.
        let result = evaluate(
            standardPolicy(),
            inOffice: [tuesday, wednesday, thursday],
            reference: monday,
            evaluationDate: monday
        )
        XCTAssertFalse(result.anchorDaysSatisfied)
        XCTAssertTrue(result.weeklyMinimumSatisfied) // 3 days met, but anchor not
        XCTAssertEqual(result.status, .needsAnchorDay)
    }

    func testAnchorSuggestsFridayAfterMondayHasPassed() {
        // Now is Thursday: Monday has passed unattended, so Friday is the
        // only remaining anchor-eligible day.
        let result = evaluate(
            standardPolicy(),
            inOffice: [tuesday, wednesday, thursday],
            reference: thursday,
            evaluationDate: thursday
        )
        XCTAssertEqual(result.status, .needsAnchorDay)
        XCTAssertEqual(result.suggestedWeekday, .friday)
        // Day-aware: Monday has passed, so guidance names Friday specifically.
        XCTAssertEqual(result.guidanceMessage,
                       "You need an office day on Friday to meet your anchor-day requirement.")
        XCTAssertFalse(result.guidanceMessage.contains("Monday or Friday"))
    }

    // MARK: - Anchor-day guidance (day-aware)

    func testAnchorGuidanceBeforeMondayListsBothDays() {
        // Start of week, no office days yet: both anchor days are still ahead.
        let result = evaluate(
            standardPolicy(),
            inOffice: [],
            reference: monday,
            evaluationDate: monday
        )
        XCTAssertEqual(result.status, .needsAnchorDay)
        XCTAssertEqual(result.guidanceMessage,
                       "You need an office day on Monday or Friday to meet your anchor-day requirement.")
    }

    func testAnchorGuidanceOnFridaySaysTodayMustCount() {
        // It's Friday, no anchor day attended yet — today is the last chance.
        let result = evaluate(
            standardPolicy(),
            inOffice: [tuesday, wednesday, thursday],
            reference: friday,
            evaluationDate: friday
        )
        XCTAssertEqual(result.status, .needsAnchorDay)
        XCTAssertEqual(result.suggestedWeekday, .friday)
        XCTAssertEqual(result.guidanceMessage,
                       "Today (Friday) must be an office day to meet your anchor-day requirement.")
    }

    func testAnchorMissedAfterFriday() {
        // Evaluated Saturday: no anchor day was attended and none remain.
        let result = evaluate(
            standardPolicy(),
            inOffice: [tuesday, wednesday, thursday],
            reference: saturday,
            evaluationDate: saturday
        )
        XCTAssertEqual(result.status, .missed)
        XCTAssertEqual(result.guidanceMessage,
                       "This week's anchor-day requirement was missed.")
    }

    // MARK: - Effective date gating

    func testPolicyDoesNotApplyBeforeEffectiveDate() {
        // Effective Oct 1, 2026 — the Sept 7 week is entirely before it.
        let effective = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let result = evaluate(
            standardPolicy(effectiveStart: effective),
            inOffice: [monday, tuesday, wednesday],
            reference: wednesday
        )
        XCTAssertFalse(result.isApplicable)
        XCTAssertEqual(result.status, .notApplicable)
    }

    func testPolicyAppliesOnAndAfterEffectiveDate() {
        // Effective Sept 1, 2026 — the Sept 7 week is on/after it.
        let effective = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let result = evaluate(
            standardPolicy(effectiveStart: effective),
            inOffice: [monday, tuesday, wednesday],
            reference: wednesday
        )
        XCTAssertTrue(result.isApplicable)
        XCTAssertEqual(result.status, .complete)
    }

    func testPolicyAppliesExactlyOnEffectiveStartWeek() {
        // Effective on Monday of the evaluated week.
        let result = evaluate(
            standardPolicy(effectiveStart: monday),
            inOffice: [monday, friday],
            reference: monday,
            evaluationDate: monday
        )
        XCTAssertTrue(result.isApplicable)
        XCTAssertTrue(result.anchorDaysSatisfied)
    }

    // MARK: - Guidance

    func testNeedsOfficeDaysGuidanceWhenMinimumNotMetButAnchorMet() {
        // Monday attended (anchor met), but only 1 of 3 days done, late in week.
        let result = evaluate(
            standardPolicy(),
            inOffice: [monday],
            reference: thursday,
            evaluationDate: thursday
        )
        XCTAssertTrue(result.anchorDaysSatisfied)
        XCTAssertFalse(result.weeklyMinimumSatisfied)
        XCTAssertEqual(result.guidanceMessage, "You need 2 more office days this week.")
    }

    func testMissedWhenNotEnoughDaysRemain() {
        // Friday is the last day; only 1 day attended, need 3 — impossible.
        let result = evaluate(
            standardPolicy(),
            inOffice: [monday],
            reference: friday,
            evaluationDate: friday
        )
        XCTAssertEqual(result.status, .missed)
    }

    // MARK: - Required specific weekdays

    func testRequiredWeekdayMustBeAttended() {
        var policy = standardPolicy()
        policy.requiredWeekdays = [.wednesday]
        // Three days incl. Monday (anchor) but NOT Wednesday.
        let result = evaluate(
            policy,
            inOffice: [monday, tuesday, thursday],
            reference: monday,
            evaluationDate: monday
        )
        XCTAssertFalse(result.requiredWeekdaysSatisfied)
        XCTAssertEqual(result.suggestedWeekday, .wednesday)
    }

    // MARK: - Monthly behavior unchanged

    func testDefaultCadenceIsMonthlyForExistingUsers() {
        let settings = AppSettings()
        XCTAssertEqual(settings.trackingCadence, .monthly)
        XCTAssertFalse(settings.trackingCadence.includesWeekly)
        XCTAssertTrue(settings.trackingCadence.includesMonthly)
    }

    func testMonthlyGoalCalculationUnaffectedByWeeklyPolicy() {
        // The existing monthly engine (CompanyPolicy) is independent.
        var policy = CompanyPolicy()
        policy.policyType = .hybrid50
        XCTAssertEqual(policy.calculateRequiredDays(workingDays: 20), 10)
    }

    @MainActor
    func testAppDataReturnsNilWeeklyComplianceWhenMonthlyOnly() {
        let appData = createTestAppData()
        var settings = appData.settings
        settings.trackingCadence = .monthly
        appData.updateSettings(settings)
        XCTAssertNil(appData.getCurrentWeekCompliance())
    }

    // MARK: - Both mode

    func testBothModeEnablesWeeklyAndMonthlyWithoutConflict() {
        let cadence = TrackingCadence.both
        XCTAssertTrue(cadence.includesWeekly)
        XCTAssertTrue(cadence.includesMonthly)

        // Weekly evaluation still produces a valid result...
        let weekly = evaluate(
            standardPolicy(),
            inOffice: [monday, tuesday, wednesday],
            reference: wednesday
        )
        XCTAssertEqual(weekly.status, .complete)

        // ...while the monthly engine computes independently.
        var monthly = CompanyPolicy()
        monthly.policyType = .hybrid60
        XCTAssertEqual(monthly.calculateRequiredDays(workingDays: 20), 12)
    }

    @MainActor
    func testAppDataReturnsWeeklyComplianceWhenWeeklyEnabled() {
        let appData = createTestAppData()
        var settings = appData.settings
        settings.trackingCadence = .weekly
        settings.weeklyPolicy = standardPolicy()
        appData.updateSettings(settings)
        XCTAssertNotNil(appData.getCurrentWeekCompliance())
    }

    // MARK: - Codable round-trip / migration

    func testWeeklyPolicyCodableRoundTrip() throws {
        let policy = WeeklyPolicy(
            effectiveStartDate: monday,
            weeklyMinimumDays: 4,
            requiredWeekdays: [.wednesday],
            anchorDayGroups: [[.monday, .friday]]
        )
        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(WeeklyPolicy.self, from: data)
        XCTAssertEqual(policy, decoded)
    }

    /// `WeeklyComplianceResult` is encoded into the widget's shared `WidgetData`
    /// payload (App Group UserDefaults) so the widget extension can render
    /// weekly compliance without recomputing it. Guard the round-trip so a
    /// future field addition doesn't silently break widget decoding.
    func testWeeklyComplianceResultCodableRoundTrip() throws {
        let result = evaluate(
            standardPolicy(),
            inOffice: [monday, tuesday, wednesday],
            reference: wednesday
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(WeeklyComplianceResult.self, from: data)
        XCTAssertEqual(result, decoded)
    }

    // MARK: - Widget/app contract
    //
    // `WidgetDataManager.getWeeklyComplianceResult(settings:)` (OfficeTrackerWidget
    // target) independently re-derives the same "in-office dates for this week"
    // filter that `AppData.getCurrentWeekCompliance()` uses, because the widget
    // extension cannot share code across the module boundary without a
    // duplicated file (matching this project's widget duplication convention).
    // These tests pin down that exact filter contract — `isValidVisit ||
    // isActiveSession`, restricted to the current `weekOfYear` — so a drift
    // between the two copies gets caught here instead of silently in the widget.

    @MainActor
    func testWeeklyInOfficeDatesIncludeCompletedAndActiveVisitsOnly() {
        let appData = createTestAppData()
        var settings = appData.settings
        settings.trackingCadence = .weekly
        settings.weeklyPolicy = standardPolicy()
        appData.updateSettings(settings)

        let testCoord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        // A completed visit long enough to be valid (>= 1 hour).
        let completedEvent = OfficeEvent(
            entryTime: monday,
            exitTime: calendar.date(byAdding: .hour, value: 2, to: monday)
        )
        let completedVisit = OfficeVisit(date: monday, events: [completedEvent], coordinate: testCoord)

        // A too-short completed visit (< 1 hour) — must NOT count.
        let shortEvent = OfficeEvent(
            entryTime: tuesday,
            exitTime: calendar.date(byAdding: .minute, value: 10, to: tuesday)
        )
        let shortVisit = OfficeVisit(date: tuesday, events: [shortEvent], coordinate: testCoord)

        // An active (in-progress) session with no exit time yet — must count.
        let activeEvent = OfficeEvent(entryTime: wednesday, exitTime: nil)
        let activeVisit = OfficeVisit(date: wednesday, events: [activeEvent], coordinate: testCoord)

        appData.visits = [completedVisit, shortVisit, activeVisit]

        let result = appData.getCurrentWeekCompliance(asOf: wednesday)
        XCTAssertEqual(result?.officeDaysCompleted, 2, "Only the completed valid visit and the active session should count")
    }
}
