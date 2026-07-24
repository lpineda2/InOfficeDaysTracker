//
//  VisitSessionValidatorTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for VisitSessionValidator visit/session consistency logic.
//

import XCTest
@testable import InOfficeDaysTracker

final class VisitSessionValidatorTests: XCTestCase {
    var validator: VisitSessionValidator!
    let calendar = Calendar.current
    var today: Date!
    var tomorrow: Date!

    override func setUp() {
        super.setUp()
        validator = VisitSessionValidator()
        today = calendar.startOfDay(for: Date())
        tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
    }

    func testNoCurrentVisit_ReturnsNoChanges() {
        let visits = [createVisit(date: today)]
        let (resultVisits, resultCurrent, resultInOffice, visitWasCleared, anyChanges) = validator.validateCurrentVisitConsistency(
            currentVisit: nil,
            visits: visits,
            isCurrentlyInOffice: false
        )

        XCTAssertEqual(resultVisits.count, 1)
        XCTAssertNil(resultCurrent)
        XCTAssertFalse(resultInOffice)
        XCTAssertFalse(visitWasCleared)
        XCTAssertFalse(anyChanges)
    }

    func testCurrentVisitFromWrongDay_ClearsVisit() {
        let currentVisit = createVisit(date: tomorrow)
        let visits = [createVisit(date: today)]
        let (resultVisits, resultCurrent, resultInOffice, visitWasCleared, anyChanges) = validator.validateCurrentVisitConsistency(
            currentVisit: currentVisit,
            visits: visits,
            isCurrentlyInOffice: true
        )

        XCTAssertEqual(resultVisits.count, 1)
        XCTAssertNil(resultCurrent)
        XCTAssertFalse(resultInOffice)
        XCTAssertTrue(visitWasCleared)
        XCTAssertTrue(anyChanges)
    }

    func testCurrentVisitFoundInArray_NoSync_ReturnsNoChanges() {
        let visit = createVisit(date: today, isActive: true)
        let (resultVisits, resultCurrent, resultInOffice, visitWasCleared, anyChanges) = validator.validateCurrentVisitConsistency(
            currentVisit: visit,
            visits: [visit],
            isCurrentlyInOffice: true
        )

        XCTAssertEqual(resultVisits.count, 1)
        XCTAssertNotNil(resultCurrent)
        XCTAssertTrue(resultInOffice)
        XCTAssertFalse(visitWasCleared)
        XCTAssertFalse(anyChanges)
    }

    func testCurrentVisitInArrayNeedsSync_SyncsSession() {
        let baseVisit = createVisit(date: today, isActive: false)
        let currentVisit = createVisit(date: today, isActive: true)
        let (resultVisits, resultCurrent, resultInOffice, visitWasCleared, anyChanges) = validator.validateCurrentVisitConsistency(
            currentVisit: currentVisit,
            visits: [baseVisit],
            isCurrentlyInOffice: true
        )

        XCTAssertEqual(resultVisits.count, 1)
        XCTAssertNotNil(resultCurrent)
        XCTAssertTrue(resultCurrent?.isActiveSession ?? false)
        XCTAssertTrue(resultInOffice)
        XCTAssertFalse(visitWasCleared)
        XCTAssertTrue(anyChanges)
    }

    func testCurrentVisitNotInArray_AddsToArray() {
        let currentVisit = createVisit(date: today)
        let existingVisit = createVisit(date: tomorrow)
        let (resultVisits, resultCurrent, resultInOffice, visitWasCleared, anyChanges) = validator.validateCurrentVisitConsistency(
            currentVisit: currentVisit,
            visits: [existingVisit],
            isCurrentlyInOffice: true
        )

        XCTAssertEqual(resultVisits.count, 2)
        XCTAssertNotNil(resultCurrent)
        XCTAssertTrue(resultInOffice)
        XCTAssertFalse(visitWasCleared)
        XCTAssertTrue(anyChanges)
    }

    // MARK: - Helpers

    private func createVisit(date: Date, isActive: Bool = false) -> OfficeVisit {
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        var visit = OfficeVisit(date: date, coordinate: coordinate)
        if isActive {
            visit.startNewSession()
        }
        return visit
    }
}
