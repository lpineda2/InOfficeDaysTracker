//
//  RecentVisitsListTests.swift
//  InOfficeDaysTrackerTests
//

import XCTest
@testable import InOfficeDaysTracker

final class RecentVisitsListTests: XCTestCase {

    /// `displayDate` must be computed from `Calendar.current` at access time,
    /// not cached — otherwise a day boundary crossed while the dashboard sits
    /// open (e.g. overnight, not in office) leaves "Today" showing for what
    /// is now yesterday's visit until something else forces a redraw.
    func testDisplayDateReflectsTodayRelativeToNow() {
        let item = VisitDisplayItem(
            id: UUID(),
            date: Date(),
            dayOfWeek: "Monday",
            duration: "8h 0m",
            isActiveSession: false
        )
        XCTAssertEqual(item.displayDate, "Today")
    }

    func testDisplayDateReflectsYesterdayRelativeToNow() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let item = VisitDisplayItem(
            id: UUID(),
            date: yesterday,
            dayOfWeek: "Sunday",
            duration: "8h 0m",
            isActiveSession: false
        )
        XCTAssertEqual(item.displayDate, "Yesterday")
    }

    func testDisplayDateFallsBackToFormattedDateForOlderVisits() {
        let lastWeek = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        let item = VisitDisplayItem(
            id: UUID(),
            date: lastWeek,
            dayOfWeek: "Sunday",
            duration: "8h 0m",
            isActiveSession: false
        )
        XCTAssertNotEqual(item.displayDate, "Today")
        XCTAssertNotEqual(item.displayDate, "Yesterday")
    }
}
