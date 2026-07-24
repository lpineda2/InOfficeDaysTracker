//
//  SettingsStore.swift
//  InOfficeDaysTracker
//
//  Handles persistence of app settings to/from UserDefaults.
//

import Foundation

final class SettingsStore {
    private let sharedUserDefaults: UserDefaults

    init(sharedUserDefaults: UserDefaults) {
        self.sharedUserDefaults = sharedUserDefaults
    }

    /// Load settings from UserDefaults. Returns default AppSettings if not found or decode fails.
    func load() -> AppSettings {
        if let data = sharedUserDefaults.data(forKey: AppGroupKeys.settingsKey) {
            if let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
                return decoded
            }
        }
        return AppSettings()
    }

    /// Save settings to UserDefaults.
    func save(_ settings: AppSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            sharedUserDefaults.set(encoded, forKey: AppGroupKeys.settingsKey)
        }
    }
}
