//
//  HistoricalRepairRunner.swift
//  InOfficeDaysTracker
//
//  Handles repair of historical sessions with spurious splits.
//

import Foundation

final class HistoricalRepairRunner {
    private let sharedUserDefaults: UserDefaults

    // Repair configuration constants (from AppData)
    private static let repairGapThreshold: TimeInterval = 90 * 60 // 90 minutes
    private static let repairDebounceInterval: TimeInterval = 60 * 60 // 1 hour
    private static let repairDateRangeDays: Int = 30 // Last 30 days

    init(sharedUserDefaults: UserDefaults) {
        self.sharedUserDefaults = sharedUserDefaults
    }

    /// Trigger foreground repair when app becomes active.
    func triggerForegroundRepair(visits: [OfficeVisit]) -> ([OfficeVisit], Int) {
        performHistoricalSessionRepairIfNeeded(visits: visits)
    }

    /// One-time migration to repair historical sessions with spurious splits.
    private func performHistoricalSessionRepairIfNeeded(visits: [OfficeVisit]) -> ([OfficeVisit], Int) {
        let repairKey = "HistoricalSessionRepairLastRun"

        if let lastRepairTime = sharedUserDefaults.object(forKey: repairKey) as? Date {
            let timeSinceLastRepair = Date().timeIntervalSince(lastRepairTime)
            if timeSinceLastRepair < Self.repairDebounceInterval {
                debugLog("ℹ️", "[AppData] Historical session repair run recently (\(Int(timeSinceLastRepair/60))m ago), skipping")
                return (visits, 0)
            }
        }

        debugLog("🔧", "[AppData] Running historical session repair for recent data...")

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -Self.repairDateRangeDays, to: Date()) ?? Date()

        let (repairedVisits, repairedCount) = repairHistoricalSessions(
            visits: visits,
            gapThreshold: Self.repairGapThreshold,
            dateFilter: cutoffDate
        )

        if repairedCount > 0 {
            debugLog("✅", "[AppData] Historical repair completed: fixed \(repairedCount) recent visits")
        }

        sharedUserDefaults.set(Date(), forKey: repairKey)
        sharedUserDefaults.synchronize()

        return (repairedVisits, repairedCount)
    }

    /// Repair historical sessions by merging events with short gaps (likely GPS drift).
    func repairHistoricalSessions(visits: [OfficeVisit], gapThreshold: TimeInterval = 5400, dateFilter: Date? = nil) -> ([OfficeVisit], Int) {
        var repairCount = 0
        var repairedVisits: [OfficeVisit] = []

        debugLog("🔧", "[AppData] Starting historical session repair (gap threshold: \(Int(gapThreshold/60)) minutes)")

        let visitsToRepair = if let cutoffDate = dateFilter {
            visits.filter { $0.date >= cutoffDate }
        } else {
            visits
        }

        if visitsToRepair.isEmpty {
            debugLog("ℹ️", "[AppData] No visits in range to repair")
            return (visits, 0)
        }

        debugLog("ℹ️", "[AppData] Checking \(visitsToRepair.count) visits for repair")

        for visit in visits {
            if let cutoffDate = dateFilter, visit.date < cutoffDate {
                repairedVisits.append(visit)
                continue
            }

            guard visit.events.count > 1, !visit.isActiveSession else {
                repairedVisits.append(visit)
                continue
            }

            let sortedEvents = visit.events.sorted { $0.entryTime < $1.entryTime }
            var mergedEvents: [OfficeEvent] = []
            var currentMergedEvent: OfficeEvent? = nil

            for event in sortedEvents {
                guard let exitTime = event.exitTime else {
                    if let merged = currentMergedEvent {
                        mergedEvents.append(merged)
                    }
                    mergedEvents.append(event)
                    currentMergedEvent = nil
                    continue
                }

                if let merged = currentMergedEvent, let mergedExit = merged.exitTime {
                    let gap = event.entryTime.timeIntervalSince(mergedExit)

                    if gap <= gapThreshold && gap >= 0 {
                        currentMergedEvent = OfficeEvent(
                            entryTime: merged.entryTime,
                            exitTime: exitTime
                        )
                        debugLog("🔧", "[AppData] Merged events with \(Int(gap/60))m gap")
                    } else {
                        mergedEvents.append(merged)
                        currentMergedEvent = event
                    }
                } else {
                    currentMergedEvent = event
                }
            }

            if let merged = currentMergedEvent {
                mergedEvents.append(merged)
            }

            if mergedEvents.count < sortedEvents.count {
                var repairedVisit = visit
                repairedVisit.events = mergedEvents
                repairedVisits.append(repairedVisit)
                repairCount += 1

                debugLog("✅", "[AppData] Repaired visit on \(visit.formattedDate): \(sortedEvents.count) events → \(mergedEvents.count) events")
            } else {
                repairedVisits.append(visit)
            }
        }

        if repairCount > 0 {
            debugLog("✅", "[AppData] Historical repair complete: fixed \(repairCount) visits")
        } else {
            debugLog("ℹ️", "[AppData] No visits needed repair")
        }

        return (repairedVisits, repairCount)
    }
}
