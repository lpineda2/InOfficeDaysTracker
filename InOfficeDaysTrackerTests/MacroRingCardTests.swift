import XCTest
@testable import InOfficeDaysTracker

final class MacroRingCardTests: XCTestCase {
    func testPaceLabel_MonthOver() {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2024
        comps.month = 1
        comps.day = 31 // last day of month
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        let now = calendar.date(from: comps)!

        // Compute expected label using same calendar arithmetic
        guard let monthRange = calendar.range(of: .day, in: .month, for: now),
              let lastDay = calendar.date(bySetting: .day, value: monthRange.count, of: now) else {
            XCTFail("Failed to compute last day")
            return
        }
        let startOfToday = calendar.startOfDay(for: now)
        let startOfLast = calendar.startOfDay(for: lastDay)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfLast)
        let daysLeft = components.day ?? 0

        // Use computed daysLeft as the working-days value so expectations align
        let label = MacroRingCard.paceLabel(paceNeeded: 2.0, workingDaysRemaining: daysLeft, now: now, calendar: calendar)
        let expected = daysLeft <= 0 ? "Month over" : "\(daysLeft)d left"
        XCTAssertEqual(label, expected)
    }

    func testPaceLabel_GoalMet() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let label = MacroRingCard.paceLabel(paceNeeded: 0.0, workingDaysRemaining: 5, now: now, calendar: calendar)
        XCTAssertEqual(label, "Goal met!")
    }

    func testPaceLabel_Challenging() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let label = MacroRingCard.paceLabel(paceNeeded: 6.0, workingDaysRemaining: 5, now: now, calendar: calendar)
        XCTAssertEqual(label, "Challenging")
    }

    func testPaceLabel_NormalDates_MonthLengths() {
        let calendar = Calendar(identifier: .gregorian)
        // Test various month lengths by computing expected days-left using calendar math
        let monthsToTest: [(Int, Int)] = [
            (2025, 1),
            (2024, 2),
            (2025, 4),
            (2025, 12)
        ]

        for (y, m) in monthsToTest {
            var comps = DateComponents()
            comps.year = y
            comps.month = m
            comps.day = 1
            comps.timeZone = TimeZone(secondsFromGMT: 0)
            let now = calendar.date(from: comps)!

            guard let monthRange = calendar.range(of: .day, in: .month, for: now),
                  let lastDay = calendar.date(bySetting: .day, value: monthRange.count, of: now) else {
                XCTFail("Failed to compute last day for \(y)-\(m)")
                continue
            }

            let startOfToday = calendar.startOfDay(for: now)
            let startOfLast = calendar.startOfDay(for: lastDay)
            let components = calendar.dateComponents([.day], from: startOfToday, to: startOfLast)
            let daysLeft = components.day ?? 0

            let label = MacroRingCard.paceLabel(paceNeeded: 2.0, workingDaysRemaining: daysLeft, now: now, calendar: calendar)
            let expected = daysLeft <= 0 ? "Month over" : "\(daysLeft)d left (workdays)"
            XCTAssertEqual(label, expected, "Failed for \(y)-\(m)")
        }
    }

    func testPaceLabel_TimezoneAware() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -5 * 3600)! // EST

        var comps = DateComponents()
        comps.year = 2025
        comps.month = 3
        comps.day = 10
        comps.timeZone = calendar.timeZone
        let now = calendar.date(from: comps)!

        // Compute expected days left using the same calendar
        guard let monthRange = calendar.range(of: .day, in: .month, for: now),
              let lastDay = calendar.date(bySetting: .day, value: monthRange.count, of: now) else {
            XCTFail("Failed to compute last day")
            return
        }
        let startOfToday = calendar.startOfDay(for: now)
        let startOfLast = calendar.startOfDay(for: lastDay)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfLast)
        let daysLeft = components.day ?? 0

        let label = MacroRingCard.paceLabel(paceNeeded: 2.0, workingDaysRemaining: daysLeft, now: now, calendar: calendar)
        XCTAssertEqual(label, "\(daysLeft)d left (workdays)")
    }

    func testMacroRingItem_safePercentageBehavior() {
        XCTAssertEqual(MacroRingItem.safePercentage(Double.nan), 0.0)
        XCTAssertEqual(MacroRingItem.safePercentage(-1.0), 0.0)
        XCTAssertEqual(MacroRingItem.safePercentage(Double.infinity), 0.0)
        XCTAssertEqual(MacroRingItem.safePercentage(0.5), 0.5)
        XCTAssertEqual(MacroRingItem.safePercentage(2.0), 1.0)
    }
}
