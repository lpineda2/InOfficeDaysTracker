//
//  WeeklyPolicyPresetTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for the ready-made weekly policy configurations.
//

import XCTest
@testable import InOfficeDaysTracker

final class WeeklyPolicyPresetTests: XCTestCase {

    // MARK: - Defaults are untouched

    func testShippedDefaultsDoNotEnableTimeAwayHandling() {
        // Presets are opt-in. A fresh policy must not silently adopt one, or
        // existing users would see their weekly goals change on upgrade.
        let fresh = WeeklyPolicy()
        XCTAssertFalse(fresh.honorsHolidaysAndPTO)
        XCTAssertEqual(fresh.unavailabilityAllowance, 0)
        XCTAssertFalse(fresh.waivesAnchorDaysOnHolidayWeeks)
    }

    func testNoPresetIsAppliedByDefault() {
        let fresh = WeeklyPolicy()
        let timeAwayPreset = WeeklyPolicyPreset.anchoredWeekWithTimeAway
        XCTAssertFalse(timeAwayPreset.matches(fresh),
                       "The time-away preset must not match the shipped default")
    }

    // MARK: - Preset contents

    func testSimpleMinimumHasNoAnchorOrTimeAwayHandling() {
        let policy = WeeklyPolicyPreset.simpleMinimum.policy()
        XCTAssertEqual(policy.weeklyMinimumDays, 3)
        XCTAssertTrue(policy.anchorDayGroups.isEmpty)
        XCTAssertFalse(policy.honorsHolidaysAndPTO)
    }

    func testAnchoredWeekAddsAnAnchorGroupWithoutTimeAwayHandling() {
        let policy = WeeklyPolicyPreset.anchoredWeek.policy()
        XCTAssertEqual(policy.weeklyMinimumDays, 3)
        XCTAssertEqual(policy.anchorDayGroups, [[.monday, .friday]])
        XCTAssertFalse(policy.honorsHolidaysAndPTO,
                       "Anchor days and time-away handling are independent choices")
    }

    func testAnchoredWeekWithTimeAwayEnablesTheFullConfiguration() {
        let policy = WeeklyPolicyPreset.anchoredWeekWithTimeAway.policy()
        XCTAssertEqual(policy.weeklyMinimumDays, 3)
        XCTAssertEqual(policy.anchorDayGroups, [[.monday, .friday]])
        XCTAssertTrue(policy.honorsHolidaysAndPTO)
        XCTAssertTrue(policy.waivesAnchorDaysOnHolidayWeeks)
    }

    // MARK: - Preserving unrelated settings

    func testApplyingAPresetKeepsTheEffectiveDate() {
        let start = Date()
        var existing = WeeklyPolicy()
        existing.effectiveStartDate = start

        let policy = WeeklyPolicyPreset.anchoredWeek.policy(basedOn: existing)
        XCTAssertEqual(policy.effectiveStartDate, start,
                       "A preset shouldn't clear settings it doesn't speak to")
    }

    func testApplyingAPresetClearsRequiredWeekdays() {
        var existing = WeeklyPolicy()
        existing.requiredWeekdays = [.wednesday]

        let policy = WeeklyPolicyPreset.simpleMinimum.policy(basedOn: existing)
        XCTAssertTrue(policy.requiredWeekdays.isEmpty,
                      "Presets fully define the rules they cover")
    }

    // MARK: - Matching

    func testEachPresetMatchesItsOwnOutput() {
        for preset in WeeklyPolicyPreset.allCases {
            XCTAssertTrue(preset.matches(preset.policy()),
                          "\(preset.rawValue) should recognize the policy it produces")
        }
    }

    func testPresetsAreMutuallyExclusive() {
        for preset in WeeklyPolicyPreset.allCases {
            let policy = preset.policy()
            let others = WeeklyPolicyPreset.allCases.filter { $0 != preset }
            for other in others {
                XCTAssertFalse(other.matches(policy),
                               "\(other.rawValue) shouldn't match \(preset.rawValue)'s policy")
            }
        }
    }

    func testMatchIgnoresSettingsThePresetDoesNotControl() {
        var policy = WeeklyPolicyPreset.anchoredWeek.policy()
        policy.effectiveStartDate = Date()
        policy.monthlyMinimumDays = 12

        XCTAssertTrue(WeeklyPolicyPreset.anchoredWeek.matches(policy),
                      "Unrelated settings shouldn't break preset recognition")
    }

    func testAModifiedPolicyNoLongerMatches() {
        var policy = WeeklyPolicyPreset.anchoredWeek.policy()
        policy.weeklyMinimumDays = 4

        XCTAssertFalse(WeeklyPolicyPreset.anchoredWeek.matches(policy))
    }
}
