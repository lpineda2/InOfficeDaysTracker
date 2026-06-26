//
//  ExitTimeAutoCloseOverwriteTests.swift
//  InOfficeDaysTrackerTests
//
//  Regression tests for the recurring "exit time overwritten to 11:59 PM" bug.
//
//  Root cause: AppData.autoCloseStaleVisit overwrote the authoritative visits[]
//  entry with a stale persisted currentVisit forced to 23:59:59, even when the
//  array entry already had a real exit time. These tests pin the mutation path
//  (driven through the real init() -> loadCurrentStatus() -> autoCloseStaleVisit
//  flow by pre-seeding the shared UserDefaults) and lock in the corrected,
//  non-destructive behavior.
//

import Foundation
import CoreLocation
import Testing
@testable import InOfficeDaysTracker

@MainActor
struct ExitTimeAutoCloseOverwriteTests {

    // MARK: - Test Helpers

    private let testCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

    /// Build an AppData backed by a fresh, isolated group suite pre-seeded with
    /// the given visits / currentVisit / pending-exit state, so that init() runs
    /// the real load + auto-close code path against that state.
    private func makeSeededAppData(
        visits: [OfficeVisit],
        currentVisit: OfficeVisit?,
        pendingExitTime: Date? = nil,
        pendingExitRegionId: String? = nil
    ) -> AppData {
        let suiteName = "group.com.lpineda.InOfficeDaysTracker.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        // Isolate the auto-close path: skip migrations and historical repair.
        defaults.set(true, forKey: "DataMigratedToAppGroups_v1.6.0")
        defaults.set(true, forKey: "DataMigratedToMultipleLocations_v1.9.0_v2")
        defaults.set(Date(), forKey: "HistoricalSessionRepairLastRun")

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(visits) {
            defaults.set(data, forKey: "OfficeVisits")
        }
        if let currentVisit, let data = try? encoder.encode(currentVisit) {
            defaults.set(data, forKey: "CurrentVisit")
            defaults.set(true, forKey: "IsCurrentlyInOffice")
        }
        if let pendingExitTime {
            defaults.set(pendingExitTime, forKey: "PendingExitTime")
        }
        if let pendingExitRegionId {
            defaults.set(pendingExitRegionId, forKey: "PendingExitRegionId")
        }
        defaults.synchronize()

        return AppData(sharedUserDefaults: defaults)
    }

    private var calendar: Calendar { Calendar.current }

    private var yesterday: Date {
        calendar.date(byAdding: .day, value: -1, to: Date())!
    }

    private func time(_ hour: Int, _ minute: Int, on day: Date) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func endOfDay(_ day: Date) -> Date {
        calendar.date(bySettingHour: 23, minute: 59, second: 59, of: day)!
    }

    private func completedVisit(entry: Date, exit: Date, on day: Date) -> OfficeVisit {
        OfficeVisit(date: day,
                    events: [OfficeEvent(entryTime: entry, exitTime: exit)],
                    coordinate: testCoordinate)
    }

    private func activeVisit(entry: Date, on day: Date) -> OfficeVisit {
        OfficeVisit(date: day,
                    events: [OfficeEvent(entryTime: entry, exitTime: nil)],
                    coordinate: testCoordinate)
    }

    private func visit(for day: Date, in appData: AppData) -> OfficeVisit? {
        appData.visits.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    // MARK: - Test 1: Completed visit must not be overwritten by stale active currentVisit

    @Test("A completed visit with a real exit is not overwritten by stale currentVisit cleanup")
    func completedVisitSurvivesStaleActiveCurrentVisit() async throws {
        let day = yesterday
        let realEntry = time(7, 24, on: day)
        let realExit = time(17, 0, on: day)

        // History has the correctly completed visit; a stale ACTIVE currentVisit
        // for the same day was left persisted (e.g. missed exit / app killed).
        let history = completedVisit(entry: realEntry, exit: realExit, on: day)
        let stale = activeVisit(entry: realEntry, on: day)

        let appData = makeSeededAppData(visits: [history], currentVisit: stale)

        let result = try #require(visit(for: day, in: appData))
        #expect(result.exitTime == realExit,
                "Real exit time (17:00) must be preserved, not overwritten")
        #expect(result.exitTime != endOfDay(day),
                "Exit time must NOT be forced to 23:59:59")
    }

    // MARK: - Test 2: Day-boundary cleanup must not change an already-completed visit

    @Test("Day-boundary cleanup does not change an already-completed visit (divergent stale copy)")
    func completedVisitUnchangedByDivergentStaleCopy() async throws {
        let day = yesterday
        let realEntry = time(7, 24, on: day)
        let realExit = time(17, 0, on: day)

        // History is completed at 17:00. A divergent (also completed) stale copy
        // claims 12:00. Cleanup must NOT replace authoritative history.
        let history = completedVisit(entry: realEntry, exit: realExit, on: day)
        let staleDivergent = completedVisit(entry: realEntry, exit: time(12, 0, on: day), on: day)

        let appData = makeSeededAppData(visits: [history], currentVisit: staleDivergent)

        let result = try #require(visit(for: day, in: appData))
        #expect(result.exitTime == realExit,
                "Authoritative completed exit (17:00) must be preserved, not replaced by stale 12:00")
    }

    // MARK: - Test 3: Active previous-day visit uses persisted real pending exit time

    @Test("Active previous-day visit is finalized with persisted real pending exit time, not 23:59")
    func activeVisitUsesPersistedPendingExitTime() async throws {
        let day = yesterday
        let realEntry = time(7, 24, on: day)
        let realPendingExit = time(17, 0, on: day)

        // The session never cleanly closed (active), but the real exit time was
        // persisted by the interrupted exit grace period.
        let active = activeVisit(entry: realEntry, on: day)

        let appData = makeSeededAppData(
            visits: [active],
            currentVisit: active,
            pendingExitTime: realPendingExit,
            pendingExitRegionId: "test_office"
        )

        let result = try #require(visit(for: day, in: appData))
        #expect(result.exitTime == realPendingExit,
                "Real pending exit time (17:00) must be applied")
        #expect(result.exitTime != endOfDay(day),
                "Exit must NOT fall back to 23:59:59 when a real exit is available")
    }

    // MARK: - Test 4: Active previous-day visit with no real exit may fall back to 23:59

    @Test("Active previous-day visit with no real exit falls back to end-of-day")
    func activeVisitWithoutPendingExitFallsBackToEndOfDay() async throws {
        let day = yesterday
        let realEntry = time(7, 24, on: day)

        let active = activeVisit(entry: realEntry, on: day)

        // No pending exit time persisted -> end-of-day fallback is acceptable.
        let appData = makeSeededAppData(visits: [active], currentVisit: active)

        let result = try #require(visit(for: day, in: appData))
        #expect(result.exitTime == endOfDay(day),
                "With no real exit available, end-of-day (23:59:59) fallback is expected")
    }

    // MARK: - Test 5: Grace-period cleanup must not overwrite a valid exit

    @Test("Grace-period restore does not overwrite an already-completed visit")
    func gracePeriodRestoreDoesNotOverwriteCompletedVisit() async throws {
        let day = yesterday
        let realEntry = time(7, 24, on: day)
        let realExit = time(17, 0, on: day)

        // Completed visit in history, plus a leftover previous-day pending exit.
        let history = completedVisit(entry: realEntry, exit: realExit, on: day)
        let appData = makeSeededAppData(
            visits: [history],
            currentVisit: nil,
            pendingExitTime: realExit,
            pendingExitRegionId: "test_office"
        )

        let locationService = LocationService()
        locationService.setAppData(appData)
        locationService.restoreExitGracePeriodIfNeeded()

        let result = try #require(visit(for: day, in: appData))
        #expect(result.exitTime == realExit,
                "Completed visit's real exit (17:00) must survive grace-period restore")
    }

    // MARK: - Test 6: Multi-session visit preserves earlier events, finalizes only trailing active

    @Test("Multi-session visit preserves completed earlier events and finalizes only the trailing active event")
    func multiSessionPreservesEarlierEventsAndFinalizesTrailing() async throws {
        let day = yesterday
        let firstEntry = time(7, 24, on: day)
        let firstExit = time(12, 0, on: day)
        let secondEntry = time(13, 0, on: day)

        // First session completed (7:24-12:00); a second session is still active.
        let multi = OfficeVisit(
            date: day,
            events: [
                OfficeEvent(entryTime: firstEntry, exitTime: firstExit),
                OfficeEvent(entryTime: secondEntry, exitTime: nil)
            ],
            coordinate: testCoordinate
        )

        let appData = makeSeededAppData(visits: [multi], currentVisit: multi)

        let result = try #require(visit(for: day, in: appData))
        #expect(result.events.count == 2, "Both sessions must be retained")
        #expect(result.events.first?.exitTime == firstExit,
                "Earlier completed session (12:00) must be preserved")
        #expect(result.events.last?.exitTime == endOfDay(day),
                "Trailing active session is finalized to end-of-day when no real exit is available")
    }
}
