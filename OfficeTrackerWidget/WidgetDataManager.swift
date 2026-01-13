//
//  WidgetDataManager.swift
//  Shared between app and widget
//
//  Manages data sharing between main app and widget extension
//

import Foundation

class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    // App Group identifier - update this to match your team/app
    private let appGroupIdentifier = "group.com.lpineda.InOfficeDaysTracker"
    private let widgetDataKey = "WidgetData"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    private init() {}
    
    // MARK: - Data Management
    
    func saveWidgetData(_ data: WidgetData) {
        guard let defaults = sharedDefaults else {
            print("❌ [WidgetDataManager] Could not access shared UserDefaults")
            return
        }
        
        do {
            let encoded = try JSONEncoder().encode(data)
            defaults.set(encoded, forKey: widgetDataKey)
            print("✅ [WidgetDataManager] Widget data saved successfully")
        } catch {
            print("❌ [WidgetDataManager] Failed to encode widget data: \(error)")
        }
    }
    
    func getCurrentData() -> WidgetData {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: widgetDataKey) else {
            print("⚠️ [WidgetDataManager] No shared data found, returning placeholder")
            return WidgetData.noData
        }
        
        do {
            let decoded = try JSONDecoder().decode(WidgetData.self, from: data)
            
            // Check if data is stale (older than 24 hours)
            let hoursSinceUpdate = Date().timeIntervalSince(decoded.lastUpdated) / 3600
            if hoursSinceUpdate > 24 {
                print("⚠️ [WidgetDataManager] Data is stale (>24h old), returning fallback")
                return createStaleDataFallback(from: decoded)
            }
            
            return decoded
        } catch {
            print("❌ [WidgetDataManager] Failed to decode widget data: \(error)")
            return WidgetData.noData
        }
    }
    
    // MARK: - Data Conversion from UserDefaults
    
    func createWidgetData() -> WidgetData {
        let timestamp = Date()
        print("🔍 [WidgetDataManager] Creating widget data at \(timestamp)...")
        
        guard let userDefaults = sharedDefaults else {
            print("❌ [WidgetDataManager] No shared UserDefaults available")
            return WidgetData.noData
        }
        
        // Force synchronization to get the latest data
        userDefaults.synchronize()
        print("🔄 [WidgetDataManager] UserDefaults synchronized")
        
        let progressData = getCurrentMonthProgress()
        let monthName = getCurrentMonthName()
        
        // Calculate weekly progress
        let weeklyProgress = calculateWeeklyProgress()
        
        // Calculate average duration
        let averageDuration = calculateAverageDuration()
        
        // Get days remaining in month
        let daysRemaining = max(0, progressData.goal - progressData.current)
        
        // Calculate pace needed using the same logic as MainProgressView
        let paceNeeded = calculatePaceNeeded(
            current: progressData.current,
            goal: progressData.goal
        )
        
        // Get current office status
        let isCurrentlyInOffice = userDefaults.bool(forKey: "IsCurrentlyInOffice")
        print("🔍 [WidgetDataManager] Office status from UserDefaults: \(isCurrentlyInOffice)")
        print("🔍 [WidgetDataManager] Month progress: current=\(progressData.current), goal=\(progressData.goal)")
        
        // Calculate current visit duration if in office
        var currentVisitDuration: TimeInterval? = nil
        if let currentVisitData = userDefaults.data(forKey: "CurrentVisit"),
           let currentVisit = try? JSONDecoder().decode(OfficeVisit.self, from: currentVisitData) {
            currentVisitDuration = Date().timeIntervalSince(currentVisit.entryTime)
        }
        
        // Calculate status message
        let statusMessage = generateStatusMessage(
            current: progressData.current,
            goal: progressData.goal,
            isCurrentlyInOffice: isCurrentlyInOffice
        )
        
        // Calculate days left in month (weekdays only, matching main app)
        let daysLeftInMonth = getDaysRemainingInMonth()
        
        return WidgetData(
            current: progressData.current,
            goal: progressData.goal,
            percentage: progressData.percentage,
            monthName: monthName,
            isCurrentlyInOffice: isCurrentlyInOffice,
            currentVisitDuration: currentVisitDuration,
            weeklyProgress: weeklyProgress,
            averageDuration: averageDuration,
            daysRemaining: daysRemaining,
            paceNeeded: paceNeeded,
            lastUpdated: Date(),
            statusMessage: statusMessage,
            daysLeftInMonth: daysLeftInMonth
        )
    }
    
    // MARK: - Helper Functions
    
    private func getCurrentMonthName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    private func calculateWeeklyProgress() -> Int {
        guard let userDefaults = sharedDefaults,
              let visitsData = userDefaults.data(forKey: "OfficeVisits"),
              let visits = try? JSONDecoder().decode([OfficeVisit].self, from: visitsData) else {
            return 0
        }
        
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
        guard let userDefaults = sharedDefaults,
              let visitsData = userDefaults.data(forKey: "OfficeVisits"),
              let visits = try? JSONDecoder().decode([OfficeVisit].self, from: visitsData) else {
            return 0
        }
        
        let validVisits = getValidVisits(from: visits)
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
        
        // Default to weekdays if no settings available
        let workingDaysPerWeek = getTrackingDaysCount()
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
            // Weekdays: 2 = Monday, ..., 6 = Friday (matching MainProgressView exactly)
            if weekday >= 2 && weekday <= 6 {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return count
    }
    
    private func createStaleDataFallback(from staleData: WidgetData) -> WidgetData {
        return WidgetData(
            current: staleData.current,
            goal: staleData.goal,
            percentage: staleData.percentage,
            monthName: staleData.monthName,
            isCurrentlyInOffice: false, // Assume not in office if data is stale
            currentVisitDuration: nil,
            weeklyProgress: staleData.weeklyProgress,
            averageDuration: staleData.averageDuration,
            daysRemaining: staleData.daysRemaining,
            paceNeeded: "Open app to refresh",
            lastUpdated: staleData.lastUpdated,
            statusMessage: "Data may be outdated",
            daysLeftInMonth: staleData.daysLeftInMonth
        )
    }
    
    // MARK: - Helper Methods for UserDefaults Access
    
    private func getCurrentMonthProgress() -> (current: Int, goal: Int, percentage: Double) {
        guard let userDefaults = sharedDefaults else {
            print("❌ [WidgetDataManager] No shared UserDefaults in getCurrentMonthProgress")
            return (0, 10, 0.0) // Fallback values
        }
        
        print("🔍 [WidgetDataManager] Checking for visits data...")
        
        // Get settings
        let goal = getMonthlyGoal()
        
        // Get visits
        guard let visitsData = userDefaults.data(forKey: "OfficeVisits"),
              let visits = try? JSONDecoder().decode([OfficeVisit].self, from: visitsData) else {
            print("❌ [WidgetDataManager] No visits data found")
            return (0, goal, 0.0)
        }
        
        print("✅ [WidgetDataManager] Found \(visits.count) visits")
        
        let validVisits = getValidVisits(from: visits)
        let visitsInProgress = getVisitsInProgress(from: visits)
        let current = validVisits.count + visitsInProgress.count
        let percentage = goal > 0 ? Double(current) / Double(goal) : 0.0
        
        return (current, goal, min(percentage, 1.0))
    }
    
    private func getValidVisits(from visits: [OfficeVisit]) -> [OfficeVisit] {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        return visits.filter { visit in
            visit.isValidVisit && visit.date >= monthStart
        }
    }
    
    private func getVisitsInProgress(from visits: [OfficeVisit]) -> [OfficeVisit] {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        return visits.filter { visit in
            visit.duration == nil && visit.date >= monthStart
        }
    }
    
    private func getMonthlyGoal() -> Int {
        guard let userDefaults = sharedDefaults,
              let settingsData = userDefaults.data(forKey: "AppSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) else {
            return 10 // Default goal
        }
        
        // Check if auto-calculate is enabled
        if settings.autoCalculateGoal {
            // Check for locked goal first
            let monthKey = getMonthKeyString(for: Date())
            if let lockedGoal = settings.lockedMonthlyGoals[monthKey] {
                return lockedGoal
            }
            
            // Calculate the goal
            return calculateRequiredDays(settings: settings)
        } else {
            return settings.monthlyGoal
        }
    }
    
    /// Calculate required in-office days based on company policy
    private func calculateRequiredDays(settings: AppSettings) -> Int {
        let businessDays = calculateBusinessDays(settings: settings)
        let ptoCount = getPTODays(settings: settings).count
        let workingDays = max(0, businessDays - ptoCount)
        return settings.companyPolicy.calculateRequiredDays(workingDays: workingDays)
    }
    
    /// Calculate business days (weekdays minus holidays) for current month
    private func calculateBusinessDays(settings: AppSettings) -> Int {
        let weekdays = getWeekdaysInMonth(settings: settings)
        let holidays = getHolidaysInMonth(settings: settings)
        return max(0, weekdays - holidays.count)
    }
    
    /// Get all weekdays in current month based on tracking days
    private func getWeekdaysInMonth(settings: AppSettings) -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: now),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
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
    
    /// Get holidays in current month that fall on tracking days
    private func getHolidaysInMonth(settings: AppSettings) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        let allHolidays = settings.holidayCalendar.getHolidays(for: now)
        
        return allHolidays.filter { holiday in
            let weekday = calendar.component(.weekday, from: holiday)
            return settings.trackingDays.contains(weekday)
        }
    }
    
    /// Get PTO days for current month
    private func getPTODays(settings: AppSettings) -> [Date] {
        let monthKey = getMonthKeyString(for: Date())
        return settings.ptoSickDays[monthKey] ?? []
    }
    
    /// Generate month key string (YYYY-MM format)
    private func getMonthKeyString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
    
    private func getTrackingDays() -> Set<Int> {
        guard let userDefaults = sharedDefaults,
              let settingsData = userDefaults.data(forKey: "AppSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) else {
            // Default to weekdays (Mon-Fri)
            return Set([2, 3, 4, 5, 6])
        }
        return Set(settings.trackingDays)
    }
    
    private func getTrackingDaysCount() -> Int {
        return getTrackingDays().count
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
}