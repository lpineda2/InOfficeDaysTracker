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
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Grid layout: 2 columns
    private let columns = [
        GridItem(.flexible(), spacing: DesignTokens.gridSpacing),
        GridItem(.flexible(), spacing: DesignTokens.gridSpacing)
    ]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DesignTokens.gridSpacing) {
                // Header with month
                headerSection
                
                // Hero Progress Card (Macro Ring style)
                MacroRingCard(
                    daysCompleted: progressData.current,
                    daysGoal: progressData.goal,
                    daysRemaining: max(0, progressData.goal - progressData.current),
                    paceNeeded: appData.getPaceNeeded(),
                    weeksRemaining: appData.getWeeksRemaining()
                )
                
                // Status Card (if in office)
                if appData.isCurrentlyInOffice, let currentVisit = appData.currentVisit {
                    currentStatusCard(visit: currentVisit)
                }
                
                // Mini Metric Cards - 2 column grid
                LazyVGrid(columns: columns, spacing: DesignTokens.gridSpacing) {
                    StreakMetricCard(
                        streakMonths: appData.getMonthlyStreak(),
                        isOnTrack: appData.isCurrentMonthGoalMet()
                    )
                    
                    DurationMetricCard(
                        averageHours: getAverageDuration()
                    )
                }
                
                // Trend Chart
                TrendChartCard(
                    data: getTrendData(),
                    hasEnoughData: appData.hasEnoughChartData(days: 90)
                )
                
                // Recent Visits - tapping "See All" switches to History tab
                RecentVisitsList(
                    visits: getRecentVisitsDisplayItems(),
                    onSeeAllTapped: { selectedTab = .history }
                )
                    
                    // Goal Progress Details
                    GoalProgressSection(
                        current: progressData.current,
                        goal: progressData.goal,
                        remaining: max(0, progressData.goal - progressData.current),
                        daysLeft: appData.getWorkingDaysRemaining(),
                        appData: appData
                    )
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .background(DesignTokens.appBackground)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                currentTime = Date()
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
    
    private func getAverageDuration() -> Double {
        let validVisits = appData.getValidVisits(for: Date())
        guard !validVisits.isEmpty else { return 0.0 }
        
        let totalDuration = validVisits.compactMap { $0.duration }.reduce(0, +)
        let count = Double(validVisits.count)
        guard count > 0 else { return 0.0 }
        
        let average = (totalDuration / count) / 3600 // Convert to hours
        guard !average.isNaN && !average.isInfinite else { return 0.0 }
        return average
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
        let trend = appData.getVisitTrend(days: 90)
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
                    
                    Button {
                        showingPTOPicker = true
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
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignTokens.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
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
            PTOPickerSheet(appData: appData, month: currentMonth)
        }
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
            return String(format: "%.1f days/week", weeklyRate)
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
                            CalculationDetailRow(label: "Holidays", value: "− \(breakdown.holidayCount)", color: .orange)
                        }
                        
                        CalculationDetailRow(label: "Business days", value: "\(breakdown.businessDays)")
                        
                        if breakdown.ptoCount > 0 {
                            CalculationDetailRow(label: "PTO/Sick days", value: "− \(breakdown.ptoCount)", color: .orange)
                        }
                        
                        CalculationDetailRow(label: "Working days", value: "\(breakdown.workingDays)")
                        
                        CalculationDetailRow(label: "Policy (\(breakdown.percentageString))", value: "× \(breakdown.percentageString)", color: .blue)
                        
                        Divider()
                        
                        HStack {
                            Text("Required days")
                                .font(.headline)
                            Spacer()
                            Text("\(breakdown.requiredDays)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
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
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Holiday Calendar")
                        Spacer()
                        Text(appData.settings.holidayCalendar.preset.displayName)
                            .foregroundColor(.secondary)
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
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
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
