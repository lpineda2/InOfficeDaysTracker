//
//  VisitRepository.swift
//  InOfficeDaysTracker
//
//  Handles persistence of office visits to/from UserDefaults.
//

import Foundation

final class VisitRepository {
    private let sharedUserDefaults: UserDefaults

    init(sharedUserDefaults: UserDefaults) {
        self.sharedUserDefaults = sharedUserDefaults
    }

    /// Load visits from UserDefaults.
    func load() -> [OfficeVisit] {
        if let data = sharedUserDefaults.data(forKey: AppGroupKeys.visitsKey),
           let decoded = try? JSONDecoder().decode([OfficeVisit].self, from: data) {
            return decoded
        }
        return []
    }

    /// Save visits to UserDefaults.
    func save(_ visits: [OfficeVisit]) {
        if let encoded = try? JSONEncoder().encode(visits) {
            sharedUserDefaults.set(encoded, forKey: AppGroupKeys.visitsKey)
        }
    }
}
