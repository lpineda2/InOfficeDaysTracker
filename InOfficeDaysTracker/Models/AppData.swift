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
            sharedUserDefaults.set(isCurrentlyInOffice, forKey: AppGroupKeys.isCurrentlyInOfficeKey)
            updateWidgetData()
        }
    }
    
    // Shared UserDefaults for app group (widget access)
    let sharedUserDefaults: UserDefaults

    // Repository for visit persistence
    private let visitRepository: VisitRepository

    // Store for settings persistence
    private let settingsStore: SettingsStore

    // Runner for one-time migrations
    private let migrationRunner: AppDataMigrationRunner

    // Runners for repair and cleanup
    private let historicalRepairRunner: HistoricalRepairRunner
    private let duplicateCleanupRunner: DuplicateCleanupRunner

    // Validator for visit/session consistency
    private let visitSessionValidator: VisitSessionValidator

    // Calendar Integration
    private let calendarEventManager = CalendarEventManager()
    
    init(sharedUserDefaults: UserDefaults? = nil) {
        // Allow tests to inject a custom UserDefaults (isolated suite) to avoid cross-test races
        self.sharedUserDefaults = sharedUserDefaults ?? UserDefaults(suiteName: AppGroupKeys.appGroupSuiteName) ?? UserDefaults.standard
        self.visitRepository = VisitRepository(sharedUserDefaults: self.sharedUserDefaults)
        self.settingsStore = SettingsStore(sharedUserDefaults: self.sharedUserDefaults)
        self.migrationRunner = AppDataMigrationRunner(sharedUserDefaults: self.sharedUserDefaults, settingsUpdater: nil)
        self.historicalRepairRunner = HistoricalRepairRunner(sharedUserDefaults: self.sharedUserDefaults)
        self.duplicateCleanupRunner = DuplicateCleanupRunner()
        self.visitSessionValidator = VisitSessionValidator()
        // CRITICAL: Migrate data from standard UserDefaults to App Groups
        migrationRunner.migrateDataFromStandardUserDefaults()

        loadSettings()

        // Set up settings updater callback now that self is fully initialized
        migrationRunner.setSettingsUpdater { [weak self] updatedSettings in
            self?.settings = updatedSettings
            self?.saveSettings()
        }

        // Run v1.9.0 migration AFTER settings are loaded
        migrationRunner.migrateToMultipleOfficeLocations(currentSettings: settings)
        
        loadVisits()
        loadCurrentStatus()
        
        // Setup calendar integration
        // Note: AppDataAccess removed in simplification
        
        // CRITICAL: Clean up any duplicate entries on startup
        let (cleanedVisits, _) = duplicateCleanupRunner.cleanupDuplicateEntries(from: visits)
        visits = cleanedVisits

        // Repair historical sessions (one-time migration for v1.15.0)
        let (repairedVisits, _) = historicalRepairRunner.triggerForegroundRepair(visits: visits)
        visits = repairedVisits
        if cleanedVisits.count != visits.count || repairedVisits.count != visits.count {
            saveVisits()
        }
        
        // Validate current visit consistency
        let (validatedVisits, validatedCurrentVisit, validatedInOffice) = visitSessionValidator.validateCurrentVisitConsistency(
            currentVisit: currentVisit,
            visits: visits,
            isCurrentlyInOffice: isCurrentlyInOffice
        )
        if validatedVisits.count != visits.count || validatedCurrentVisit !== currentVisit || validatedInOffice != isCurrentlyInOffice {
            visits = validatedVisits
            currentVisit = validatedCurrentVisit
            isCurrentlyInOffice = validatedInOffice
            clearCurrentVisit()
            saveVisits()
        }
        
        // Debug: Add test data if no visits exist
        #if DEBUG
        addTestDataIfNeeded()
        #endif
        
        // Perform calendar catch-up sync if enabled
        // Note: Catch-up sync removed in simplification
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: AppSettings) {
        debugLog("🔧", "[AppData] updateSettings called")
        debugLog("  - Calendar enabled: \(newSettings.calendarSettings.isEnabled)")
        debugLog("  - Calendar ID: \(newSettings.calendarSettings.selectedCalendarId ?? "none")")
        
        let wasCalendarEnabled = settings.calendarSettings.isEnabled
        let isCalendarNowEnabled = newSettings.calendarSettings.isEnabled
        
        settings = newSettings
        saveSettings()
        
        // If calendar integration was just enabled and there's an active office visit,
        // create a calendar event for the current visit
        if !wasCalendarEnabled && isCalendarNowEnabled {
            debugLog("📅", "Calendar integration was just enabled!")
            if let activeVisit = currentVisit, activeVisit.isActiveSession {
                debugLog("📅", "Found active office visit - creating calendar event")
                Task {
                    await calendarEventManager.handleVisitStart(activeVisit, settings: settings)
                }
            } else {
                debugLog("📅", "No active visit to create calendar event for")
            }
        }
        
        debugLog("✅", "Settings updated and saved")
    }
    
    func completeSetup() {
        settings.isSetupComplete = true
        saveSettings()
    }
    
    private func saveSettings() {
        debugLog("💾", "[AppData] saveSettings called")
        debugLog("📋 Settings to save:")
        debugLog("  - Calendar enabled: \(settings.calendarSettings.isEnabled)")
        debugLog("  - Calendar ID: \(settings.calendarSettings.selectedCalendarId ?? "none")")
        debugLog("  - Setup complete: \(settings.isSetupComplete)")

        settingsStore.save(settings)
        debugLog("✅", "Settings encoded and saved to UserDefaults")

        // Verify the data was actually written
        if let savedData = sharedUserDefaults.data(forKey: AppGroupKeys.settingsKey) {
            debugLog("📄", "Saved data size: \(savedData.count) bytes")
            if let jsonString = String(data: savedData, encoding: .utf8) {
                debugLog("📄", "JSON preview: \(String(jsonString.prefix(200)))...")
            }
        } else {
            debugLog("❌", "No data found immediately after saving!")
        }
    }
    
    private func loadSettings() {
        debugLog("🔍", "[AppData] loadSettings called")

        if let data = sharedUserDefaults.data(forKey: AppGroupKeys.settingsKey) {
            debugLog("📄", "Found settings data: \(data.count) bytes")

            if let jsonString = String(data: data, encoding: .utf8) {
                debugLog("📄", "JSON preview: \(String(jsonString.prefix(200)))...")
            }
        }

        settings = settingsStore.load()
        debugLog("✅", "Settings loaded successfully")
        debugLog("📅", "Calendar enabled: \(settings.calendarSettings.isEnabled)")
        debugLog("📅", "Calendar ID: \(settings.calendarSettings.selectedCalendarId ?? "none")")
        debugLog("📅", "Setup complete: \(settings.isSetupComplete)")
    }
    
    // MARK: - Status Persistence
    
    private func loadCurrentStatus() {
        // Restore office status and current visit from persistent storage
        isCurrentlyInOffice = sharedUserDefaults.bool(forKey: AppGroupKeys.isCurrentlyInOfficeKey)
        
        if let data = sharedUserDefaults.data(forKey: AppGroupKeys.currentVisitKey),
           let visit = try? JSONDecoder().decode(OfficeVisit.self, from: data) {
            currentVisit = visit
            
            // Validate that the current visit is from today
            let calendar = Calendar.current
            if !calendar.isDate(visit.date, inSameDayAs: Date()) {
                // Current visit is from a previous day - auto-close the session
                autoCloseStaleVisit(visit)
                currentVisit = nil
                isCurrentlyInOffice = false
                clearCurrentVisit()
                debugLog("[AppData] Auto-closed and cleared stale visit from previous day")
            } else {
                debugLog("[AppData] Restored current visit from: \(visit.entryTime)")
                
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
            sharedUserDefaults.set(encoded, forKey: AppGroupKeys.currentVisitKey)
        } else {
            // Clear persisted current visit when currentVisit is nil
            sharedUserDefaults.removeObject(forKey: AppGroupKeys.currentVisitKey)
        }
    }
    
    private func clearCurrentVisit() {
        sharedUserDefaults.removeObject(forKey: AppGroupKeys.currentVisitKey)
    }
    
    /// Auto-close a stale session left open across a day boundary.
    ///
    /// This finalizes only a genuinely-active trailing session on the authoritative
    /// `visits` entry. It must NEVER overwrite a visit that already has a real exit
    /// time — doing so was the cause of exit times being replaced with 11:59 PM.
    private func autoCloseStaleVisit(_ staleVisit: OfficeVisit) {
        let calendar = Calendar.current

        // Operate on the authoritative array entry, not the (possibly stale) copy.
        guard let index = visits.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: staleVisit.date) }) else {
            // No history entry for that day; nothing to finalize.
            return
        }

        var visit = visits[index]

        // Preserve completed visits: if the trailing session already has a real
        // exit time, the visit is authoritative and must not be modified.
        guard visit.isActiveSession else {
            debugLog("[AppData] Stale visit already completed in history; preserving real exit time")
            return
        }

        // Prefer the real exit time captured by an interrupted grace period;
        // fall back to end-of-day only when no real exit is available.
        let exitTimeToApply = resolveStaleExitTime(for: visit, calendar: calendar)

        visit.endCurrentSession(at: exitTimeToApply)
        visits[index] = visit
        saveVisits()
        debugLog("[AppData] Auto-closed stale active visit with exit time: \(exitTimeToApply)")

        // CRITICAL: Update calendar event with exit time
        // This ensures the calendar event reflects the auto-closed state
        Task {
            await calendarEventManager.handleVisitEnd(visit, settings: settings)
            debugLog("[AppData] Updated calendar event for auto-closed stale visit")
        }
    }

    /// Resolve the exit time used to finalize a stale active session.
    ///
    /// Prefers the real exit time persisted by an interrupted exit grace period
    /// (when it is valid for the visit's day and not before entry). Consuming it
    /// here also prevents the grace-period restore from discarding it later.
    /// Falls back to end-of-day (23:59:59), and never returns a time before entry.
    private func resolveStaleExitTime(for visit: OfficeVisit, calendar: Calendar) -> Date {
        let entryTime = visit.entryTime

        if let pendingExit = sharedUserDefaults.object(forKey: AppGroupKeys.pendingExitTimeKey) as? Date,
           calendar.isDate(pendingExit, inSameDayAs: visit.date),
           pendingExit >= entryTime {
            // Consume the pending-exit state so grace-period restore won't re-handle it.
            sharedUserDefaults.removeObject(forKey: AppGroupKeys.pendingExitTimeKey)
            sharedUserDefaults.removeObject(forKey: AppGroupKeys.pendingExitRegionIdKey)
            sharedUserDefaults.removeObject(forKey: AppGroupKeys.gracePeriodExpiresKey)
            sharedUserDefaults.synchronize()
            debugLog("[AppData] Recovered real exit time from interrupted grace period: \(pendingExit)")
            return pendingExit
        }

        if let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: visit.date),
           endOfDay >= entryTime {
            return endOfDay
        }

        // Degenerate guard: never return a time before entry.
        return entryTime
    }
    
    // MARK: - Visit Management
    
    /// Add a visit with improved duplicate handling
    /// Add a visit with session management (mainly for manual entry and legacy compatibility)
    func addVisit(_ visit: OfficeVisit) -> Bool {
        let calendar = Calendar.current
        
        #if DEBUG
        debugLog("[AppData] addVisit called for date: \(visit.date)")
        debugLog("[AppData] Current visits array has \(visits.count) items")
        #endif
        
        // Check if a visit already exists for this day
        if let existingIndex = visits.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: visit.date) }) {
            let existingVisit = visits[existingIndex]
            
            // If existing visit has an active session, prevent duplicate
            if existingVisit.isActiveSession {
                debugLog("[AppData] DUPLICATE PREVENTED: Active session already exists for this day")
                return false
            }
            
            // Replace existing completed visit with new one (for manual edits)
            visits[existingIndex] = visit
            debugLog("[AppData] Replaced existing visit for \(visit.formattedDate)")
        } else {
            // No visit exists for this day, add new one
            visits.append(visit)
            debugLog("[AppData] Added new visit for \(visit.formattedDate)")
        }
        
        saveVisits()
        #if DEBUG
        debugLog("[AppData] Visits saved to UserDefaults")
        #endif
        return true
    }
    
    func startVisit(at location: CLLocationCoordinate2D) {
        let now = Date()
        let calendar = Calendar.current
        
        #if DEBUG
        debugLog("[AppData] startVisit called at \(now)")
        debugLog("[AppData] Current visits count: \(visits.count)")
        debugLog("[AppData] Current visit exists: \(currentVisit != nil)")
        #endif
        
        // Session Management: Check if there's already a visit for today
        if let todayVisitIndex = visits.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: now) }) {
            var todayVisit = visits[todayVisitIndex]
            
            #if DEBUG
            debugLog("[AppData] Found existing visit for today, managing session")
            #endif
            
            // If there's already an active session, don't create duplicate
            if todayVisit.isActiveSession {
                debugLog("[AppData] DUPLICATE PREVENTED: Session already active for today")
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
            
            debugLog("[AppData] Resumed office session for today")
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
        debugLog("[AppData] About to call calendar event manager...")
        Task {
            await calendarEventManager.handleVisitStart(newVisit, settings: settings)
        }
        
        debugLog("[AppData] Started new office session for today")
    }
    
    func endVisit(at exitTime: Date? = nil) async {
        guard var visit = currentVisit else { 
            debugLog("[AppData] No current visit to end")
            return 
        }
        
        debugLog("[AppData] Ending current session")
        
        let exitTime = exitTime ?? Date()
        
        // End the current session in the visit
        visit.endCurrentSession(at: exitTime)
        
        // Update the visit in the array
        let calendar = Calendar.current
        if let index = visits.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: visit.date) }) {
            visits[index] = visit
        }
        
        saveVisits()
        
        // Clear current visit state BEFORE calendar update to prevent UI confusion
        // But keep reference to visit for calendar update
        currentVisit = nil
        isCurrentlyInOffice = false
        clearCurrentVisit()
        
        if visit.isValidVisit {
            debugLog("[AppData] Completed valid office session with total duration: \(visit.formattedDuration)")
        } else {
            debugLog("[AppData] Completed session (\(visit.formattedDuration)), saved for record")
        }
        
        // CRITICAL FIX: Await calendar update to ensure it completes before app suspension
        // This prevents calendar events from showing "Currently in office" after you've left
        await calendarEventManager.handleVisitEnd(visit, settings: settings)
        debugLog("[AppData] Calendar event update completed for exit")
        
        debugLog("[AppData] Session ended successfully")
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
        let goal = getGoalForMonth(currentMonth)
        let percentage = goal > 0 ? Double(current) / Double(goal) : 0.0
        return (current, goal, min(percentage, 1.0))
    }

    // MARK: - Weekly Hybrid Policy

    /// Evaluate the user's current week against their weekly hybrid policy.
    ///
    /// Returns `nil` when the tracking cadence does not include weekly tracking,
    /// so existing monthly-only users are unaffected. The heavy lifting lives in
    /// `WeeklyComplianceEvaluator` to keep calculation logic out of this singleton.
    func getCurrentWeekCompliance(asOf date: Date = Date()) -> WeeklyComplianceResult? {
        guard settings.trackingCadence.includesWeekly else { return nil }

        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return nil }

        // In-office days for this week: completed valid visits plus any active session.
        let inOfficeDates = visits
            .filter { $0.date >= week.start && $0.date < week.end && ($0.isValidVisit || $0.isActiveSession) }
            .map { $0.date }

        return WeeklyComplianceEvaluator.evaluate(
            policy: settings.weeklyPolicy,
            weekContaining: date,
            inOfficeDates: inOfficeDates,
            evaluationDate: date,
            calendar: calendar
        )
    }

    // MARK: - Auto-Calculate Goal Methods
    
    /// Get the goal for a specific month, respecting locked historical goals
    func getGoalForMonth(_ date: Date) -> Int {
        let monthKey = monthKeyString(for: date)
        
        // Check if this is a past month with a locked goal
        if let lockedGoal = settings.lockedMonthlyGoals[monthKey] {
            return lockedGoal
        }
        
        // For current/future months, calculate or use manual goal
        if settings.autoCalculateGoal {
            return calculateRequiredDays(for: date)
        } else {
            return settings.monthlyGoal
        }
    }
    
    /// Calculate required in-office days for a month based on company policy
    func calculateRequiredDays(for month: Date) -> Int {
        let businessDays = calculateBusinessDays(for: month)
        let ptoCount = getPTODays(for: month).count
        let workingDays = max(0, businessDays - ptoCount)
        return settings.companyPolicy.calculateRequiredDays(workingDays: workingDays)
    }
    
    /// Calculate business days (weekdays minus holidays) for a month
    func calculateBusinessDays(for month: Date) -> Int {
        let weekdays = getWeekdaysInMonth(month)
        let holidays = getHolidaysInMonth(month)
        return max(0, weekdays - holidays.count)
    }
    
    /// Get all weekdays (based on tracking days setting) in a month
    func getWeekdaysInMonth(_ month: Date) -> Int {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return 0
        }
        
        var count = 0
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                let weekday = calendar.component(.weekday, from: date)
                if settings.trackingDays.contains(weekday) {
                    count += 1
                }
            }
        }
        return count
    }
    
    /// Get holidays that fall on tracking days in a month
    func getHolidaysInMonth(_ month: Date) -> [Date] {
        let calendar = Calendar.current
        let allHolidays = settings.holidayCalendar.getHolidays(for: month)
        
        // Only count holidays that fall on tracking days (e.g., weekdays)
        return allHolidays.filter { holiday in
            let weekday = calendar.component(.weekday, from: holiday)
            return settings.trackingDays.contains(weekday)
        }
    }
    
    /// Get PTO/sick days for a specific month
    func getPTODays(for month: Date) -> [Date] {
        let monthKey = monthKeyString(for: month)
        return settings.ptoSickDays[monthKey] ?? []
    }
    
    /// Add a PTO/sick day for a specific month
    func addPTODay(_ date: Date) {
        let monthKey = monthKeyString(for: date)
        var days = settings.ptoSickDays[monthKey] ?? []
        
        // Avoid duplicates
        let calendar = Calendar.current
        if !days.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
            days.append(date)
            days.sort()
            settings.ptoSickDays[monthKey] = days
            saveSettings()
        }
    }
    
    /// Add multiple PTO/sick days efficiently (single save operation)
    func addPTODays(_ dates: [Date]) {
        guard !dates.isEmpty else { return }
        
        let calendar = Calendar.current
        
        // Group dates by month
        var datesByMonth: [String: [Date]] = [:]
        for date in dates {
            let monthKey = monthKeyString(for: date)
            datesByMonth[monthKey, default: []].append(date)
        }
        
        // Add dates to each month, avoiding duplicates
        for (monthKey, newDates) in datesByMonth {
            var days = settings.ptoSickDays[monthKey] ?? []
            
            for date in newDates {
                if !days.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
                    days.append(date)
                }
            }
            
            days.sort()
            settings.ptoSickDays[monthKey] = days
        }
        
        // Single save after all additions
        saveSettings()
    }
    
    /// Remove a PTO/sick day for a specific month
    func removePTODay(_ date: Date) {
        let monthKey = monthKeyString(for: date)
        let calendar = Calendar.current
        settings.ptoSickDays[monthKey]?.removeAll { calendar.isDate($0, inSameDayAs: date) }
        saveSettings()
    }
    
    /// Lock the goal for a specific month (called on month transition)
    func lockGoalForMonth(_ date: Date) {
        let monthKey = monthKeyString(for: date)
        guard settings.lockedMonthlyGoals[monthKey] == nil else { return }
        
        settings.lockedMonthlyGoals[monthKey] = getGoalForMonth(date)
        saveSettings()
    }
    
    /// Generate a month key string (YYYY-MM format) for dictionary keys
    private func monthKeyString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
    
    /// Get detailed calculation breakdown for UI display
    func getGoalCalculationBreakdown(for month: Date) -> GoalCalculationBreakdown {
        let weekdays = getWeekdaysInMonth(month)
        let holidays = getHolidaysInMonth(month)
        let businessDays = weekdays - holidays.count
        let ptoDays = getPTODays(for: month)
        
        // Deduplicate: Remove PTO days that are also holidays to prevent double-counting
        let calendar = Calendar.current
        let uniquePTODays = ptoDays.filter { ptoDate in
            !holidays.contains { holiday in
                calendar.isDate(ptoDate, inSameDayAs: holiday)
            }
        }
        
        let workingDays = max(0, businessDays - uniquePTODays.count)
        let requiredDays = settings.companyPolicy.calculateRequiredDays(workingDays: workingDays)
        
        return GoalCalculationBreakdown(
            weekdaysInMonth: weekdays,
            holidays: holidays,
            businessDays: businessDays,
            ptoDays: uniquePTODays,  // Return deduplicated list
            workingDays: workingDays,
            policyPercentage: settings.companyPolicy.requiredPercentage,
            requiredDays: requiredDays
        )
    }
    
    private func saveVisits() {
        visitRepository.save(visits)
        updateWidgetData()
    }

    private func loadVisits() {
        visits = visitRepository.load()
    }
    
    // MARK: - Widget Data Management
    
    /// Update widget data whenever app data changes
    private func updateWidgetData() {
        debugLog("✅", "[AppData] Triggering widget timeline reload")
        debugLog("🔄", "[AppData] Current state: isInOffice=\(isCurrentlyInOffice), visits=\(getCurrentMonthProgress().current)")
        
        // Force UserDefaults synchronization to ensure data is written immediately
        sharedUserDefaults.synchronize()
        
        // Verify the data was persisted correctly
        let verifyStatus = sharedUserDefaults.bool(forKey: AppGroupKeys.isCurrentlyInOfficeKey) 
        debugLog("🔍", "[AppData] Verified persisted office status: \(verifyStatus)")
        
        // Request widget timeline reload - single call to preserve WidgetKit daily budget
        #if canImport(WidgetKit)
        Task { @MainActor in
            WidgetCenter.shared.reloadTimelines(ofKind: "OfficeTrackerWidget")
            debugLog("🔄", "[AppData] Widget reload request sent")
        }
        #else
        debugLog("⚠️", "[AppData] WidgetKit not available")
        #endif
    }
    
    // MARK: - Historical Data Repair

    /// Trigger foreground repair when app becomes active
    /// Called by the app when returning from background
    func triggerForegroundRepair() {
        let (repairedVisits, repairCount) = historicalRepairRunner.triggerForegroundRepair(visits: visits)
        if repairCount > 0 {
            visits = repairedVisits
            saveVisits()
        }
    }
    
    /// Repair historical sessions by merging events with short gaps (likely GPS drift)
    /// This fixes visits that were incorrectly split due to false geofence exits
    /// - Parameter gapThreshold: Maximum gap in seconds to merge (default: 90 minutes)
    /// - Parameter dateFilter: Only repair visits on or after this date (nil = all visits)
    /// - Returns: Number of visits repaired
    @discardableResult
    func repairHistoricalSessions(gapThreshold: TimeInterval = 5400, dateFilter: Date? = nil) -> Int {
        let (repairedVisits, repairCount) = historicalRepairRunner.repairHistoricalSessions(visits: visits, gapThreshold: gapThreshold, dateFilter: dateFilter)
        if repairCount > 0 {
            visits = repairedVisits
            saveVisits()
        }
        return repairCount
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

    // MARK: - Public Migration Helper

    /// Force migration of office locations if data is inconsistent
    func ensureOfficeLocationConsistency() {
        migrationRunner.ensureOfficeLocationConsistency(currentSettings: settings)
    }
    
    // MARK: - Multiple Office Location Helpers
    
    /// Check if a coordinate is within any configured office location
    func isWithinAnyOfficeLocation(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // Check new multiple locations first
        if !settings.officeLocations.isEmpty {
            return settings.officeLocations.contains { $0.contains(coordinate: coordinate) }
        }
        
        // Fallback to legacy single location
        guard let officeCoord = settings.officeLocation else { return false }
        let officeLocation = CLLocation(latitude: officeCoord.latitude, longitude: officeCoord.longitude)
        let checkLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return checkLocation.distance(from: officeLocation) <= settings.detectionRadius
    }
    
    /// Get the primary office location (or first location if none marked primary)
    func getPrimaryOfficeLocation() -> OfficeLocation? {
        if let primary = settings.officeLocations.first(where: { $0.isPrimary }) {
            return primary
        }
        return settings.officeLocations.first
    }
    
    /// Get the office location that contains a given coordinate
    func getOfficeLocation(containing coordinate: CLLocationCoordinate2D) -> OfficeLocation? {
        return settings.officeLocations.first { $0.contains(coordinate: coordinate) }
    }
    
    // MARK: - Calendar Integration
    
    /// Optimistically write exit time to calendar during the geofence background window.
    /// Called immediately on exit detection so the calendar updates even if the app is suspended
    /// before the grace period timer fires. If the user re-enters (false exit), the calendar
    /// will be corrected by revertOptimisticCalendarExit on re-entry.
    func writeOptimisticCalendarExit(at exitTime: Date) async {
        guard let visit = currentVisit, visit.isActiveSession else {
            debugLog("📅", "[AppData] No active visit for optimistic calendar exit")
            return
        }
        
        // Create a snapshot of the visit with the exit time applied
        var snapshot = visit
        snapshot.endCurrentSession(at: exitTime)
        
        debugLog("📅", "[AppData] Writing optimistic calendar exit at \(exitTime)")
        await calendarEventManager.handleVisitEnd(snapshot, settings: settings)
    }
    
    /// Revert an optimistic calendar exit when user re-enters during grace period (false exit).
    /// Restores the calendar event to "currently in office" state.
    func revertOptimisticCalendarExit(visit: OfficeVisit) async {
        debugLog("📅", "[AppData] Reverting optimistic calendar exit - user returned")
        await calendarEventManager.handleVisitStart(visit, settings: settings)
    }
    
    private func ensureCalendarEventForCurrentVisit(_ visit: OfficeVisit) async {
        guard settings.calendarSettings.isEnabled,
              visit.isActiveSession else {
            return
        }
        
        debugLog("📅", "[AppData] Ensuring calendar event exists for current visit")
        await calendarEventManager.handleVisitUpdate(visit, settings: settings)
    }
    
    // MARK: - Trend & Streak Data Methods (MFP-style dashboard)
    
    /// Get visit trend data for the chart - returns daily visit counts
    /// - Parameter days: Number of days to look back
    /// - Returns: Array of (date, visitCount) tuples for chart visualization
    func getVisitTrend(days: Int) -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Build a dictionary of visit counts by date
        var visitsByDate: [Date: Int] = [:]
        
        for visit in visits where visit.isValidVisit {
            let visitDate = calendar.startOfDay(for: visit.date)
            visitsByDate[visitDate, default: 0] += 1
        }
        
        // Generate data points for each day in the range
        var result: [(date: Date, count: Int)] = []
        let daysToInclude = min(days, 365) // Cap at 1 year
        
        for dayOffset in (0..<daysToInclude).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let count = visitsByDate[date] ?? 0
                result.append((date: date, count: count))
            }
        }
        
        return result
    }
    
    /// Check if there's enough data for meaningful chart visualization
    /// - Parameter days: Requested chart range
    /// - Returns: True if at least 7 days of visit data exists
    func hasEnoughChartData(days: Int) -> Bool {
        let trendData = getVisitTrend(days: days)
        let daysWithData = trendData.filter { $0.count > 0 }.count
        return daysWithData >= 7
    }

    /// Month-based visit trend helper. Keeps existing day-based API for compatibility.
    /// - Parameter months: Number of months to look back
    /// - Returns: Array of (date, visitCount) tuples for chart visualization (daily points)
    func getVisitTrend(months: Int) -> [(date: Date, count: Int)] {
        guard months > 0 else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Compute start date month-aware
        guard let startDate = calendar.date(byAdding: .month, value: -months, to: today) else { return [] }

        // Build a dictionary of visit counts by date
        var visitsByDate: [Date: Int] = [:]
        for visit in visits where visit.isValidVisit {
            let visitDate = calendar.startOfDay(for: visit.date)
            visitsByDate[visitDate, default: 0] += 1
        }

        // Iterate day-by-day from startDate to today
        var result: [(date: Date, count: Int)] = []
        var current = startDate
        while current <= today {
            let count = visitsByDate[current] ?? 0
            result.append((date: current, count: count))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return result
    }

    /// Month-based wrapper to check if there's enough data for chart visualization
    /// - Parameter months: Number of months to inspect
    /// - Returns: True if at least 7 days of visit data exists in the range
    func hasEnoughChartData(months: Int) -> Bool {
        let trendData = getVisitTrend(months: months)
        let daysWithData = trendData.filter { $0.count > 0 }.count
        return daysWithData >= 7
    }
    
    /// Calculate monthly streak - consecutive months meeting the goal
    /// Includes current month if goal is already met
    /// - Returns: Number of consecutive months meeting the goal
    func getMonthlyStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0

        // Start checking from the previous month so prior months count even if current month isn't met
        var checkDate = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()

        // Count consecutive previous months that met their goals
        for _ in 0..<24 { // Check up to 2 years back
            let monthVisits = getValidVisits(for: checkDate)
            let monthGoal = getGoalForMonth(checkDate)

            if monthGoal > 0 && monthVisits.count >= monthGoal {
                streak += 1
                checkDate = calendar.date(byAdding: .month, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }

        // Optionally include the current month if already met
        let currentProgress = getCurrentMonthProgress()
        if currentProgress.goal > 0 && currentProgress.current >= currentProgress.goal {
            streak += 1
        }

        return streak
    }
    
    /// Check if current month goal is already met
    /// - Returns: True if current visits >= goal
    func isCurrentMonthGoalMet() -> Bool {
        let progress = getCurrentMonthProgress()
        return progress.current >= progress.goal && progress.goal > 0
    }
    
    /// Calculate pace needed to meet monthly goal
    /// - Returns: Days per week needed, or 0 if goal already met
    func getPaceNeeded() -> Double {
        let progress = getCurrentMonthProgress()
        let remaining = max(0, progress.goal - progress.current)
        
        guard remaining > 0 else { return 0.0 }
        
        let daysLeft = getWorkingDaysRemaining()
        guard daysLeft > 0 else { return Double(remaining) } // All remaining days needed
        
        let workingDaysPerWeek = Double(settings.trackingDays.count)
        guard workingDaysPerWeek > 0 else { return 0.0 }
        
        let dailyRate = Double(remaining) / Double(daysLeft)
        return dailyRate * workingDaysPerWeek
    }
    
    /// Get number of working days remaining in current month
    /// - Returns: Count of remaining tracking days (includes today if it's a tracking day), minus holidays and PTO
    func getWorkingDaysRemaining() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end else { return 0 }
        
        var count = 0
        var date = calendar.startOfDay(for: now)
        
        // endOfMonth is the start of next month, so use < not <=
        while date < endOfMonth {
            let weekday = calendar.component(.weekday, from: date)
            if settings.trackingDays.contains(weekday) {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? endOfMonth
        }
        
        // Get remaining holidays (on tracking days, >= today)
        let allHolidays = getHolidaysInMonth(now)
        let remainingHolidays = allHolidays.filter { holiday in
            holiday >= calendar.startOfDay(for: now)
        }
        
        // Get remaining PTO days (on tracking days, >= today)
        let allPTO = getPTODays(for: now)
        let remainingPTO = allPTO.filter { pto in
            let weekday = calendar.component(.weekday, from: pto)
            return settings.trackingDays.contains(weekday) && pto >= calendar.startOfDay(for: now)
        }
        
        // Deduplicate: holiday + PTO on same day counted once
        let holidayPTOSet = Set(remainingHolidays + remainingPTO)
        
        return max(0, count - holidayPTOSet.count)
    }
    
    /// Get number of weeks remaining in current month
    /// - Returns: Approximate weeks remaining (rounded up)
    func getWeeksRemaining() -> Int {
        let daysRemaining = getWorkingDaysRemaining()
        let workingDaysPerWeek = max(1, settings.trackingDays.count)
        return Int(ceil(Double(daysRemaining) / Double(workingDaysPerWeek)))
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