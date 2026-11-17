//
//  LocationAccessState.swift
//  InOfficeDaysTracker
//
//  Pure decision logic: what the app can currently do with location, and what
//  the user should do next. Kept free of CLLocationManager so every
//  combination can be unit tested.
//

import CoreLocation

/// Where the app stands with location access, in the order a user would need
/// to resolve it. Drives the dashboard banner, the Settings row and the
/// "Use Current Location" failure messages so they can't disagree.
enum LocationAccessState: Equatable {
    /// The system prompt has never been shown (fresh install, or a device
    /// restore that kept settings but reset permissions).
    case needsPrompt
    /// The user declined, or turned location off for this app.
    case denied
    /// A device policy (Screen Time, MDM) blocks location for this app.
    case restricted
    /// Access is granted but Precise Location is off, which geofencing needs.
    case approximateOnly
    /// The device reports it cannot monitor regions in the background.
    case monitoringUnavailable
    /// "While Using" only; automatic tracking needs "Always".
    case whenInUseOnly
    /// Everything automatic tracking needs is in place.
    case ready

    /// What tapping the primary button should do.
    enum Action: Equatable {
        case requestPermission
        case openSettings
        case none
    }

    init(
        authorizationStatus: CLAuthorizationStatus,
        accuracyAuthorization: CLAccuracyAuthorization,
        isRegionMonitoringAvailable: Bool
    ) {
        switch authorizationStatus {
        case .notDetermined:
            self = .needsPrompt
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .authorizedWhenInUse, .authorizedAlways:
            if accuracyAuthorization == .reducedAccuracy {
                self = .approximateOnly
            } else if !isRegionMonitoringAvailable {
                self = .monitoringUnavailable
            } else if authorizationStatus == .authorizedWhenInUse {
                self = .whenInUseOnly
            } else {
                self = .ready
            }
        @unknown default:
            // Unknown future status: Settings is the safest place to send people.
            self = .denied
        }
    }

    /// Whether the user should be shown something about location access.
    var needsAttention: Bool { self != .ready }

    /// Whether a one-shot location (for example "Use Current Location") can
    /// be fetched at a precision that is useful for picking an office.
    var allowsPreciseCurrentLocation: Bool {
        switch self {
        case .monitoringUnavailable, .whenInUseOnly, .ready:
            return true
        case .needsPrompt, .denied, .restricted, .approximateOnly:
            return false
        }
    }

    var title: String {
        switch self {
        case .needsPrompt: return "Location access needed"
        case .denied: return "Location access is off"
        case .restricted: return "Location access is restricted"
        case .approximateOnly: return "Precise Location is off"
        case .monitoringUnavailable: return "Automatic detection unavailable"
        case .whenInUseOnly: return "Allow location \u{201C}Always\u{201D}"
        case .ready: return "Location access is on"
        }
    }

    var message: String {
        switch self {
        case .needsPrompt:
            return "Allow location access so In Office Days can detect when you arrive at and leave your office."
        case .denied:
            return "Turn on location access for In Office Days in Settings so your office visits can be tracked automatically."
        case .restricted:
            return "Location access is restricted on this device, for example by Screen Time or a device profile. Automatic tracking is unavailable until it is allowed."
        case .approximateOnly:
            return "Automatic office detection needs Precise Location. Turn it on for In Office Days in Settings."
        case .monitoringUnavailable:
            return "This device reports that it can't watch for your office in the background, so automatic detection isn't available."
        case .whenInUseOnly:
            return "Tracking while the app is closed needs location set to Always. Choose Always for In Office Days."
        case .ready:
            return "Automatic office detection is on."
        }
    }

    var action: Action {
        switch self {
        case .needsPrompt, .whenInUseOnly: return .requestPermission
        case .denied, .approximateOnly: return .openSettings
        case .restricted, .monitoringUnavailable, .ready: return .none
        }
    }

    var actionTitle: String? {
        switch self {
        case .needsPrompt: return "Allow Location Access"
        case .whenInUseOnly: return "Enable Always Access"
        case .denied, .approximateOnly: return "Open Settings"
        case .restricted, .monitoringUnavailable, .ready: return nil
        }
    }

    /// Message for when "Use Current Location" can't proceed, always pointing
    /// the user at the manual-address alternative.
    var currentLocationFailureMessage: String {
        switch self {
        case .needsPrompt:
            return "Location access wasn't granted. You can allow it when prompted, or enter your office address manually."
        case .denied:
            return "Location access is off for In Office Days. Turn it on in Settings, or enter your office address manually."
        case .restricted:
            return "Location access is restricted on this device. Enter your office address manually."
        case .approximateOnly:
            return "Precise Location is off, so your current location would be too rough to use. Turn it on in Settings, or enter your office address manually."
        case .monitoringUnavailable, .whenInUseOnly, .ready:
            return "Unable to get current location. Please try again or enter address manually."
        }
    }
}
