//
//  AppDataMigrationRunner.swift
//  InOfficeDaysTracker
//
//  Handles one-time data migrations from previous app versions.
//

import Foundation

final class AppDataMigrationRunner {
    private let sharedUserDefaults: UserDefaults
    private let settingsUpdater: (AppSettings) -> Void

    init(sharedUserDefaults: UserDefaults, settingsUpdater: @escaping (AppSettings) -> Void) {
        self.sharedUserDefaults = sharedUserDefaults
        self.settingsUpdater = settingsUpdater
    }

    /// Run migrations from standard UserDefaults to app groups (v1.6.0).
    func migrateDataFromStandardUserDefaults() {
        let standardDefaults = UserDefaults.standard
        let migrationKey = "DataMigratedToAppGroups_v1.6.0"

        // Check if migration already completed
        if sharedUserDefaults.bool(forKey: migrationKey) {
            debugLog("[AppData] Data migration already completed")
            return
        }

        debugLog("[AppData] Starting data migration from standard UserDefaults...")
        var migrationCount = 0

        // Migrate settings
        if let settingsData = standardDefaults.data(forKey: AppGroupKeys.settingsKey),
           sharedUserDefaults.data(forKey: AppGroupKeys.settingsKey) == nil {
            sharedUserDefaults.set(settingsData, forKey: AppGroupKeys.settingsKey)
            migrationCount += 1
            debugLog("[AppData] Migrated app settings")
        }

        // Migrate visits
        if let visitsData = standardDefaults.data(forKey: AppGroupKeys.visitsKey),
           sharedUserDefaults.data(forKey: AppGroupKeys.visitsKey) == nil {
            sharedUserDefaults.set(visitsData, forKey: AppGroupKeys.visitsKey)
            migrationCount += 1
            debugLog("[AppData] Migrated office visits history")
        }

        // Migrate current visit
        if let currentVisitData = standardDefaults.data(forKey: AppGroupKeys.currentVisitKey),
           sharedUserDefaults.data(forKey: AppGroupKeys.currentVisitKey) == nil {
            sharedUserDefaults.set(currentVisitData, forKey: AppGroupKeys.currentVisitKey)
            migrationCount += 1
            debugLog("[AppData] Migrated current visit state")
        }

        // Migrate office status
        if standardDefaults.object(forKey: "IsCurrentlyInOffice") != nil,
           sharedUserDefaults.object(forKey: AppGroupKeys.isCurrentlyInOfficeKey) == nil {
            let isInOffice = standardDefaults.bool(forKey: "IsCurrentlyInOffice")
            sharedUserDefaults.set(isInOffice, forKey: AppGroupKeys.isCurrentlyInOfficeKey)
            migrationCount += 1
            debugLog("[AppData] Migrated office status: \(isInOffice)")
        }

        // Mark migration as complete
        sharedUserDefaults.set(true, forKey: migrationKey)

        debugLog("[AppData] Migration completed! Migrated \(migrationCount) data items")

        if migrationCount > 0 {
            debugLog("[AppData] ✅ Your previous app data has been restored!")
        }
    }

    /// Run migration of single office location to multiple office locations (v1.9.0).
    func migrateToMultipleOfficeLocations(currentSettings: AppSettings) {
        let migrationKey = "DataMigratedToMultipleLocations_v1.9.0_v2"

        // Check if migration already completed
        let migrationCompleted = sharedUserDefaults.bool(forKey: migrationKey)

        // Also check for data consistency - if we have a legacy location but no new locations,
        // force migration even if marked as complete
        let hasLegacyLocation = currentSettings.officeLocation != nil
        let hasNewLocations = !currentSettings.officeLocations.isEmpty
        let needsForcedMigration = hasLegacyLocation && !hasNewLocations

        if migrationCompleted && !needsForcedMigration {
            return
        }

        if needsForcedMigration {
            debugLog("[AppData] Detected inconsistent office location data - forcing migration...")
        } else {
            debugLog("[AppData] Starting v1.9.0 office location migration...")
        }

        // If user has an existing single office location but no office locations array
        if let existingLocation = currentSettings.officeLocation,
           currentSettings.officeLocations.isEmpty {
            var updatedSettings = currentSettings
            let migratedLocation = OfficeLocation(
                name: "Office",
                coordinate: existingLocation,
                address: currentSettings.officeAddress,
                detectionRadius: currentSettings.detectionRadius,
                isPrimary: true
            )
            updatedSettings.officeLocations = [migratedLocation]
            settingsUpdater(updatedSettings)
            debugLog("[AppData] Migrated single office location to locations array")
        }

        // Mark migration as complete
        sharedUserDefaults.set(true, forKey: migrationKey)
        debugLog("[AppData] v1.9.0 migration completed!")
    }

    /// Force migration of office locations if data is inconsistent.
    /// Used by AppData's ensureOfficeLocationConsistency() to handle edge cases.
    func ensureOfficeLocationConsistency(currentSettings: AppSettings) {
        if currentSettings.officeLocation != nil && currentSettings.officeLocations.isEmpty {
            debugLog("[AppData] Forcing office location migration due to inconsistent data...")
            let migrationKey = "DataMigratedToMultipleLocations_v1.9.0_v2"
            sharedUserDefaults.set(false, forKey: migrationKey)
            migrateToMultipleOfficeLocations(currentSettings: currentSettings)
        }
    }
}
