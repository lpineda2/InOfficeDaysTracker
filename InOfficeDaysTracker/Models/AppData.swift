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
        
        // Remove any existing incomplete visit for today before adding new one
        visits.removeAll { existingVisit in
            calendar.isDate(existingVisit.date, inSameDayAs: visit.date) && existingVisit.duration == nil
        }
        
        // Check if a completed visit for this day already exists
        if visits.contains(where: { calendar.isDate($0.date, inSameDayAs: visit.date) && $0.duration != nil }) {
            return false // Completed visit already exists for today
        }
        
        visits.append(visit)
        saveVisits()
        return true
    }
    
    func startVisit(at location: CLLocationCoordinate2D) {
        let now = Date()
        let calendar = Calendar.current
        
        // Improve duplicate handling - allow re-entry on same day if previous visit was completed
        let existingTodayVisit = visits.first { calendar.isDate($0.date, inSameDayAs: now) }
        
        // If there's already a completed visit today, don't start a new one
        // But if there's an incomplete visit, we can update it
        if let existing = existingTodayVisit, existing.duration != nil {
            print("[AppData] Already have a completed visit for today")
            return
        }
        
        // Remove any incomplete visits for today
        visits.removeAll { visit in
            calendar.isDate(visit.date, inSameDayAs: now) && visit.duration == nil
        }
        
        let visit = OfficeVisit(
            date: now,
            entryTime: now,
            coordinate: location
        )
        currentVisit = visit
        isCurrentlyInOffice = true
        
        // Add the visit
        _ = addVisit(visit)
        print("[AppData] Started office visit at \(now)")
    }
    
    func endVisit() {
        guard let visit = currentVisit else { 
            print("[AppData] No current visit to end")
            return 
        }
        
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
        visits.removeAll { existingVisit in
            calendar.isDate(existingVisit.date, inSameDayAs: visit.date)
        }
        
        // Only save valid visits (at least 1 hour)
        if completedVisit.isValidVisit {
            visits.append(completedVisit)
            saveVisits()
            print("[AppData] Completed valid office visit with duration: \(completedVisit.formattedDuration)")
        } else {
            print("[AppData] Visit too short (\(completedVisit.formattedDuration)), not saving")
        }
        
        currentVisit = nil
        isCurrentlyInOffice = false
        clearCurrentVisit()
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