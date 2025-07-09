//
//  MainProgressView.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import SwiftUI

struct MainProgressView: View {
    @ObservedObject var appData: AppData
    
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("This Month")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(getCurrentMonthName())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Progress Circle
                    CircularProgressView(
                        current: progressData.current,
                        goal: progressData.goal,
                        percentage: progressData.percentage
                    )
                    .padding(.vertical)
                    
                    // Status Cards
                    VStack(spacing: 16) {
                        StatusCard(
                            title: "Current Status",
                            value: appData.isCurrentlyInOffice ? "In Office" : "Away",
                            icon: appData.isCurrentlyInOffice ? "building.2.fill" : "house.fill",
                            color: appData.isCurrentlyInOffice ? .green : .orange
                        )
                        
                        if let currentVisit = appData.currentVisit {
                            StatusCard(
                                title: "Current Visit",
                                value: formatCurrentVisitDuration(currentVisit),
                                icon: "clock.fill",
                                color: .blue
                            )
                        }
                        
                        HStack(spacing: 12) {
                            MiniStatusCard(
                                title: "This Week",
                                value: "\(getWeeklyProgress())",
                                icon: "calendar.badge.clock"
                            )
                            
                            MiniStatusCard(
                                title: "Average",
                                value: String(format: "%.1fh", getAverageDuration()),
                                icon: "chart.bar.fill"
                            )
                        }
                    }
                    
                    // Recent Visits
                    RecentVisitsSection(visits: getRecentVisits())
                    
                    // Goal Progress Details
                    GoalProgressSection(
                        current: progressData.current,
                        goal: progressData.goal,
                        remaining: max(0, progressData.goal - progressData.current),
                        daysLeft: getDaysRemainingInMonth()
                    )
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Office Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingHistory = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView(appData: appData)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(appData: appData)
            }
            .onAppear {
                currentTime = Date()
            }
            .onReceive(timer) { _ in
                if appData.isCurrentlyInOffice {
                    currentTime = Date() // Just trigger UI update
                }
            }
        }
    }
    
    private var progressData: (current: Int, goal: Int, percentage: Double) {
        appData.getCurrentMonthProgress()
    }
    
    private func getCurrentMonthName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    private func formatCurrentVisitDuration(_ visit: OfficeVisit) -> String {
        let now = Date()
        let duration = now.timeIntervalSince(visit.entryTime)
        guard !duration.isNaN && !duration.isInfinite && duration >= 0 else { return "Invalid duration" }
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
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
    
    private func getDaysRemainingInMonth() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        return calendar.dateComponents([.day], from: now, to: endOfMonth).day ?? 0
    }
}

struct CircularProgressView: View {
    let current: Int
    let goal: Int
    let percentage: Double
    
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
                .stroke(Color(.systemGray5), lineWidth: 12)
                .frame(width: 200, height: 200)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: safePercentage)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1), value: safePercentage)
            
            // Center content
            VStack(spacing: 4) {
                Text("\(current)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("of \(goal) days")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("\(safePercentageDisplay)%")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }
        }
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct MiniStatusCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct RecentVisitsSection: View {
    let visits: [OfficeVisit]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Visits")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if visits.isEmpty {
                Text("No visits recorded yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
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
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(visit.dayOfWeek)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(visit.formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(formatTime(visit.entryTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct GoalProgressSection: View {
    let current: Int
    let goal: Int
    let remaining: Int
    let daysLeft: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goal Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Days completed")
                    Spacer()
                    Text("\(current)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Days remaining")
                    Spacer()
                    Text("\(remaining)")
                        .fontWeight(.medium)
                        .foregroundColor(remaining > 0 ? .orange : .green)
                }
                
                HStack {
                    Text("Days left in month")
                    Spacer()
                    Text("\(daysLeft)")
                        .fontWeight(.medium)
                }
                
                if remaining > 0 {
                    HStack {
                        Text("Pace needed")
                        Spacer()
                        Text(calculatePace())
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func calculatePace() -> String {
        guard daysLeft > 0 && remaining > 0 else { 
            if remaining <= 0 {
                return "Goal complete!"
            } else {
                return "0.0 days/week"
            }
        }
        let pace = Double(remaining) / Double(daysLeft)
        guard !pace.isNaN && !pace.isInfinite else { return "0.0 days/week" }
        return String(format: "%.1f days/week", pace * 7)
    }
}

#Preview {
    MainProgressView(appData: AppData())
}
