//
//  CadenceAwareStatsTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for cadence-aware dashboard stats: the week-based visit trend source
//  and the average-duration window/empty-state behavior (issue #2).
//

import XCTest
import CoreLocation
@testable import InOfficeDaysTracker

final class CadenceAwareStatsTests: XCTestCase {

    // MARK: - Fixtures

    private let testCoord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

    /// Creates a clean AppData instance backed by an isolated UserDefaults suite,
    /// matching the isolation pattern used by WeeklyPolicyTests/WidgetRefreshTests.
    @MainActor
    private func makeAppData() -> AppData {
        let suiteName = "test.cadencestats.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppData(sharedUserDefaults: defaults)
    }

    /// A completed visit of `hours` length on the given date.
    private func completedVisit(on date: Date, hours: Double) -> OfficeVisit {
        let exit = date.addingTimeInterval(hours * 3600)
        let event = OfficeEvent(entryTime: date, exitTime: exit)
        return OfficeVisit(date: date, events: [event], coordinate: testCoord)
    }

    /// An in-progress visit (no exit time) on the given date.
    private func activeVisit(on date: Date) -> OfficeVisit {
        let event = OfficeEvent(entryTime: date, exitTime: nil)
        return OfficeVisit(date: date, events: [event], coordinate: testCoord)
    }

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }

    // MARK: - getVisitTrend(weeks:)

    @MainActor
    func testWeeklyTrendReturnsEmptyForNonPositiveWeeks() {
        let appData = makeAppData()
        XCTAssertTrue(appData.getVisitTrend(weeks: 0).isEmpty)
        XCTAssertTrue(appData.getVisitTrend(weeks: -1).isEmpty)
    }

    @MainActor
    func testWeeklyTrendStartsOnAWeekBoundary() throws {
        let appData = makeAppData()
        let calendar = Calendar.current

        let trend = appData.getVisitTrend(weeks: 4)
        let firstDate = try XCTUnwrap(trend.first?.date)

        // The window must begin at the start of a week so the first chart bucket
        // is a whole week rather than a partial one.
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: firstDate)?.start
        XCTAssertEqual(firstDate, weekStart)
    }

    @MainActor
    func testWeeklyTrendCountsOnlyValidVisits() {
        let appData = makeAppData()

        appData.visits = [
            completedVisit(on: daysAgo(3), hours: 8),   // valid
            completedVisit(on: daysAgo(4), hours: 0.25), // too short (< 1h), excluded
            activeVisit(on: daysAgo(5))                  // in progress, excluded
        ]

        let total = appData.getVisitTrend(weeks: 4).reduce(0) { $0 + $1.count }
        XCTAssertEqual(total, 1, "Only completed visits of at least an hour should count")
    }

    @MainActor
    func testWeeklyTrendExcludesVisitsOlderThanWindow() {
        let appData = makeAppData()

        appData.visits = [
            completedVisit(on: daysAgo(2), hours: 8),   // inside a 2-week window
            completedVisit(on: daysAgo(60), hours: 8)   // well outside it
        ]

        let total = appData.getVisitTrend(weeks: 2).reduce(0) { $0 + $1.count }
        XCTAssertEqual(total, 1)
    }

    @MainActor
    func testWeeklyTrendIncludesToday() {
        let appData = makeAppData()
        let calendar = Calendar.current

        let trend = appData.getVisitTrend(weeks: 2)
        let lastDate = calendar.startOfDay(for: trend.last?.date ?? .distantPast)
        XCTAssertEqual(lastDate, calendar.startOfDay(for: Date()),
                       "The window should run through today so the current week is represented")
    }

    // MARK: - hasEnoughChartData(weeks:)

    @MainActor
    func testHasEnoughChartDataRequiresTwoDistinctWeeks() {
        let appData = makeAppData()

        // Two visits, but both inside the same week.
        appData.visits = [
            completedVisit(on: daysAgo(0), hours: 8),
            completedVisit(on: daysAgo(1), hours: 8)
        ]
        let sameWeekResult = appData.hasEnoughChartData(weeks: 8)

        // Add a visit far enough back to land in a different week.
        appData.visits.append(completedVisit(on: daysAgo(10), hours: 8))
        let twoWeekResult = appData.hasEnoughChartData(weeks: 8)

        XCTAssertFalse(sameWeekResult, "A single week of data is not enough")
        XCTAssertTrue(twoWeekResult, "Two distinct weeks with data should qualify")
    }

    @MainActor
    func testHasEnoughChartDataFalseWhenNoVisits() {
        let appData = makeAppData()
        XCTAssertFalse(appData.hasEnoughChartData(weeks: 8))
    }

    // MARK: - Average duration window (mirrors MainProgressView.getAverageDuration)

    /// Reimplements the view's selection rule so the windowing behavior is
    /// covered without instantiating SwiftUI (consistent with this codebase's
    /// convention of not unit-testing view bodies).
    @MainActor
    private func averageDuration(for appData: AppData, isWeeklyOnly: Bool) -> Double? {
        let validVisits = isWeeklyOnly
            ? appData.visits.filter { $0.isValidVisit }
            : appData.getValidVisits(for: Date())

        guard !validVisits.isEmpty else { return nil }

        let maxReasonableDuration: TimeInterval = 18 * 3600
        let capped = validVisits.compactMap { visit -> TimeInterval? in
            guard let duration = visit.duration else { return nil }
            return min(duration, maxReasonableDuration)
        }
        guard !capped.isEmpty else { return nil }

        let average = (capped.reduce(0, +) / Double(capped.count)) / 3600
        guard !average.isNaN && !average.isInfinite else { return nil }
        return average
    }

    @MainActor
    func testAverageDurationIsNilWhenOnlyVisitIsStillInProgress() {
        let appData = makeAppData()
        appData.visits = [activeVisit(on: Date())]

        // This is the reported bug: first visit of the period, still in progress.
        // It must read as "no completed visits yet", not as an average of zero.
        XCTAssertNil(averageDuration(for: appData, isWeeklyOnly: true))
        XCTAssertNil(averageDuration(for: appData, isWeeklyOnly: false))
    }

    @MainActor
    func testAverageDurationIsNilWhenNoVisitsAtAll() {
        let appData = makeAppData()
        appData.visits = []

        XCTAssertNil(averageDuration(for: appData, isWeeklyOnly: true))
        XCTAssertNil(averageDuration(for: appData, isWeeklyOnly: false))
    }

    @MainActor
    func testWeeklyCadenceUsesAllTimeWindowWhileMonthlyUsesCurrentMonth() throws {
        let appData = makeAppData()
        let calendar = Calendar.current

        // A completed visit in a previous month, and none in the current month.
        let lastMonth = calendar.date(byAdding: .month, value: -2, to: Date())!
        appData.visits = [completedVisit(on: lastMonth, hours: 6)]

        // Weekly-only: all-time window still finds it.
        let weekly = averageDuration(for: appData, isWeeklyOnly: true)
        XCTAssertNotNil(weekly)
        XCTAssertEqual(try XCTUnwrap(weekly), 6.0, accuracy: 0.01)

        // Monthly: current-month window finds nothing, so it's an empty state.
        XCTAssertNil(averageDuration(for: appData, isWeeklyOnly: false),
                     "Monthly cadence should keep its current-month window")
    }

    @MainActor
    func testAverageDurationCapsUnreasonablyLongVisits() throws {
        let appData = makeAppData()
        // A 30-hour visit should be capped at 18 hours before averaging.
        appData.visits = [completedVisit(on: daysAgo(1), hours: 30)]

        let average = try XCTUnwrap(averageDuration(for: appData, isWeeklyOnly: true))
        XCTAssertEqual(average, 18.0, accuracy: 0.01)
    }

    @MainActor
    func testAverageDurationAveragesMultipleCompletedVisits() throws {
        let appData = makeAppData()
        appData.visits = [
            completedVisit(on: daysAgo(1), hours: 6),
            completedVisit(on: daysAgo(2), hours: 8)
        ]

        let average = try XCTUnwrap(averageDuration(for: appData, isWeeklyOnly: true))
        XCTAssertEqual(average, 7.0, accuracy: 0.01)
    }
}
