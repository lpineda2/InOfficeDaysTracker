//
//  AppData.swift (Updated Version)
//  InOfficeDaysTracker
//
//  Updated to add status persistence and improve visit management
//

import Foundation
import CoreLocation

@MainActor
class AppData: ObservableObject {
    @Published var settings = AppSettings()
    @Published var visits: [OfficeVisit] = []
    @Published var currentVisit: OfficeVisit?
    @Published var isCurrentlyInOffice = false {
        didSet {
            // Persist office status to handle app restarts
            UserDefaults.standard.set(isCurrentlyInOffice, forKey: "IsCurrentlyInOffice")
            saveCurrentVisit()
        }
    }
    
    private let settingsKey = "AppSettings"
    private let visitsKey = "OfficeVisits"
    private let currentVisitKey = "CurrentVisit"
    
    init() {
        loadSettings()
        loadVisits()
        loadCurrentStatus()
        
        // CRITICAL: Clean up any duplicate entries on startup
        cleanupDuplicateEntries()
        
        // Validate current visit consistency
        validateCurrentVisitConsistency()
        
        // Debug: Add test data if no visits exist
        #if DEBUG
        addTestDataIfNeeded()
        #endif
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        saveSettings()
    }
    
    func completeSetup() {
        settings.isSetupComplete = true
        saveSettings()
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
    }
    
    // MARK: - Status Persistence
    
    private func loadCurrentStatus() {
        // Restore office status and current visit from persistent storage
        isCurrentlyInOffice = UserDefaults.standard.bool(forKey: "IsCurrentlyInOffice")
        
        if let data = UserDefaults.standard.data(forKey: currentVisitKey),
           let visit = try? JSONDecoder().decode(OfficeVisit.self, from: data) {
            currentVisit = visit
            
            // Validate that the current visit is from today
            let calendar = Calendar.current
            if !calendar.isDate(visit.date, inSameDayAs: Date()) {
                // Current visit is from a previous day, clear it
                currentVisit = nil
                isCurrentlyInOffice = false
                clearCurrentVisit()
                print("[AppData] Cleared stale visit from previous day")
            } else {
                print("[AppData] Restored current visit from: \(visit.entryTime)")
            }
        }
    }
    
    private func saveCurrentVisit() {
        if let visit = currentVisit,
           let encoded = try? JSONEncoder().encode(visit) {
            UserDefaults.standard.set(encoded, forKey: currentVisitKey)
        }
    }
    
    private func clearCurrentVisit() {
        UserDefaults.standard.removeObject(forKey: currentVisitKey)
    }
    
    // MARK: - Visit Management
    
    /// Add a visit with improved duplicate handling
    func addVisit(_ visit: OfficeVisit) -> Bool {
        let calendar = Calendar.current
        
        print("[AppData] addVisit called for date: \(visit.date)")
        print("[AppData] Current visits array has \(visits.count) items")
        
        // Remove any existing incomplete visit for today before adding new one
        let beforeRemovalCount = visits.count
        visits.removeAll { existingVisit in
            let isSameDay = calendar.isDate(existingVisit.date, inSameDayAs: visit.date)
            let isIncomplete = existingVisit.duration == nil
            if isSameDay && isIncomplete {
                print("[AppData] Removing incomplete visit from \(existingVisit.entryTime)")
            }
            return isSameDay && isIncomplete
        }
        let afterRemovalCount = visits.count
        
        if beforeRemovalCount != afterRemovalCount {
            print("[AppData] Removed \(beforeRemovalCount - afterRemovalCount) incomplete visits")
        }
        
        // Check if a completed visit for this day already exists
        let existingCompletedVisits = visits.filter { 
            calendar.isDate($0.date, inSameDayAs: visit.date) && $0.duration != nil 
        }
        
        if !existingCompletedVisits.isEmpty {
            print("[AppData] DUPLICATE PREVENTED: \(existingCompletedVisits.count) completed visit(s) already exist for this day")
            return false // Completed visit already exists for today
        }
        
        visits.append(visit)
        print("[AppData] Visit added to array. New count: \(visits.count)")
        
        saveVisits()
        print("[AppData] Visits saved to UserDefaults")
        return true
    }
    
    func startVisit(at location: CLLocationCoordinate2D) {
        let now = Date()
        let calendar = Calendar.current
        
        print("[AppData] startVisit called at \(now)")
        print("[AppData] Current visits count: \(visits.count)")
        print("[AppData] Current visit exists: \(currentVisit != nil)")
        
        // CRITICAL: Check if we already have an active visit for today
        if let currentVisit = currentVisit {
            if calendar.isDate(currentVisit.date, inSameDayAs: now) {
                print("[AppData] DUPLICATE PREVENTED: Already have active visit for today")
                return
            } else {
                print("[AppData] Current visit is from different day, clearing it")
                self.currentVisit = nil
                clearCurrentVisit()
            }
        }
        
        // Check for existing completed visit today
        let existingCompletedVisit = visits.first { 
            calendar.isDate($0.date, inSameDayAs: now) && $0.duration != nil 
        }
        
        if existingCompletedVisit != nil {
            print("[AppData] DUPLICATE PREVENTED: Already have completed visit for today")
            return
        }
        
        // Clean up any incomplete visits for today (defensive cleanup)
        let beforeCount = visits.count
        visits.removeAll { visit in
            calendar.isDate(visit.date, inSameDayAs: now) && visit.duration == nil
        }
        let afterCount = visits.count
        if beforeCount != afterCount {
            print("[AppData] Cleaned up \(beforeCount - afterCount) incomplete visits for today")
            saveVisits()
        }
        
        let visit = OfficeVisit(
            date: now,
            entryTime: now,
            coordinate: location
        )
        
        // Set current visit BEFORE adding to array to prevent race conditions
        currentVisit = visit
        isCurrentlyInOffice = true
        
        // Add the visit
        let wasAdded = addVisit(visit)
        print("[AppData] Visit added to array: \(wasAdded)")
        print("[AppData] Total visits after adding: \(visits.count)")
        print("[AppData] Started office visit at \(now)")
    }
    
    func endVisit() {
        guard let visit = currentVisit else { 
            print("[AppData] No current visit to end")
            return 
        }
        
        print("[AppData] Ending visit that started at \(visit.entryTime)")
        
        let exitTime = Date()
        let duration = exitTime.timeIntervalSince(visit.entryTime)
        
        let completedVisit = OfficeVisit(
            date: visit.date,
            entryTime: visit.entryTime,
            exitTime: exitTime,
            duration: duration,
            coordinate: visit.coordinate
        )
        
        // Replace any existing visit for today with the completed one
        let calendar = Calendar.current
        let beforeCount = visits.count
        visits.removeAll { existingVisit in
            calendar.isDate(existingVisit.date, inSameDayAs: visit.date)
        }
        let afterCount = visits.count
        
        if beforeCount != afterCount {
            print("[AppData] Removed \(beforeCount - afterCount) existing visits for today")
        }
        
        // Always save visits with exit time, regardless of duration
        // This ensures we don't lose exit events even for short visits
        visits.append(completedVisit)
        saveVisits()
        
        if completedVisit.isValidVisit {
            print("[AppData] Completed valid office visit with duration: \(completedVisit.formattedDuration)")
        } else {
            print("[AppData] Completed short visit (\(completedVisit.formattedDuration)), but saving for record")
        }
        
        // Clear current visit state
        currentVisit = nil
        isCurrentlyInOffice = false
        clearCurrentVisit()
        
        print("[AppData] Visit ended successfully")
    }

    private func addTodayAsOfficeDay(at location: CLLocationCoordinate2D) {
        let today = Date()
        let calendar = Calendar.current
        
        // Check if we already have a visit for today
        let todayVisits = visits.filter { calendar.isDate($0.date, inSameDayAs: today) }
        
        if todayVisits.isEmpty {
            // Add a placeholder visit for today that will be updated when we leave
            let placeholderVisit = OfficeVisit(
                date: today,
                entryTime: today,
                coordinate: location
            )
            visits.append(placeholderVisit)
            saveVisits()
        }
    }
    
    func getVisits(for month: Date) -> [OfficeVisit] {
        let calendar = Calendar.current
        return visits.filter { visit in
            calendar.isDate(visit.date, equalTo: month, toGranularity: .month)
        }
    }
    
    func getValidVisits(for month: Date) -> [OfficeVisit] {
        return getVisits(for: month).filter { $0.isValidVisit }
    }
    
    func getCurrentMonthProgress() -> (current: Int, goal: Int, percentage: Double) {
        let currentMonth = Date()
        let allVisits = getVisits(for: currentMonth)
        
        // Count both valid visits (completed with 1+ hour) and visits in progress
        let validVisits = allVisits.filter { $0.isValidVisit }
        let visitsInProgress = allVisits.filter { $0.duration == nil } // Currently in office
        
        let current = validVisits.count + visitsInProgress.count
        let goal = settings.monthlyGoal
        let percentage = goal > 0 ? Double(current) / Double(goal) : 0.0
        return (current, goal, min(percentage, 1.0))
    }
    
    private func saveVisits() {
        if let encoded = try? JSONEncoder().encode(visits) {
            UserDefaults.standard.set(encoded, forKey: visitsKey)
        }
    }
    
    private func loadVisits() {
        if let data = UserDefaults.standard.data(forKey: visitsKey),
           let decoded = try? JSONDecoder().decode([OfficeVisit].self, from: data) {
            visits = decoded
        }
    }
    
    // MARK: - Utility Methods
    
    /// Clean up duplicate entries that may have been created
    private func cleanupDuplicateEntries() {
        print("[AppData] Starting duplicate cleanup...")
        let _ = visits.count // Suppress warning
        let _ = Calendar.current // Suppress warning
        
        // Group visits by date
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
                print("[AppData] Found \(dayVisits.count) visits for \(dateKey)")
                
                // Prioritize: completed visits over incomplete, then latest entry time
                let sortedVisits = dayVisits.sorted { visit1, visit2 in
                    // Completed visits come first
                    if (visit1.duration != nil) != (visit2.duration != nil) {
                        return visit1.duration != nil
                    }
                    // Then by entry time (latest first)
                    return visit1.entryTime > visit2.entryTime
                }
                
                // Keep only the best visit for each day
                if let bestVisit = sortedVisits.first {
                    cleanedVisits.append(bestVisit)
                    duplicatesRemoved += dayVisits.count - 1
                    print("[AppData] Kept visit from \(bestVisit.entryTime), removed \(dayVisits.count - 1) duplicates")
                }
            } else {
                cleanedVisits.append(dayVisits[0])
            }
        }
        
        if duplicatesRemoved > 0 {
            visits = cleanedVisits
            saveVisits()
            print("[AppData] Cleanup complete: removed \(duplicatesRemoved) duplicates, kept \(cleanedVisits.count) visits")
        } else {
            print("[AppData] No duplicates found")
        }
    }
    
    /// Validate that currentVisit is consistent with visits array
    private func validateCurrentVisitConsistency() {
        guard let currentVisit = currentVisit else {
            print("[AppData] No current visit to validate")
            return
        }
        
        let calendar = Calendar.current
        let today = Date()
        
        // Check if current visit is from today
        if !calendar.isDate(currentVisit.date, inSameDayAs: today) {
            print("[AppData] Current visit is from wrong day, clearing it")
            self.currentVisit = nil
            isCurrentlyInOffice = false
            clearCurrentVisit()
            return
        }
        
        // Check if there's a matching incomplete visit in the array
        let matchingVisits = visits.filter { visit in
            calendar.isDate(visit.date, inSameDayAs: currentVisit.date) && 
            visit.entryTime == currentVisit.entryTime &&
            visit.duration == nil
        }
        
        if matchingVisits.isEmpty {
            print("[AppData] Current visit not found in visits array, adding it")
            _ = addVisit(currentVisit)
        } else if matchingVisits.count > 1 {
            print("[AppData] Multiple matching visits found, cleaning up")
            // Remove duplicates and keep one
            visits.removeAll { visit in
                calendar.isDate(visit.date, inSameDayAs: currentVisit.date) && visit.duration == nil
            }
            _ = addVisit(currentVisit)
        } else {
            print("[AppData] Current visit is properly synced with visits array")
        }
    }
    
    func deleteVisit(_ visit: OfficeVisit) {
        visits.removeAll { $0.id == visit.id }
        saveVisits()
    }
    
    func clearAllData() {
        visits.removeAll()
        currentVisit = nil
        isCurrentlyInOffice = false
        settings = AppSettings()
        saveVisits()
        saveSettings()
        clearCurrentVisit()
    }
    
    #if DEBUG
    private func addTestDataIfNeeded() {
        // Only add test data if no visits exist
        if visits.isEmpty {
            print("[DEBUG] Adding test visits for debugging export functionality")
            
            let calendar = Calendar.current
            let now = Date()
            
            // Create a few test visits from the past week
            for i in 1...5 {
                if let pastDate = calendar.date(byAdding: .day, value: -i, to: now),
                   let entryTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: pastDate),
                   let exitTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: pastDate) {
                    
                    let duration = exitTime.timeIntervalSince(entryTime)
                    let testVisit = OfficeVisit(
                        date: pastDate,
                        entryTime: entryTime,
                        exitTime: exitTime,
                        duration: duration,
                        coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                    )
                    visits.append(testVisit)
                }
            }
            saveVisits()
        }
    }
    #endif
}