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
    /// Add a visit with session management (mainly for manual entry and legacy compatibility)
    func addVisit(_ visit: OfficeVisit) -> Bool {
        let calendar = Calendar.current
        
        #if DEBUG
        print("[AppData] addVisit called for date: \(visit.date)")
        print("[AppData] Current visits array has \(visits.count) items")
        #endif
        
        // Check if a visit already exists for this day
        if let existingIndex = visits.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: visit.date) }) {
            let existingVisit = visits[existingIndex]
            
            // If existing visit has an active session, prevent duplicate
            if existingVisit.isActiveSession {
                print("[AppData] DUPLICATE PREVENTED: Active session already exists for this day")
                return false
            }
            
            // Replace existing completed visit with new one (for manual edits)
            visits[existingIndex] = visit
            print("[AppData] Replaced existing visit for \(visit.formattedDate)")
        } else {
            // No visit exists for this day, add new one
            visits.append(visit)
            print("[AppData] Added new visit for \(visit.formattedDate)")
        }
        
        saveVisits()
        #if DEBUG
        print("[AppData] Visits saved to UserDefaults")
        #endif
        return true
    }
    
    func startVisit(at location: CLLocationCoordinate2D) {
        let now = Date()
        let calendar = Calendar.current
        
        #if DEBUG
        print("[AppData] startVisit called at \(now)")
        print("[AppData] Current visits count: \(visits.count)")
        print("[AppData] Current visit exists: \(currentVisit != nil)")
        #endif
        
        // Session Management: Check if there's already a visit for today
        if let todayVisitIndex = visits.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: now) }) {
            var todayVisit = visits[todayVisitIndex]
            
            #if DEBUG
            print("[AppData] Found existing visit for today, managing session")
            #endif
            
            // If there's already an active session, don't create duplicate
            if todayVisit.isActiveSession {
                print("[AppData] DUPLICATE PREVENTED: Session already active for today")
                currentVisit = todayVisit
                isCurrentlyInOffice = true
                return
            }
            
            // Resume the session (start new event in existing visit)
            todayVisit.startNewSession(at: now)
            visits[todayVisitIndex] = todayVisit
            currentVisit = todayVisit
            isCurrentlyInOffice = true
            
            saveVisits()
            print("[AppData] Resumed office session for today")
            return
        }
        
        // No visit exists for today, create new one
        var newVisit = OfficeVisit(date: now, coordinate: location)
        newVisit.startNewSession(at: now)
        
        currentVisit = newVisit
        isCurrentlyInOffice = true
        
        // Add the visit to the array
        visits.append(newVisit)
        saveVisits()
        
        print("[AppData] Started new office session for today")
    }
    
    func endVisit() {
        guard var visit = currentVisit else { 
            print("[AppData] No current visit to end")
            return 
        }
        
        print("[AppData] Ending current session")
        
        let exitTime = Date()
        
        // End the current session in the visit
        visit.endCurrentSession(at: exitTime)
        
        // Update the visit in the array
        let calendar = Calendar.current
        if let index = visits.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: visit.date) }) {
            visits[index] = visit
        }
        
        saveVisits()
        
        if visit.isValidVisit {
            print("[AppData] Completed valid office session with total duration: \(visit.formattedDuration)")
        } else {
            print("[AppData] Completed session (\(visit.formattedDuration)), saved for record")
        }
        
        // Clear current visit state (session is paused, can be resumed later)
        currentVisit = nil
        isCurrentlyInOffice = false
        clearCurrentVisit()
        
        print("[AppData] Session ended successfully")
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
        
        // Count both valid visits (completed with 1+ hour total) and visits in progress
        let validVisits = allVisits.filter { $0.isValidVisit }
        let visitsInProgress = allVisits.filter { $0.isActiveSession } // Currently in office
        
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
    
    /// Clean up duplicate entries with session management awareness
    private func cleanupDuplicateEntries() {
        #if DEBUG
        print("[AppData] Starting duplicate cleanup with session management...")
        #endif
        
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
                print("[AppData] Found \(dayVisits.count) visits for \(dateKey) - consolidating into session")
                
                // Merge multiple visits for the same day into a single session-based visit
                if let consolidatedVisit = consolidateVisitsIntoSession(dayVisits) {
                    cleanedVisits.append(consolidatedVisit)
                    duplicatesRemoved += dayVisits.count - 1
                    print("[AppData] Consolidated \(dayVisits.count) visits into single session")
                }
            } else {
                cleanedVisits.append(dayVisits[0])
            }
        }
        
        if duplicatesRemoved > 0 {
            visits = cleanedVisits
            saveVisits()
            #if DEBUG
            print("[AppData] Cleanup complete: consolidated \(duplicatesRemoved) duplicate visits into sessions")
            #endif
        } else {
            #if DEBUG
            print("[AppData] No duplicates found")
            #endif
        }
    }
    
    /// Consolidate multiple visits for the same day into a single session-based visit
    private func consolidateVisitsIntoSession(_ dayVisits: [OfficeVisit]) -> OfficeVisit? {
        guard !dayVisits.isEmpty else { return nil }
        
        // Sort by entry time
        let sortedVisits = dayVisits.sorted { $0.entryTime < $1.entryTime }
        let firstVisit = sortedVisits[0]
        
        // Create new session-based visit starting with the first visit's data
        var consolidatedVisit = OfficeVisit(date: firstVisit.date, coordinate: firstVisit.coordinate)
        
        // Add events from all visits
        for visit in sortedVisits {
            // For legacy visits, create events from entry/exit times
            if let exitTime = visit.exitTime {
                let event = OfficeEvent(entryTime: visit.entryTime, exitTime: exitTime)
                consolidatedVisit.events.append(event)
            } else {
                // Incomplete visit - add as active session
                let event = OfficeEvent(entryTime: visit.entryTime, exitTime: nil)
                consolidatedVisit.events.append(event)
            }
        }
        
        return consolidatedVisit
    }
    
    /// Validate that currentVisit is consistent with visits array (session management aware)
    private func validateCurrentVisitConsistency() {
        guard let currentVisit = currentVisit else {
            #if DEBUG
            print("[AppData] No current visit to validate")
            #endif
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
        
        // Check if there's a matching visit in the array
        if let matchingIndex = visits.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: currentVisit.date) }) {
            let matchingVisit = visits[matchingIndex]
            
            // If the visit in array doesn't have an active session but currentVisit exists,
            // it means we need to sync the state
            if !matchingVisit.isActiveSession && isCurrentlyInOffice {
                print("[AppData] Syncing current visit state with session management")
                var updatedVisit = matchingVisit
                updatedVisit.startNewSession()
                visits[matchingIndex] = updatedVisit
                self.currentVisit = updatedVisit
            }
        } else {
            print("[AppData] Current visit not found in visits array, adding it")
            visits.append(currentVisit)
            saveVisits()
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
        // Test data functionality disabled for production
        // Only add test data in development when explicitly needed
        // if visits.isEmpty {
        //     // Test data code removed for production
        // }
    }
    #endif
}