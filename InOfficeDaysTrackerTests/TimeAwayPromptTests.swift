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
}
