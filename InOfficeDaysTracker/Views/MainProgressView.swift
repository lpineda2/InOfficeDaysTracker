//
//  MainProgressView.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//  Redesigned with MFP-style dashboard
//

import SwiftUI

struct MainProgressView: View {
    @ObservedObject var appData: AppData
    @Binding var selectedTab: MainTabView.Tab
    
    @State private var currentTime = Date()
    /// Keeps the time-away prompt visible through its confirmation state after
    /// the user enables the feature from it. Resets when the view reappears.
    @State private var justEnabledTimeAway = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Grid layout: 2 columns
    private let columns = [
        GridItem(.flexible(), spacing: DesignTokens.gridSpacing),
        GridItem(.flexible(), spacing: DesignTokens.gridSpacing)
    ]

    /// Current-week compliance when weekly tracking is enabled (nil otherwise).
    private var weeklyCompliance: WeeklyComplianceResult? {
        appData.getCurrentWeekCompliance()
    }

    /// Whether the monthly goal engine applies. Only `.monthly`/`.both` show
    /// monthly-goal UI (ring, pace, streak, goal-progress details) — a
    /// `.weekly`-only user has no monthly goal configured for that policy, so
    /// showing it would surface a number unrelated to (and sometimes in
    /// conflict with) their actual weekly policy.
    private var showsMonthlyGoal: Bool {
        appData.settings.trackingCadence.includesMonthly
    }

    /// Weekly tracking with no monthly goal alongside it. Historical stats
    /// (trend chart, average duration) switch to weekly/all-time framing here,
    /// since a calendar-month window is meaningless to these users.
    private var isWeeklyOnly: Bool {
        appData.settings.trackingCadence == .weekly
    }

    /// Widest weekly range the chart offers, used for the "enough data" check
    /// so the overlay reflects the full window a user could select.
    /// Keep in sync with `TrendChartCard.WeeklyTrendRange`.
    private var weeklyTrendWeeks: Int { 8 }

    /// Clarifies which window the average covers, since it differs by cadence.
    private var durationSubtitle: String {
        isWeeklyOnly ? "Per office visit (all time)" : "Per office visit"
    }

    /// Whether to offer the one-time nudge about reducing goals for time away.
    ///
    /// Only for weekly users who haven't enabled the feature and haven't
    /// dismissed the prompt. Weekly tracking shipped before this existed, so
    /// those users would otherwise never discover it.
    ///
    /// `justEnabledTimeAway` keeps the card on screen after the user turns the
    /// feature on from it, so they see the confirmation instead of the card
    /// disappearing the instant they tap.
    private var showsTimeAwayPrompt: Bool {
        guard appData.settings.trackingCadence.includesWeekly else { return false }
        if justEnabledTimeAway { return true }

        return !appData.settings.weeklyPolicy.honorsHolidaysAndPTO
            && !appData.settings.hasSeenTimeAwayPrompt
    }

    /// Writes straight through to the stored policy so the prompt's inline
    /// controls and the settings screen can't disagree.
    private var timeAwayAllowanceBinding: Binding<Int> {
        Binding(
            get: { appData.settings.weeklyPolicy.unavailabilityAllowance },
            set: { newValue in
                var settings = appData.settings
                settings.weeklyPolicy.unavailabilityAllowance = max(0, newValue)
                appData.updateSettings(settings)
            }
        )
    }

    private var holidayAnchorWaiverBinding: Binding<Bool> {
        Binding(
            get: { appData.settings.weeklyPolicy.waivesAnchorDaysOnHolidayWeeks },
            set: { newValue in
                var settings = appData.settings
                settings.weeklyPolicy.waivesAnchorDaysOnHolidayWeeks = newValue
                appData.updateSettings(settings)
            }
        )
    }

    /// Enables time-away handling directly from the dashboard prompt.
    ///
    /// Deliberately does *not* set `hasSeenTimeAwayPrompt`. Enabling already
    /// suppresses the prompt via the `honorsHolidaysAndPTO` check, so writing
    /// the flag too would permanently suppress it even if the user later turns
    /// the feature back off — leaving them with no way to see the explanation
    /// again. "Seen" is reserved for an explicit dismissal.
    private func enableTimeAwayHandling() {
        justEnabledTimeAway = true

        var settings = appData.settings
        settings.weeklyPolicy.honorsHolidaysAndPTO = true
        appData.updateSettings(settings)
    }

    private func dismissTimeAwayPrompt() {
        justEnabledTimeAway = false

        var settings = appData.settings
        settings.hasSeenTimeAwayPrompt = true
        appData.updateSettings(settings)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DesignTokens.gridSpacing) {
                // Header with month
                headerSection
                
                // In Weekly mode, the weekly card is primary (shown first) and
                // the monthly card is clearly labelled as a secondary summary.
                if let weeklyCompliance = weeklyCompliance {
                    WeeklyComplianceCard(
                        result: weeklyCompliance,
                        policy: appData.settings.weeklyPolicy
                    )

                    if showsTimeAwayPrompt {
                        TimeAwayPromptCard(
                            onEnable: enableTimeAwayHandling,
                            onDismiss: dismissTimeAwayPrompt,
                            unavailabilityAllowance: timeAwayAllowanceBinding,
                            waivesAnchorDaysOnHolidayWeeks: holidayAnchorWaiverBinding,
                            hasAnchorDay: !appData.settings.weeklyPolicy.anchorDayGroups.isEmpty
                        )
                    }

                    if showsMonthlyGoal {
                        Text("Monthly Summary")
                            .font(Typography.sectionHeader)
                            .foregroundColor(DesignTokens.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                            .accessibilityAddTraits(.isHeader)
                    }
                }

                // Hero Progress Card (Macro Ring style) — monthly goal.
                // Hidden entirely for weekly-only tracking: there is no
                // monthly goal to show, and the old CompanyPolicy-derived
                // numbers would be unrelated to (or contradict) the weekly
                // policy above.
                if showsMonthlyGoal {
                    MacroRingCard(
                        daysCompleted: progressData.current,
                        daysGoal: progressData.goal,
                        goalRemaining: max(0, progressData.goal - progressData.current),
                        workingDaysRemaining: appData.getWorkingDaysRemaining(),
                        paceNeeded: appData.getPaceNeeded(),
                        weeksRemaining: appData.getWeeksRemaining(),
                        isGoalUnreachable: isPaceUnreachable
                    )
                }

                // Status Card (if in office)
                if appData.isCurrentlyInOffice, let currentVisit = appData.currentVisit {
                    currentStatusCard(visit: currentVisit)
                }
                
                // Mini Metric Cards. Paired 2-column grid when there's a
                // monthly streak to show alongside duration; otherwise
                // Avg Duration renders alone at full width so it doesn't
                // leave a lopsided half-empty row.
                if showsMonthlyGoal {
                    LazyVGrid(columns: columns, spacing: DesignTokens.gridSpacing) {
                        StreakMetricCard(
                            streakMonths: appData.getMonthlyStreak(),
                            isOnTrack: appData.isCurrentMonthGoalMet(),
                            title: weeklyCompliance != nil ? "Monthly Streak" : "Streak"
                        )

                        DurationMetricCard(
                            averageHours: getAverageDuration(),
                            subtitle: durationSubtitle
                        )
                    }
                } else {
                    DurationMetricCard(
                        averageHours: getAverageDuration(),
                        isFullWidth: true,
                        subtitle: durationSubtitle
                    )
                }

                // Trend Chart — weekly buckets for weekly-only cadence, monthly otherwise
                if isWeeklyOnly {
                    TrendChartCard(
                        data: getWeeklyTrendData(),
                        hasEnoughData: appData.hasEnoughChartData(weeks: weeklyTrendWeeks),
                        isWeekly: true,
                        weeklyMinimumDays: appData.settings.weeklyPolicy.weeklyMinimumDays
                    )
                } else {
                    TrendChartCard(
                        data: getTrendData(),
                        hasEnoughData: appData.hasEnoughChartData(months: 9)
                    )
                }
                
                // Recent Visits - tapping "See All" switches to History tab
                RecentVisitsList(
                    visits: getRecentVisitsDisplayItems(),
                    onSeeAllTapped: { selectedTab = .history }
                )
                    
                    // Goal Progress Details — monthly-goal breakdown, same
                    // reasoning as MacroRingCard above.
                    if showsMonthlyGoal {
                        GoalProgressSection(
                            current: progressData.current,
                            goal: progressData.goal,
                            remaining: max(0, progressData.goal - progressData.current),
                            daysLeft: appData.getWorkingDaysRemaining(),
                            appData: appData
                        )
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .background(DesignTokens.appBackground)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                currentTime = Date()
                // The confirmation state is per-visit; returning to the
                // dashboard later shouldn't resurrect the card.
                justEnabledTimeAway = false
            }
            .onReceive(timer) { _ in
                if appData.isCurrentlyInOffice {
                    currentTime = Date()
                }
            }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("Today")
                .font(Typography.cardTitle)
                .foregroundColor(DesignTokens.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(getCurrentMonthName())
                .font(Typography.bodySecondary)
                .foregroundColor(DesignTokens.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 8)
    }
    
    private func currentStatusCard(visit: OfficeVisit) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .iconBackground(color: DesignTokens.statusInOffice)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Currently In Office")
                    .font(Typography.caption)
                    .foregroundColor(DesignTokens.textSecondary)
                
                Text(formatCurrentVisitDuration(visit))
                    .font(Typography.cardTitle)
                    .foregroundColor(DesignTokens.textPrimary)
            }
            
            Spacer()
            
            // Pulsing indicator
            Circle()
                .fill(DesignTokens.statusInOffice)
                .frame(width: 10, height: 10)
                .modifier(PulseAnimation())
        }
        .cardStyle()
    }
    
    // MARK: - Data
    
    private var progressData: (current: Int, goal: Int, percentage: Double) {
        appData.getCurrentMonthProgress()
    }

    private var isPaceUnreachable: Bool {
        let remainingForPace = max(0, progressData.goal - progressData.current)
        let daysLeftForPace = appData.getWorkingDaysRemaining()
        let workingDaysPerWeek = appData.settings.trackingDays.count

        if remainingForPace > 0 {
            if daysLeftForPace <= 0 {
                return true
            } else if workingDaysPerWeek > 0 {
                let dailyRate = Double(remainingForPace) / Double(daysLeftForPace)
                let weeklyRate = dailyRate * Double(workingDaysPerWeek)
                if weeklyRate > Double(workingDaysPerWeek) {
                    return true
                }
            }
        }

        return false
    }
    
    private func getCurrentMonthName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    private func formatCurrentVisitDuration(_ visit: OfficeVisit) -> String {
        let duration = currentTime.timeIntervalSince(visit.entryTime)
        guard !duration.isNaN && !duration.isInfinite && duration >= 0 else { return "Invalid duration" }
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours == 0 && minutes == 0 && duration > 0 {
            return "< 1 minute"
        }
        return String(format: "%dh %dm", hours, minutes)
    }
    
    private func getWeeklyProgress() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        let validVisits = appData.visits.filter { visit in
            visit.isValidVisit && visit.date >= weekStart
        }
        
        let visitsInProgress = appData.visits.filter { visit in
            visit.duration == nil && visit.date >= weekStart
        }
        
        return validVisits.count + visitsInProgress.count
    }
    
    /// Average completed-visit length in hours, or `nil` when no completed
    /// visits exist in the relevant window.
    ///
    /// Window depends on cadence: weekly-only users get an all-time average
    /// (a calendar-month window is meaningless to them, and short windows
    /// frequently render empty), while monthly/both keep the current-month
    /// window that has always been shown.
    ///
    /// Returning `nil` rather than `0.0` lets the card distinguish "nothing
    /// completed yet" from a genuine zero — the former is common (a first
    /// visit still in progress) and previously displayed as a confusing "0h".
    private func getAverageDuration() -> Double? {
        let validVisits = isWeeklyOnly
            ? appData.visits.filter { $0.isValidVisit }
            : appData.getValidVisits(for: Date())

        guard !validVisits.isEmpty else { return nil }

        // Cap individual visit durations at 18 hours (64,800 seconds) to filter out
        // stale/test visits that were never properly ended or have timestamp anomalies
        let maxReasonableDuration: TimeInterval = 18 * 3600
        let cappedDurations = validVisits.compactMap { visit -> TimeInterval? in
            guard let duration = visit.duration else { return nil }
            return min(duration, maxReasonableDuration)
        }

        guard !cappedDurations.isEmpty else { return nil }

        let totalDuration = cappedDurations.reduce(0, +)
        let average = (totalDuration / Double(cappedDurations.count)) / 3600 // Convert to hours
        guard !average.isNaN && !average.isInfinite else { return nil }
        return average
    }

    /// Daily trend points covering the widest weekly range the chart offers.
    /// `TrendChartCard` buckets these into weeks for the selected range.
    private func getWeeklyTrendData() -> [TrendDataPoint] {
        let trend = appData.getVisitTrend(weeks: weeklyTrendWeeks)
        return trend.map { TrendDataPoint(date: $0.date, value: $0.count) }
    }
    
    private func getRecentVisits() -> [OfficeVisit] {
        let sortedVisits = appData.visits
            .filter { $0.isValidVisit }
            .sorted { $0.date > $1.date }
        return Array(sortedVisits.prefix(3))
    }
    
    private func getRecentVisitsDisplayItems() -> [VisitDisplayItem] {
        // Include current active visit first
        var items: [VisitDisplayItem] = []
        
        if let currentVisit = appData.currentVisit, currentVisit.isActiveSession {
            items.append(VisitDisplayItem(
                id: currentVisit.id,
                date: currentVisit.date,
                dayOfWeek: currentVisit.dayOfWeek,
                duration: formatCurrentVisitDuration(currentVisit),
                isActiveSession: true
            ))
        }
        
        // Add completed visits
        let completedVisits = appData.visits
            .filter { $0.isValidVisit && !$0.isActiveSession }
            .sorted { $0.date > $1.date }
            .prefix(5)
        
        for visit in completedVisits {
            items.append(VisitDisplayItem(
                id: visit.id,
                date: visit.date,
                dayOfWeek: visit.dayOfWeek,
                duration: visit.formattedDuration,
                isActiveSession: false
            ))
        }
        
        return items
    }
    
    private func getTrendData() -> [TrendDataPoint] {
        let trend = appData.getVisitTrend(months: 9)
        return trend.map { TrendDataPoint(date: $0.date, value: $0.count) }
    }
    
}


// MARK: - Pulse Animation Modifier

struct PulseAnimation: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Legacy CircularProgressView (kept for compatibility)

struct CircularProgressView: View {
    let current: Int
    let goal: Int
    let percentage: Double
    var size: CGFloat = 200
    var strokeWidth: CGFloat = 12
    var gradient: LinearGradient = DesignTokens.accentBlue
    
    private var safePercentage: Double {
        guard !percentage.isNaN && !percentage.isInfinite && percentage >= 0 else { return 0.0 }
        return min(percentage, 1.0)
    }
    
    private var safePercentageDisplay: Int {
        let displayValue = Int(safePercentage * 100)
        return max(0, min(100, displayValue))
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(DesignTokens.ringBackground, lineWidth: strokeWidth)
                .frame(width: size, height: size)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: safePercentage)
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1), value: safePercentage)
            
            // Center content
            VStack(spacing: 4) {
                Text("\(current)")
                    .font(Typography.heroNumber)
                    .foregroundColor(DesignTokens.textPrimary)
                
                Text("of \(goal) days")
                    .font(Typography.cardTitle)
                    .foregroundColor(DesignTokens.textSecondary)
                
                Text("\(safePercentageDisplay)%")
                    .font(Typography.bodySecondary)
                    .foregroundColor(DesignTokens.cyanAccent)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Updated StatusCard with Design Tokens

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .iconBackground(color: color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.caption)
                    .foregroundColor(DesignTokens.textSecondary)
                Text(value)
                    .font(Typography.cardTitle)
                    .foregroundColor(DesignTokens.textPrimary)
            }
            
            Spacer()
        }
        .cardStyle()
    }
}

// MARK: - Updated MiniStatusCard with Design Tokens

struct MiniStatusCard: View {
    let title: String
    let value: String
    let icon: String
    var iconColor: Color = DesignTokens.cyanAccent
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .iconBackground(color: iconColor)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(Typography.caption)
                    .foregroundColor(DesignTokens.textSecondary)
                Text(value)
                    .font(Typography.cardTitle)
                    .foregroundColor(DesignTokens.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - Legacy RecentVisitsSection (kept for compatibility)

struct RecentVisitsSection: View {
    let visits: [OfficeVisit]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Visits")
                    .font(Typography.cardTitle)
                    .foregroundColor(DesignTokens.textPrimary)
                Spacer()
            }
            
            if visits.isEmpty {
                Text("No visits recorded yet")
                    .foregroundColor(DesignTokens.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .cardStyle()
            } else {
                VStack(spacing: 8) {
                    ForEach(visits) { visit in
                        VisitRow(visit: visit)
                    }
                }
            }
        }
    }
}

struct VisitRow: View {
    let visit: OfficeVisit
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(visit.formattedDate)
                    .font(Typography.bodySecondary)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.textPrimary)
                Text(visit.dayOfWeek)
                    .font(Typography.caption)
                    .foregroundColor(DesignTokens.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(visit.formattedDuration)
                    .font(Typography.bodySecondary)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.textPrimary)
                Text(formatTime(visit.entryTime))
                    .font(Typography.caption)
                    .foregroundColor(DesignTokens.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignTokens.cardBackground)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Goal Progress Section

struct GoalProgressSection: View {
    let current: Int
    let goal: Int
    let remaining: Int
    let daysLeft: Int
    @ObservedObject var appData: AppData
    
    @State private var showingCalculationDetails = false
    @State private var showingPTOPicker = false
    @State private var editingPTODate: Date?
    @State private var isPTOExpanded = false
    @State private var showingDeleteConfirmation = false
    @State private var dateToDelete: Date?
    
    private let currentMonth = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goal Progress")
                .font(Typography.cardTitle)
                .foregroundColor(DesignTokens.textPrimary)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Days completed")
                        .foregroundColor(DesignTokens.textSecondary)
                    Spacer()
                    Text("\(current)")
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.textPrimary)
                }
                
                HStack {
                    Text("Days remaining")
                        .foregroundColor(DesignTokens.textSecondary)
                    Spacer()
                    Text("\(remaining)")
                        .fontWeight(.medium)
                        .foregroundColor(remaining > 0 ? DesignTokens.orangeAccent : DesignTokens.successGreen)
                }
                
                HStack {
                    Text("Days left in month")
                        .foregroundColor(DesignTokens.textSecondary)
                    Spacer()
                    Text("\(daysLeft)")
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.textPrimary)
                }
                
                if remaining > 0 {
                    HStack {
                        Text("Pace needed")
                            .foregroundColor(DesignTokens.textSecondary)
                        Spacer()
                        Text(calculatePace())
                            .fontWeight(.medium)
                            .foregroundColor(DesignTokens.cyanAccent)
                    }
                }
                
                Divider()
                
                if appData.settings.autoCalculateGoal {
                    Button {
                        showingCalculationDetails = true
                    } label: {
                        HStack {
                            Image(systemName: "function")
                                .foregroundColor(DesignTokens.cyanAccent)
                            Text("Calculated Goal")
                                .foregroundColor(DesignTokens.textSecondary)
                            Spacer()
                            Text("\(goal) days")
                                .fontWeight(.medium)
                                .foregroundColor(DesignTokens.cyanAccent)
                            Image(systemName: "info.circle")
                                .foregroundColor(DesignTokens.cyanAccent)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // PTO/Sick Days Section
                    VStack(alignment: .leading, spacing: 0) {
                        // Header Button
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                let ptoCount = appData.getPTODays(for: currentMonth).count
                                if ptoCount > 0 {
                                    isPTOExpanded.toggle()
                                } else {
                                    editingPTODate = nil
                                    showingPTOPicker = true
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(DesignTokens.successGreen)
                                Text("PTO/Sick Days")
                                    .foregroundColor(DesignTokens.textSecondary)
                                Spacer()
                                let ptoCount = appData.getPTODays(for: currentMonth).count
                                Text(ptoCount > 0 ? "\(ptoCount) day\(ptoCount == 1 ? "" : "s")" : "Add")
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignTokens.cyanAccent)
                                Image(systemName: ptoCount > 0 ? (isPTOExpanded ? "chevron.up" : "chevron.down") : "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(DesignTokens.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // Expanded PTO List
                        if isPTOExpanded {
                            VStack(alignment: .leading, spacing: 0) {
                                let ptoDays = appData.getPTODays(for: currentMonth).sorted()
                                
                                if ptoDays.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("No PTO days this month")
                                            .foregroundColor(DesignTokens.textSecondary)
                                            .font(.subheadline)
                                            .padding(.top, 12)
                                    }
                                } else {
                                    ForEach(ptoDays, id: \.self) { date in
                                        HStack {
                                            Image(systemName: "calendar")
                                                .foregroundColor(DesignTokens.successGreen)
                                                .font(.subheadline)
                                            Text(formatPTODate(date))
                                                .foregroundColor(DesignTokens.textPrimary)
                                            Spacer()
                                            Button {
                                                dateToDelete = date
                                                showingDeleteConfirmation = true
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(DesignTokens.textSecondary)
                                                    .font(.system(size: 16))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.top, date == ptoDays.first ? 12 : 0)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            editingPTODate = date
                                            showingPTOPicker = true
                                        }
                                        .accessibilityLabel("\(formatPTODate(date)), double tap to edit")
                                        .accessibilityHint("Tap delete button to remove")
                                    }
                                }
                                
                                // Add PTO Button
                                Button {
                                    editingPTODate = nil
                                    showingPTOPicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(DesignTokens.cyanAccent)
                                        Text("Add PTO Day")
                                            .foregroundColor(DesignTokens.cyanAccent)
                                        Spacer()
                                    }
                                    .padding(.top, 12)
                                }
                                .buttonStyle(.plain)
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(DesignTokens.textSecondary)
                        Text("Manual Goal")
                            .foregroundColor(DesignTokens.textSecondary)
                        Spacer()
                        Text("\(goal) days")
                            .fontWeight(.medium)
                            .foregroundColor(DesignTokens.textPrimary)
                    }
                }
            }
            .font(Typography.bodySecondary)
        }
        .cardStyle()
        .sheet(isPresented: $showingCalculationDetails) {
            CalculationDetailsSheet(appData: appData)
        }
        .sheet(isPresented: $showingPTOPicker) {
            PTOPickerSheet(appData: appData, month: currentMonth, editingDate: editingPTODate)
        }
        .alert("Remove PTO Day?", isPresented: $showingDeleteConfirmation, presenting: dateToDelete) { date in
            Button("Cancel", role: .cancel) {
                dateToDelete = nil
            }
            Button("Remove", role: .destructive) {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                appData.removePTODay(date)
                dateToDelete = nil
            }
        } message: { date in
            Text("Remove PTO/Sick day for \(formatDeleteConfirmation(date))?")
        }
    }
    
    private func formatPTODate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func formatDeleteConfirmation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private func calculatePace() -> String {
        guard daysLeft > 0 && remaining > 0 else { 
            if remaining <= 0 {
                return "Goal complete!"
            } else {
                return "0.0 days/week"
            }
        }
        
        let workingDaysPerWeek = appData.settings.trackingDays.count
        guard workingDaysPerWeek > 0 else { return "No tracking days set" }
        
        let dailyRate = Double(remaining) / Double(daysLeft)
        guard !dailyRate.isNaN && !dailyRate.isInfinite else { return "0.0 days/week" }
        
        let weeklyRate = dailyRate * Double(workingDaysPerWeek)
        
        if weeklyRate > Double(workingDaysPerWeek) {
            return "Goal unreachable"
        } else {
            // Round to match MacroRingCard display (which uses Int(rounded()))
            let roundedRate = weeklyRate.rounded()
            return String(format: "%.0f days/week", roundedRate)
        }
    }
}


// MARK: - Calculation Details Sheet

struct CalculationDetailsSheet: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) private var dismiss
    
    private let currentMonth = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    let breakdown = appData.getGoalCalculationBreakdown(for: currentMonth)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        CalculationDetailRow(label: "Weekdays in month", value: "\(breakdown.weekdaysInMonth)")
                        
                        if breakdown.holidayCount > 0 {
                            CalculationDetailRow(label: "Holidays", value: "− \(breakdown.holidayCount)", color: DesignTokens.orangeAccent)
                        }
                        
                        CalculationDetailRow(label: "Business days", value: "\(breakdown.businessDays)")
                        
                        if breakdown.ptoCount > 0 {
                            CalculationDetailRow(label: "PTO/Sick days", value: "− \(breakdown.ptoCount)", color: DesignTokens.orangeAccent)
                        }
                        
                        CalculationDetailRow(label: "Working days", value: "\(breakdown.workingDays)")
                        
                        CalculationDetailRow(label: "Policy (\(breakdown.percentageString))", value: "× \(breakdown.percentageString)", color: DesignTokens.cyanAccent)
                        
                        Divider()
                        
                        HStack {
                            Text("Required days")
                                .font(.headline)
                            Spacer()
                            Text("\(breakdown.requiredDays)")
                                .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignTokens.cyanAccent)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(monthName)
                }
                
                Section {
                    HStack {
                        Text("Policy")
                        Spacer()
                        Text(appData.settings.companyPolicy.displayName)
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                    
                    HStack {
                        Text("Holiday Calendar")
                        Spacer()
                        Text(appData.settings.holidayCalendar.preset.displayName)
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                } header: {
                    Text("Settings")
                }
            }
            .navigationTitle("Goal Calculation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
}

struct CalculationDetailRow: View {
    let label: String
    let value: String
    var color: Color = DesignTokens.textPrimary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(DesignTokens.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .font(.subheadline)
    }
}

#Preview {
    @Previewable @State var selectedTab: MainTabView.Tab = .home
    MainProgressView(appData: AppData(), selectedTab: $selectedTab)
}
