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
}
