import XCTest
@testable import InOfficeDaysTracker

final class TrendChartCardTests: XCTestCase {
    func testAggregatedProducesFullMonthsAndMidpoints() {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 22
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        guard let now = calendar.date(from: comps) else {
            XCTFail("Failed to construct 'now' date")
            return
        }

        // Months expected: Oct 2025, Nov 2025, Dec 2025 (previous full 3 months)
        var data: [TrendDataPoint] = []

        // Oct 2025: two visits
        var oct1 = DateComponents()
        oct1.year = 2025
        oct1.month = 10
        oct1.day = 5
        oct1.timeZone = TimeZone(secondsFromGMT: 0)
        data.append(TrendDataPoint(date: calendar.date(from: oct1)!, value: 1))
        oct1.day = 20
        data.append(TrendDataPoint(date: calendar.date(from: oct1)!, value: 1))

        // Nov 2025: zero visits (no entries)

        // Dec 2025: one visit
        var dec = DateComponents()
        dec.year = 2025
        dec.month = 12
        dec.day = 10
        dec.timeZone = TimeZone(secondsFromGMT: 0)
        data.append(TrendDataPoint(date: calendar.date(from: dec)!, value: 1))

        let aggregated = TrendChartCard.aggregated(from: data, months: 3, now: now, calendar: calendar)

        XCTAssertEqual(aggregated.count, 3, "Should produce 3 month buckets")

        // Values should be [2, 0, 1]
        let values = aggregated.map { $0.value }
        XCTAssertEqual(values, [2, 0, 1])

        // Dates should be mid-month for Oct/Nov/Dec
        let monthComponents = aggregated.map { calendar.dateComponents([.year, .month, .day], from: $0.date) }
        XCTAssertEqual(monthComponents[0].month, 10)
        XCTAssertEqual(monthComponents[1].month, 11)
        XCTAssertEqual(monthComponents[2].month, 12)

        // Check day ~= midpoint (for Oct: 31 days -> midOffset 15 -> day 16)
        XCTAssertEqual(monthComponents[0].day, 16)
        XCTAssertEqual(monthComponents[1].day, 16)
        XCTAssertEqual(monthComponents[2].day, 16)
    }

    // MARK: - Weekly aggregation

    /// Gregorian calendar with a fixed first weekday and timezone so week
    /// boundaries are deterministic (mirrors WeeklyPolicyTests' fixture style).
    private var weeklyCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    /// A date in the fixed test window: Wednesday, Sept 9, 2026.
    private func testDate(year: Int = 2026, month: Int = 9, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        return weeklyCalendar.date(from: comps)!
    }

    func testAggregatedByWeekProducesContiguousZeroFilledBuckets() {
        let now = testDate(day: 9) // Wednesday
        // Only one visit, three weeks before the current week.
        let data = [TrendDataPoint(date: testDate(month: 8, day: 19), value: 1)]

        let aggregated = TrendChartCard.aggregatedByWeek(
            from: data, weeks: 4, now: now, calendar: weeklyCalendar
        )

        let total = aggregated.reduce(0) { $0 + $1.value }
        XCTAssertEqual(aggregated.count, 4, "Should produce one bucket per week in the range")
        XCTAssertEqual(total, 1, "Only the single visit should be counted")
        // Weeks with no visits must still be present as zeros.
        XCTAssertEqual(aggregated.filter { $0.value == 0 }.count, 3)
    }

    func testAggregatedByWeekIncludesCurrentPartialWeek() {
        let now = testDate(day: 9) // Wednesday of the current week
        // A visit earlier in the same (still incomplete) week: Monday Sept 7.
        let data = [TrendDataPoint(date: testDate(day: 7), value: 1)]

        let aggregated = TrendChartCard.aggregatedByWeek(
            from: data, weeks: 4, now: now, calendar: weeklyCalendar
        )

        // Deliberate divergence from the monthly aggregator, which excludes the
        // current month: the in-progress week is the one weekly trackers care about.
        XCTAssertEqual(aggregated.last?.value, 1, "Current partial week must be included")
    }

    func testAggregatedByWeekUsesSameWeekBoundaryAsComplianceEvaluator() {
        let now = testDate(day: 9)
        // Sunday Sept 6 starts the week under firstWeekday = 1; Saturday Sept 5
        // belongs to the previous week.
        let data = [
            TrendDataPoint(date: testDate(day: 6), value: 1), // current week
            TrendDataPoint(date: testDate(day: 5), value: 1)  // previous week
        ]

        let aggregated = TrendChartCard.aggregatedByWeek(
            from: data, weeks: 2, now: now, calendar: weeklyCalendar
        )

        XCTAssertEqual(aggregated.count, 2)
        XCTAssertEqual(aggregated[0].value, 1, "Sept 5 belongs to the previous week")
        XCTAssertEqual(aggregated[1].value, 1, "Sept 6 starts the current week")

        // The split must match what WeeklyComplianceEvaluator would use, or the
        // chart and the compliance card would disagree about week boundaries.
        let evaluatorWeekStart = weeklyCalendar.dateInterval(of: .weekOfYear, for: now)?.start
        let lastBucketWeekStart = weeklyCalendar.dateInterval(
            of: .weekOfYear, for: aggregated[1].date
        )?.start
        XCTAssertEqual(lastBucketWeekStart, evaluatorWeekStart)
    }

    func testAggregatedByWeekExcludesDataOutsideWindow() {
        let now = testDate(day: 9)
        let data = [
            TrendDataPoint(date: testDate(day: 9), value: 1),          // in range
            TrendDataPoint(date: testDate(month: 6, day: 1), value: 5) // far outside
        ]

        let aggregated = TrendChartCard.aggregatedByWeek(
            from: data, weeks: 2, now: now, calendar: weeklyCalendar
        )

        let total = aggregated.reduce(0) { $0 + $1.value }
        XCTAssertEqual(total, 1, "Out-of-window data must be dropped")
    }

    func testAggregatedByWeekReturnsEmptyForNonPositiveWeeks() {
        let now = testDate(day: 9)
        let data = [TrendDataPoint(date: testDate(day: 9), value: 1)]

        XCTAssertTrue(
            TrendChartCard.aggregatedByWeek(from: data, weeks: 0, now: now, calendar: weeklyCalendar).isEmpty
        )
    }

    // MARK: - Weekly ranges

    func testWeeklyRangesAreShortEnoughToLabelEveryBucket() {
        // Ranges are deliberately small (4W/8W) so every bucket can carry an
        // axis label. Longer ranges previously truncated every label to an
        // ellipsis, which is why they were removed.
        let ranges = TrendChartCard.WeeklyTrendRange.allCases.map(\.rawValue)
        XCTAssertEqual(ranges, [4, 8])
        XCTAssertLessThanOrEqual(ranges.max() ?? 0, 8,
                                 "Wider ranges crowd the axis; revisit label handling before adding one")
    }
}
