//
//  DuplicateCleanupRunner.swift
//  InOfficeDaysTracker
//
//  Handles deduplication and consolidation of visits.
//

import Foundation

final class DuplicateCleanupRunner {
    /// Clean up duplicate entries by consolidating multiple visits for the same day.
    /// Returns the cleaned visits array.
    func cleanupDuplicateEntries(from visits: [OfficeVisit]) -> ([OfficeVisit], Int) {
        var visitsByDate: [String: [OfficeVisit]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for visit in visits {
            let dateKey = dateFormatter.string(from: visit.date)
            if visitsByDate[dateKey] == nil {
                visitsByDate[dateKey] = []
            }
            visitsByDate[dateKey]?.append(visit)
        }

        var cleanedVisits: [OfficeVisit] = []
        var duplicatesRemoved = 0

        for (dateKey, dayVisits) in visitsByDate {
            if dayVisits.count > 1 {
                debugLog("[AppData] Found \(dayVisits.count) visits for \(dateKey) - consolidating into session")

                if let consolidatedVisit = consolidateVisitsIntoSession(dayVisits) {
                    cleanedVisits.append(consolidatedVisit)
                    duplicatesRemoved += dayVisits.count - 1
                    debugLog("[AppData] Consolidated \(dayVisits.count) visits into single session")
                }
            } else {
                cleanedVisits.append(dayVisits[0])
            }
        }

        if duplicatesRemoved > 0 {
            debugLog("[AppData] Cleanup complete: consolidated \(duplicatesRemoved) duplicate visits into sessions")
        } else {
            debugLog("[AppData] No duplicates found")
        }

        return (cleanedVisits, duplicatesRemoved)
    }

    /// Consolidate multiple visits for the same day into a single session-based visit.
    private func consolidateVisitsIntoSession(_ dayVisits: [OfficeVisit]) -> OfficeVisit? {
        guard !dayVisits.isEmpty else { return nil }

        let sortedVisits = dayVisits.sorted { $0.entryTime < $1.entryTime }
        let firstVisit = sortedVisits[0]

        var consolidatedVisit = OfficeVisit(date: firstVisit.date, coordinate: firstVisit.coordinate)

        for visit in sortedVisits {
            if let exitTime = visit.exitTime {
                let event = OfficeEvent(entryTime: visit.entryTime, exitTime: exitTime)
                consolidatedVisit.events.append(event)
            } else {
                let event = OfficeEvent(entryTime: visit.entryTime, exitTime: nil)
                consolidatedVisit.events.append(event)
            }
        }

        return consolidatedVisit
    }
}
