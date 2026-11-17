//
//  LocationAccessStateTests.swift
//  InOfficeDaysTrackerTests
//
//  Covers the decision of what location access the app has and what the user
//  should do next. Regression coverage for the iPhone Duo report: the app never
//  asked for location, "Use Current Location" failed with a generic error, and
//  "Always" was blocked with a message that hid the real reason.
//

import Testing
import CoreLocation
@testable import InOfficeDaysTracker

struct LocationAccessStateTests {

    private func state(
        _ status: CLAuthorizationStatus,
        accuracy: CLAccuracyAuthorization = .fullAccuracy,
        monitoring: Bool = true
    ) -> LocationAccessState {
        LocationAccessState(
            authorizationStatus: status,
            accuracyAuthorization: accuracy,
            isRegionMonitoringAvailable: monitoring
        )
    }

    // MARK: - State mapping

    @Test("Never-asked maps to needsPrompt and offers the permission request")
    func neverAskedNeedsPrompt() {
        let result = state(.notDetermined)
        #expect(result == .needsPrompt)
        #expect(result.action == .requestPermission)
        #expect(result.needsAttention)
    }

    @Test("Denied and restricted are distinguished; only denied can be fixed in Settings")
    func deniedAndRestricted() {
        #expect(state(.denied) == .denied)
        #expect(state(.denied).action == .openSettings)
        #expect(state(.restricted) == .restricted)
        #expect(state(.restricted).action == .none)
        #expect(state(.restricted).actionTitle == nil)
    }

    @Test("While-Using with precise access and monitoring asks to upgrade to Always")
    func whenInUseOnly() {
        let result = state(.authorizedWhenInUse)
        #expect(result == .whenInUseOnly)
        #expect(result.action == .requestPermission)
        #expect(result.actionTitle == "Enable Always Access")
    }

    @Test("Always with precise access and monitoring is ready and needs no attention")
    func alwaysIsReady() {
        let result = state(.authorizedAlways)
        #expect(result == .ready)
        #expect(!result.needsAttention)
        #expect(result.action == .none)
    }

    @Test("Approximate location is reported as such for both authorized levels")
    func approximateOnly() {
        #expect(state(.authorizedWhenInUse, accuracy: .reducedAccuracy) == .approximateOnly)
        #expect(state(.authorizedAlways, accuracy: .reducedAccuracy) == .approximateOnly)
        #expect(state(.authorizedAlways, accuracy: .reducedAccuracy).action == .openSettings)
    }

    @Test("Region monitoring unavailable is reported even when Always is granted")
    func monitoringUnavailable() {
        #expect(state(.authorizedAlways, monitoring: false) == .monitoringUnavailable)
        #expect(state(.authorizedWhenInUse, monitoring: false) == .monitoringUnavailable)
        #expect(state(.authorizedAlways, monitoring: false).action == .none)
    }

    @Test("Monitoring availability does not change not-yet-granted states")
    func monitoringIgnoredBeforeAuthorization() {
        #expect(state(.notDetermined, monitoring: false) == .needsPrompt)
        #expect(state(.denied, monitoring: false) == .denied)
    }

    // MARK: - Regression: the real reason must not be overwritten

    @Test("Precise Location off and monitoring unavailable give different messages")
    func distinctReasonsGiveDistinctMessages() {
        let approximate = state(.authorizedWhenInUse, accuracy: .reducedAccuracy)
        let unsupported = state(.authorizedWhenInUse, monitoring: false)

        #expect(approximate.message != unsupported.message)
        #expect(approximate.message.contains("Precise Location"))
        #expect(!unsupported.message.contains("Precise Location"))
    }

    // MARK: - Use Current Location (setup step 1)

    @Test("Unasked state fails with a message that offers manual entry, not the generic error")
    func currentLocationBeforePermission() {
        let result = state(.notDetermined)
        #expect(!result.allowsPreciseCurrentLocation)
        #expect(result.currentLocationFailureMessage.contains("manually"))
        #expect(result.currentLocationFailureMessage != LocationAccessState.ready.currentLocationFailureMessage)
    }

    @Test("Denied and approximate states point the user at Settings")
    func currentLocationNeedsSettings() {
        #expect(state(.denied).currentLocationFailureMessage.contains("Settings"))
        #expect(state(.authorizedWhenInUse, accuracy: .reducedAccuracy).currentLocationFailureMessage.contains("Precise Location"))
    }

    @Test("A one-shot precise location is allowed whenever precise access exists")
    func currentLocationAllowedStates() {
        #expect(state(.authorizedWhenInUse).allowsPreciseCurrentLocation)
        #expect(state(.authorizedAlways).allowsPreciseCurrentLocation)
        // Region monitoring being unavailable must not block picking an office.
        #expect(state(.authorizedAlways, monitoring: false).allowsPreciseCurrentLocation)
        #expect(!state(.denied).allowsPreciseCurrentLocation)
        #expect(!state(.restricted).allowsPreciseCurrentLocation)
    }

    // MARK: - Copy consistency

    @Test("Every state has a title and message, and actionTitle matches action")
    func everyStateIsDescribed() {
        let all: [LocationAccessState] = [
            .needsPrompt, .denied, .restricted, .approximateOnly,
            .monitoringUnavailable, .whenInUseOnly, .ready
        ]
        for item in all {
            #expect(!item.title.isEmpty)
            #expect(!item.message.isEmpty)
            #expect((item.actionTitle != nil) == (item.action != .none), "\(item) action/title mismatch")
        }
    }
}
