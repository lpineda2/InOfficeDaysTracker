//
//  AppData.swift (Updated Version)
//  InOfficeDaysTracker
//
//  Updated to add status persistence and improve visit management
//

import Foundation
import CoreLocation
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
class AppData: ObservableObject {
    @Published var settings = AppSettings()
    @Published var visits: [OfficeVisit] = []
    @Published var currentVisit: OfficeVisit? {
        didSet {
            saveCurrentVisit()
        }
    }
    @Published var isCurrentlyInOffice = false {
        didSet {
            // Persist office status to handle app restarts
            sharedUserDefaults.set(isCurrentlyInOffice, forKey: "IsCurrentlyInOffice")
            updateWidgetData()
        }
    }
    
    // Shared UserDefaults for app group (widget access)
    let sharedUserDefaults = UserDefaults(suiteName: "group.com.lpineda.InOfficeDaysTracker") ?? UserDefaults.standard
    
    // Calendar Integration
    private let calendarEventManager = CalendarEventManager()
    
    private let settingsKey = "AppSettings"
    private let visitsKey = "OfficeVisits"
    private let currentVisitKey = "CurrentVisit"
    private let widgetDataKey = "WidgetData"
    
    init() {
        // CRITICAL: Migrate data from standard UserDefaults to App Groups
        migrateDataFromStandardUserDefaults()
        
        loadSettings()
        loadVisits()
        loadCurrentStatus()
        
        // Setup calendar integration
        // Note: AppDataAccess removed in simplification
        
        // CRITICAL: Clean up any duplicate entries on startup
        cleanupDuplicateEntries()
        
        // Validate current visit consistency
        validateCurrentVisitConsistency()
        
        // Debug: Add test data if no visits exist
        #if DEBUG
        addTestDataIfNeeded()
        #endif
        
        // Perform calendar catch-up sync if enabled
        // Note: Catch-up sync removed in simplification
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: AppSettings) {
        print("🔧 [AppData] updateSettings called")
        print("  - Calendar enabled: \(newSettings.calendarSettings.isEnabled)")
        print("  - Calendar ID: \(newSettings.calendarSettings.selectedCalendarId ?? "none")")
        
        let wasCalendarEnabled = settings.calendarSettings.isEnabled
        let isCalendarNowEnabled = newSettings.calendarSettings.isEnabled
        
        settings = newSettings
        saveSettings()
        
        // If calendar integration was just enabled and there's an active office visit,
        // create a calendar event for the current visit
        if !wasCalendarEnabled && isCalendarNowEnabled {
            print("  📅 Calendar integration was just enabled!")
            if let activeVisit = currentVisit, activeVisit.isActiveSession {
                print("  📅 Found active office visit - creating calendar event")
                Task {
                    await calendarEventManager.handleVisitStart(activeVisit, settings: settings)
                }
            } else {
                print("  📅 No active visit to create calendar event for")
            }
        }
        
        print("  ✅ Settings updated and saved")
    }
    
    func completeSetup() {
        settings.isSetupComplete = true
        saveSettings()
    }
    
    private func saveSettings() {
        print("💾 [AppData] saveSettings called")
        print("  📋 Settings to save:")
        print("    - Calendar enabled: \(settings.calendarSettings.isEnabled)")
        print("    - Calendar ID: \(settings.calendarSettings.selectedCalendarId ?? "none")")
        print("    - Setup complete: \(settings.isSetupComplete)")
        
        if let encoded = try? JSONEncoder().encode(settings) {
            sharedUserDefaults.set(encoded, forKey: settingsKey)
            print("  ✅ Settings encoded and saved to UserDefaults")
            
            // Verify the data was actually written
            if let savedData = sharedUserDefaults.data(forKey: settingsKey) {
                print("  📄 Saved data size: \(savedData.count) bytes")
                if let jsonString = String(data: savedData, encoding: .utf8) {
                    print("  📄 JSON preview: \(String(jsonString.prefix(200)))...")
                }
            } else {
                print("  ❌ No data found immediately after saving!")
            }
        } else {
            print("  ❌ Failed to encode settings")
        }
    }
    
    private func loadSettings() {
        print("🔍 [AppData] loadSettings called")
        
        if let data = sharedUserDefaults.data(forKey: settingsKey) {
            print("  📄 Found settings data: \(data.count) bytes")
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("  📄 JSON preview: \(String(jsonString.prefix(200)))...")
            }
            
            if let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
                settings = decoded
                print("  ✅ Settings loaded successfully")
                print("  📅 Calendar enabled: \(settings.calendarSettings.isEnabled)")
                print("  📅 Calendar ID: \(settings.calendarSettings.selectedCalendarId ?? "none")")
                print("  📅 Setup complete: \(settings.isSetupComplete)")
            } else {
                print("  ❌ Failed to decode settings JSON!")
                settings = AppSettings()
            }
        } else {
            print("  ⚠️ No settings data found in UserDefaults")
            settings = AppSettings()
        }
    }
    
    // MARK: - Status Persistence
    
    private func loadCurrentStatus() {
        // Restore office status and current visit from persistent storage
        isCurrentlyInOffice = sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        
        if let data = sharedUserDefaults.data(forKey: currentVisitKey),
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
                
                // Check if calendar event should be created for current visit
                Task {
                    await ensureCalendarEventForCurrentVisit(visit)
                }
            }
        }
    }
    
    private func saveCurrentVisit() {
        if let visit = currentVisit,
           let encoded = try? JSONEncoder().encode(visit) {
            sharedUserDefaults.set(encoded, forKey: currentVisitKey)
        } else {
            // Clear persisted current visit when currentVisit is nil
            sharedUserDefaults.removeObject(forKey: currentVisitKey)
        }
    }
    
    private func clearCurrentVisit() {
        sharedUserDefaults.removeObject(forKey: currentVisitKey)
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
            
            // Handle calendar event update
            Task {
                await calendarEventManager.handleVisitUpdate(todayVisit, settings: settings)
            }
            
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
        
        // Handle calendar event creation
        print("[AppData] About to call calendar event manager...")
        Task {
            await calendarEventManager.handleVisitStart(newVisit, settings: settings)
        }
        
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
        
        // Handle calendar event end
        Task {
            await calendarEventManager.handleVisitEnd(visit, settings: settings)
        }
        
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
            sharedUserDefaults.set(encoded, forKey: visitsKey)
        }
        updateWidgetData()
    }
    
    private func loadVisits() {
        if let data = sharedUserDefaults.data(forKey: visitsKey),
           let decoded = try? JSONDecoder().decode([OfficeVisit].self, from: data) {
            visits = decoded
        }
    }
    
    // MARK: - Widget Data Management
    
    /// Update widget data whenever app data changes
    private func updateWidgetData() {
        print("✅ [AppData] Triggering widget timeline reload")
        print("🔄 [AppData] Current state: isInOffice=\(isCurrentlyInOffice), visits=\(getCurrentMonthProgress().current)")
        
        // Force UserDefaults synchronization to ensure data is written immediately
        sharedUserDefaults.synchronize()
        
        // Verify the data was persisted correctly
        let verifyStatus = sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice") 
        print("🔍 [AppData] Verified persisted office status: \(verifyStatus)")
        
        // Request widget timeline reload with multiple strategies for reliability
        #if canImport(WidgetKit)
        Task {
            await MainActor.run {
                // Strategy 1: Reload all timelines
                WidgetCenter.shared.reloadAllTimelines()
                
                // Strategy 2: Also reload specific widget configuration
                WidgetCenter.shared.reloadTimelines(ofKind: "OfficeTrackerWidget")
                
                print("🔄 [AppData] Widget reload requests sent (all + specific)")
                
                // Strategy 3: Multiple delayed reloads to handle iOS widget caching issues
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    WidgetCenter.shared.reloadAllTimelines()
                    print("🔄 [AppData] First delayed widget reload request sent")
                    
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    WidgetCenter.shared.reloadAllTimelines()
                    print("🔄 [AppData] Second delayed widget reload request sent")
                }
            }
        }
        #else
        print("⚠️ [AppData] WidgetKit not available")
        #endif
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
    
    // MARK: - Widget Helper Methods
    
    private func getCurrentMonthName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    private func calculateWeeklyProgress() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        let validVisits = visits.filter { visit in
            visit.isValidVisit && visit.date >= weekStart
        }
        
        let visitsInProgress = visits.filter { visit in
            visit.duration == nil && visit.date >= weekStart
        }
        
        return validVisits.count + visitsInProgress.count
    }
    
    private func calculateAverageDuration() -> Double {
        let validVisits = getValidVisits(for: Date())
        guard !validVisits.isEmpty else { return 0.0 }
        
        let totalDuration = validVisits.compactMap { $0.duration }.reduce(0, +)
        let count = Double(validVisits.count)
        guard count > 0 else { return 0.0 }
        
        let average = (totalDuration / count) / 3600 // Convert to hours
        guard !average.isNaN && !average.isInfinite else { return 0.0 }
        return average
    }
    
    private func calculatePaceNeeded(current: Int, goal: Int) -> String {
        let remaining = max(0, goal - current)
        let daysLeft = getDaysRemainingInMonth()
        
        guard daysLeft > 0 && remaining > 0 else { 
            if remaining <= 0 {
                return "Goal complete!"
            } else {
                return "0.0 days/week"
            }
        }
        
        let workingDaysPerWeek = settings.trackingDays.count
        guard workingDaysPerWeek > 0 else { return "No tracking days set" }
        
        let dailyRate = Double(remaining) / Double(daysLeft)
        guard !dailyRate.isNaN && !dailyRate.isInfinite else { return "0.0 days/week" }
        
        let weeklyRate = dailyRate * Double(workingDaysPerWeek)
        
        if weeklyRate > Double(workingDaysPerWeek) {
            return "Goal unreachable"
        } else {
            return String(format: "%.1f days/week", weeklyRate)
        }
    }
    
    private func getDaysRemainingInMonth() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end else { return 0 }
        var count = 0
        var date = now

        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if settings.trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return count
    }
    
    private func generateStatusMessage(current: Int, goal: Int, isCurrentlyInOffice: Bool) -> String {
        let remaining = max(0, goal - current)
        
        if remaining == 0 {
            return "Goal achieved! 🎉"
        } else if isCurrentlyInOffice {
            return "Currently in office"
        } else if remaining == 1 {
            return "1 more day needed"
        } else {
            return "\(remaining) more days needed"
        }
    }

    // MARK: - Data Migration
    
    /// Migrate data from standard UserDefaults to App Groups container
    /// This fixes data loss when upgrading from pre-widget versions
    private func migrateDataFromStandardUserDefaults() {
        let standardDefaults = UserDefaults.standard
        let migrationKey = "DataMigratedToAppGroups_v1.6.0"
        
        // Check if migration already completed
        if sharedUserDefaults.bool(forKey: migrationKey) {
            print("[AppData] Data migration already completed")
            return
        }
        
        print("[AppData] Starting data migration from standard UserDefaults...")
        var migrationCount = 0
        
        // Migrate settings
        if let settingsData = standardDefaults.data(forKey: settingsKey),
           sharedUserDefaults.data(forKey: settingsKey) == nil {
            sharedUserDefaults.set(settingsData, forKey: settingsKey)
            migrationCount += 1
            print("[AppData] Migrated app settings")
        }
        
        // Migrate visits
        if let visitsData = standardDefaults.data(forKey: visitsKey),
           sharedUserDefaults.data(forKey: visitsKey) == nil {
            sharedUserDefaults.set(visitsData, forKey: visitsKey)
            migrationCount += 1
            print("[AppData] Migrated office visits history")
        }
        
        // Migrate current visit
        if let currentVisitData = standardDefaults.data(forKey: currentVisitKey),
           sharedUserDefaults.data(forKey: currentVisitKey) == nil {
            sharedUserDefaults.set(currentVisitData, forKey: currentVisitKey)
            migrationCount += 1
            print("[AppData] Migrated current visit state")
        }
        
        // Migrate office status
        if standardDefaults.object(forKey: "IsCurrentlyInOffice") != nil,
           sharedUserDefaults.object(forKey: "IsCurrentlyInOffice") == nil {
            let isInOffice = standardDefaults.bool(forKey: "IsCurrentlyInOffice")
            sharedUserDefaults.set(isInOffice, forKey: "IsCurrentlyInOffice")
            migrationCount += 1
            print("[AppData] Migrated office status: \(isInOffice)")
        }
        
        // Mark migration as complete
        sharedUserDefaults.set(true, forKey: migrationKey)
        
        print("[AppData] Migration completed! Migrated \(migrationCount) data items")
        
        if migrationCount > 0 {
            print("[AppData] ✅ Your previous app data has been restored!")
        }
    }
    
    // MARK: - Calendar Integration
    
    private func ensureCalendarEventForCurrentVisit(_ visit: OfficeVisit) async {
        guard settings.calendarSettings.isEnabled,
              visit.isActiveSession else {
            return
        }
        
        print("📅 [AppData] Ensuring calendar event exists for current visit")
        await calendarEventManager.handleVisitUpdate(visit, settings: settings)
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