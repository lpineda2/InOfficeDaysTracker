//
//  TimeAwayPromptTests.swift
//  InOfficeDaysTrackerTests
//
//  Tests for the one-time dashboard prompt introducing PTO/holiday goal
//  adjustment to users who enabled weekly tracking before it existed.
//

import XCTest
@testable import InOfficeDaysTracker

final class TimeAwayPromptTests: XCTestCase {

    @MainActor
    private func makeAppData() -> AppData {
        let suiteName = "test.timeawayprompt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppData(sharedUserDefaults: defaults)
    }

    /// Mirrors `MainProgressView.showsTimeAwayPrompt`, which can't be read
    /// directly from a SwiftUI view. Kept in sync deliberately; this codebase
    /// doesn't unit-test view bodies.
    private func shouldShowPrompt(_ settings: AppSettings) -> Bool {
        settings.trackingCadence.includesWeekly
            && !settings.weeklyPolicy.honorsHolidaysAndPTO
            && !settings.hasSeenTimeAwayPrompt
    }

    // MARK: - Visibility

    func testPromptIsHiddenForMonthlyOnlyUsers() {
        var settings = AppSettings()
        settings.trackingCadence = .monthly
        XCTAssertFalse(shouldShowPrompt(settings),
                       "Monthly users have no weekly goal to reduce")
    }

    func testPromptIsShownForWeeklyUsersWhoHaventEnabledTheFeature() {
        var settings = AppSettings()
        settings.trackingCadence = .weekly
        XCTAssertTrue(shouldShowPrompt(settings),
                      "This is the 1.15.0 upgrade case the prompt exists for")
    }

    func testPromptIsShownForBothCadence() {
        var settings = AppSettings()
        settings.trackingCadence = .both
        XCTAssertTrue(shouldShowPrompt(settings))
    }

    func testPromptIsHiddenOnceTheFeatureIsEnabled() {
        var settings = AppSettings()
        settings.trackingCadence = .weekly
        settings.weeklyPolicy.honorsHolidaysAndPTO = true
        XCTAssertFalse(shouldShowPrompt(settings),
                       "Nothing left to suggest once it's on")
    }

    func testPromptIsHiddenOnceDismissed() {
        var settings = AppSettings()
        settings.trackingCadence = .weekly
        settings.hasSeenTimeAwayPrompt = true
        XCTAssertFalse(shouldShowPrompt(settings))
    }

    // MARK: - Persistence

    @MainActor
    func testDismissalSurvivesSettingsRoundTrip() throws {
        let appData = makeAppData()

        var settings = appData.settings
        settings.trackingCadence = .weekly
        settings.hasSeenTimeAwayPrompt = true
        appData.updateSettings(settings)

        // Encode/decode the way settings are actually persisted; a missed
        // Codable key would resurrect the prompt on every launch.
        let data = try JSONEncoder().encode(appData.settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertTrue(decoded.hasSeenTimeAwayPrompt)
        XCTAssertFalse(shouldShowPrompt(decoded))
    }

    func testFlagDefaultsToFalseForExistingUsers() throws {
        // Simulate a payload written before this flag existed by encoding
        // current settings and stripping the key. Building the JSON by hand
        // would just test my guess at the schema.
        var settings = AppSettings()
        settings.trackingCadence = .weekly
        settings.hasSeenTimeAwayPrompt = true

        let encoded = try JSONEncoder().encode(settings)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        XCTAssertNotNil(object["hasSeenTimeAwayPrompt"], "Key should exist before removal")
        object.removeValue(forKey: "hasSeenTimeAwayPrompt")

        let legacy = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: legacy)

        XCTAssertFalse(decoded.hasSeenTimeAwayPrompt,
                       "Upgrading users should still see the prompt once")
        XCTAssertTrue(shouldShowPrompt(decoded))
    }

    func testFreshSettingsHaveNotSeenThePrompt() {
        XCTAssertFalse(AppSettings().hasSeenTimeAwayPrompt)
    }

    // MARK: - Enabling from the prompt

    /// Mirrors `MainProgressView.enableTimeAwayHandling`, which deliberately
    /// does not mark the prompt seen.
    private func enableFromPrompt(_ settings: inout AppSettings) {
        settings.weeklyPolicy.honorsHolidaysAndPTO = true
    }

    /// Mirrors the flag reset in `WeeklyPolicySettingsView.savePolicy`.
    private func setFeatureEnabled(_ enabled: Bool, in settings: inout AppSettings) {
        let wasEnabled = settings.weeklyPolicy.honorsHolidaysAndPTO
        settings.weeklyPolicy.honorsHolidaysAndPTO = enabled
        if wasEnabled && !enabled {
            settings.hasSeenTimeAwayPrompt = false
        }
    }

    func testEnablingFromThePromptTurnsOnTheFeature() {
        var settings = AppSettings()
        settings.trackingCadence = .weekly
        XCTAssertTrue(shouldShowPrompt(settings))

        enableFromPrompt(&settings)

        XCTAssertTrue(settings.weeklyPolicy.honorsHolidaysAndPTO,
                      "One tap should be enough to turn it on")
        XCTAssertFalse(shouldShowPrompt(settings),
                       "The prompt shouldn't return after enabling")
    }

    func testEnablingDoesNotMarkThePromptSeen() {
        var settings = AppSettings()
        settings.trackingCadence = .weekly

        enableFromPrompt(&settings)

        // Enabling already hides the prompt. Also writing "seen" would make the
        // suppression permanent, so turning the feature back off would leave no
        // way to see the explanation again.
        XCTAssertFalse(settings.hasSeenTimeAwayPrompt)
    }

    // MARK: - Cross-screen consistency

    @MainActor
    func testEnablingFromTheDashboardIsVisibleToTheSettingsScreen() {
        // Regression: WeeklyPolicySettingsView mirrors the policy into @State,
        // whose initial values SwiftUI captures only at first creation. When
        // the dashboard prompt enabled the feature, a previously-created
        // settings view still held the old value and wrote it back on the next
        // edit, silently reverting the change. The view now resyncs on appear;
        // this pins that AppData is the source of truth either way.
        let appData = makeAppData()

        var settings = appData.settings
        settings.trackingCadence = .weekly
        settings.weeklyPolicy.honorsHolidaysAndPTO = false
        appData.updateSettings(settings)

        // Dashboard prompt enables it.
        var enabled = appData.settings
        enabled.weeklyPolicy.honorsHolidaysAndPTO = true
        appData.updateSettings(enabled)

        // What the settings screen reads when it resyncs.
        XCTAssertTrue(appData.settings.weeklyPolicy.honorsHolidaysAndPTO,
                      "The settings screen must see the dashboard's change")

        // An unrelated edit made from the settings screen must not revert it.
        var edited = appData.settings
        edited.weeklyPolicy.weeklyMinimumDays = 4
        appData.updateSettings(edited)

        XCTAssertTrue(appData.settings.weeklyPolicy.honorsHolidaysAndPTO,
                      "Editing another field shouldn't turn the feature back off")
        XCTAssertEqual(appData.settings.weeklyPolicy.weeklyMinimumDays, 4)
    }

    // MARK: - Recovery

    func testTurningTheFeatureOffMakesThePromptEligibleAgain() {
        var settings = AppSettings()
        settings.trackingCadence = .weekly
        settings.weeklyPolicy.honorsHolidaysAndPTO = true
        settings.hasSeenTimeAwayPrompt = true
        XCTAssertFalse(shouldShowPrompt(settings))

        setFeatureEnabled(false, in: &settings)

        XCTAssertTrue(shouldShowPrompt(settings),
                      "Disabling returns the user to the state the prompt is for")
    }

    func testTurningTheFeatureOnDoesNotClearTheSeenFlag() {
        var settings = AppSettings()
        settings.trackingCadence = .weekly
        settings.hasSeenTimeAwayPrompt = true

        setFeatureEnabled(true, in: &settings)

        XCTAssertTrue(settings.hasSeenTimeAwayPrompt,
                      "Only the off transition should reset it")
    }

    func testSavingWithTheFeatureAlreadyOffLeavesTheSeenFlagAlone() {
        // A user who dismissed the prompt and then edits unrelated policy
        // settings shouldn't have it reappear.
        var settings = AppSettings()
        settings.trackingCadence = .weekly
        settings.weeklyPolicy.honorsHolidaysAndPTO = false
        settings.hasSeenTimeAwayPrompt = true

        setFeatureEnabled(false, in: &settings)

        XCTAssertTrue(settings.hasSeenTimeAwayPrompt,
                      "No transition occurred, so nothing should change")
        XCTAssertFalse(shouldShowPrompt(settings))
    }

    func testEnablingFromThePromptLeavesOtherPolicySettingsAlone() {
        var settings = AppSettings()
        settings.trackingCadence = .weekly
        settings.weeklyPolicy.weeklyMinimumDays = 4
        settings.weeklyPolicy.anchorDayGroups = [[.tuesday]]
        settings.weeklyPolicy.unavailabilityAllowance = 0
        settings.weeklyPolicy.waivesAnchorDaysOnHolidayWeeks = false

        enableFromPrompt(&settings)

        // The prompt turns on the headline behavior only; anything else the
        // user configured stays as they left it.
        XCTAssertEqual(settings.weeklyPolicy.weeklyMinimumDays, 4)
        XCTAssertEqual(settings.weeklyPolicy.anchorDayGroups, [[.tuesday]])
        XCTAssertEqual(settings.weeklyPolicy.unavailabilityAllowance, 0)
        XCTAssertFalse(settings.weeklyPolicy.waivesAnchorDaysOnHolidayWeeks)
    }

    @MainActor
    func testEnablingFromThePromptPersists() throws {
        let appData = makeAppData()

        var settings = appData.settings
        settings.trackingCadence = .weekly
        enableFromPrompt(&settings)
        appData.updateSettings(settings)

        let data = try JSONEncoder().encode(appData.settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertTrue(decoded.weeklyPolicy.honorsHolidaysAndPTO)
        XCTAssertFalse(shouldShowPrompt(decoded),
                       "Enabling suppresses the prompt without needing the seen flag")
    }
}
