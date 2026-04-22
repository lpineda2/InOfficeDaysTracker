//
//  HistoryView.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import SwiftUI
import CoreLocation

struct HistoryView: View {
    @ObservedObject var appData: AppData
    @State private var selectedMonth = Date()
    @State private var showingDeleteAlert = false
    @State private var visitToDelete: OfficeVisit?
    @State private var showingAddVisitSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Month selector card
                monthSelector
                
                // Visit list
                visitList
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color(.systemBackground))
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddVisitSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddVisitSheet) {
            AddVisitSheet(appData: appData, isPresented: $showingAddVisitSheet)
        }
        .alert("Delete Visit", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let visit = visitToDelete {
                    appData.deleteVisit(visit)
                    visitToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                visitToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this visit? This action cannot be undone.")
        }
    }
    
    private var monthSelector: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    withAnimation {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.cyanAccent)
                }
                Spacer()
                Text(monthName(for: selectedMonth))
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    withAnimation {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.cyanAccent)
                }
                .opacity(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month) ? 0.3 : 1.0)
                .disabled(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
            }
            
            // Month stats
            HStack(spacing: 32) {
                StatView(title: "Visits", value: "\(appData.getValidVisits(for: selectedMonth).count)")
                StatView(title: "Goal", value: "\(appData.getGoalForMonth(selectedMonth))")
                StatView(title: "Progress", value: progressPercentage)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private var progressPercentage: String {
        let visits = appData.getValidVisits(for: selectedMonth).count
        let goal = appData.getGoalForMonth(selectedMonth)
        guard goal > 0 else { return "0%" }
        return "\(Int(Double(visits) / Double(goal) * 100))%"
    }
    
    private var visitList: some View {
        let visits = appData.getValidVisits(for: selectedMonth)
            .sorted { $0.date > $1.date }
        
        return Group {
            if visits.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(visits) { visit in
                        VisitCard(visit: visit) {
                            visitToDelete = visit
                            showingDeleteAlert = true
                        }
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(Typography.iconL)
                .foregroundColor(DesignTokens.textTertiary)
            
            Text("No visits recorded")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Office visits for \(monthName(for: selectedMonth)) will appear here when you spend time at your office location.")
                .font(.body)
                .foregroundColor(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// Manual Visit Entry Sheet
struct AddVisitSheet: View {
    @ObservedObject var appData: AppData
    @Binding var isPresented: Bool

    @State private var visitDate: Date = Date()
    @State private var entryTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var exitTime: Date = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notes: String = ""
    @State private var showValidationError = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Date")) {
                    DatePicker("Visit Date", selection: $visitDate, in: ...Date(), displayedComponents: .date)
                }
                Section(header: Text("Entry Time")) {
                    DatePicker("Entry Time", selection: $entryTime, displayedComponents: .hourAndMinute)
                }
                Section(header: Text("Exit Time")) {
                    DatePicker("Exit Time", selection: $exitTime, displayedComponents: .hourAndMinute)
                }
                Section(header: Text("Notes (optional)")) {
                    TextField("Notes", text: $notes)
                }
                if showValidationError {
                    Text("Exit time must be after entry time and duration at least 1 hour, and no duplicate visit for this day.")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Add Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if exitTime > entryTime && exitTime.timeIntervalSince(entryTime) >= 3600 {
                            let defaultCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
                            let duration = exitTime.timeIntervalSince(entryTime)
                            let visit = OfficeVisit(date: visitDate,
                                                    entryTime: entryTime,
                                                    exitTime: exitTime,
                                                    duration: duration,
                                                    coordinate: defaultCoordinate)
                            // Use new addVisit method to prevent duplicates
                            if appData.addVisit(visit) {
                                isPresented = false
                            } else {
                                showValidationError = true
                            }
                        } else {
                            showValidationError = true
                        }
                    }
                }
            }
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignTokens.cyanAccent)
            Text(title)
                .font(.caption)
                .foregroundColor(DesignTokens.textSecondary)
        }
    }
}

struct VisitCard: View {
    let visit: OfficeVisit
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: Date and Duration
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(visit.formattedDate)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.textPrimary)
                    Text(visit.dayOfWeek)
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(visit.formattedDuration)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.cyanAccent)
                        Text("Duration")
                        .font(.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
            
            // Bottom row: Entry and Exit times
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Entry Time")
                        .font(.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                    Text(formatTime(visit.entryTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.textPrimary)
                }
                
                Spacer()
                
                if let exitTime = visit.exitTime {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Exit Time")
                            .font(.caption)
                            .foregroundColor(DesignTokens.textSecondary)
                        Text(formatTime(exitTime))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(DesignTokens.textPrimary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(DesignTokens.textSecondary)
                        Text("In Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(DesignTokens.orangeAccent)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryView(appData: AppData())
}
