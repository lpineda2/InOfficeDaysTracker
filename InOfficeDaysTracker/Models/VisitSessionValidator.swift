//
//  VisitSessionValidator.swift
//  InOfficeDaysTracker
//
//  Validates visit/session state consistency between currentVisit and visits array.
//

import Foundation

final class VisitSessionValidator {
    /// Validate that currentVisit is consistent with visits array and return corrected state.
    /// - Parameters:
    ///   - currentVisit: Current active visit, if any
    ///   - visits: Array of all office visits
    ///   - isCurrentlyInOffice: Current in-office status
    /// - Returns: Tuple of (validated visits, validated currentVisit, validated isCurrentlyInOffice, visitWasCleared, anyChangesApplied)
    func validateCurrentVisitConsistency(
        currentVisit: OfficeVisit?,
        visits: [OfficeVisit],
        isCurrentlyInOffice: Bool
    ) -> (visits: [OfficeVisit], currentVisit: OfficeVisit?, isCurrentlyInOffice: Bool, visitWasCleared: Bool, anyChangesApplied: Bool) {
        guard let currentVisit = currentVisit else {
            debugLog("[AppData] No current visit to validate")
            return (visits, nil, false, false, false)
        }

        let calendar = Calendar.current
        let today = Date()

        // Check if current visit is from today
        if !calendar.isDate(currentVisit.date, inSameDayAs: today) {
            debugLog("[AppData] Current visit is from wrong day, clearing it")
            return (visits, nil, false, true, true)
        }

        // Check if there's a matching visit in the array
        if let matchingIndex = visits.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: currentVisit.date) }) {
            let matchingVisit = visits[matchingIndex]

            // If the visit in array doesn't have an active session but currentVisit exists,
            // it means we need to sync the state
            if !matchingVisit.isActiveSession && isCurrentlyInOffice {
                debugLog("[AppData] Syncing current visit state with session management")
                var updatedVisit = matchingVisit
                updatedVisit.startNewSession()
                var updatedVisits = visits
                updatedVisits[matchingIndex] = updatedVisit
                return (updatedVisits, updatedVisit, true, false, true)
            }

            return (visits, currentVisit, isCurrentlyInOffice, false, false)
        } else {
            debugLog("[AppData] Current visit not found in visits array, adding it")
            var updatedVisits = visits
            updatedVisits.append(currentVisit)
            return (updatedVisits, currentVisit, isCurrentlyInOffice, false, true)
        }
    }
}
