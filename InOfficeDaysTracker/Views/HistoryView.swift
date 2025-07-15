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
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMonth = Date()
    @State private var showingDeleteAlert = false
    @State private var visitToDelete: OfficeVisit?
    @State private var showingAddVisitSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month selector
                monthSelector
                // Add Visit button
                HStack {
                    Spacer()
                    Button {
                        showingAddVisitSheet = true
                    } label: {
                        Label("Add Visit", systemImage: "plus")
                            .font(.headline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(Color(.systemGray6))
                // Visit list
                visitList
            }
            .navigationTitle("Visit History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
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
    }
    
    private var monthSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    withAnimation {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                Spacer()
                Text(monthName(for: selectedMonth))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    withAnimation {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
            }
            // Month stats
            HStack(spacing: 24) {
                StatView(title: "Visits", value: "\(appData.getValidVisits(for: selectedMonth).count)")
                StatView(title: "Goal", value: "\(appData.settings.monthlyGoal)")
                StatView(title: "Progress", value: "\(Int(Double(appData.getValidVisits(for: selectedMonth).count) / Double(appData.settings.monthlyGoal) * 100))%")
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var visitList: some View {
        let visits = appData.getValidVisits(for: selectedMonth)
            .sorted { $0.date > $1.date }
        
        return Group {
            if visits.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(visits) { visit in
                        VisitDetailRow(visit: visit) {
                            visitToDelete = visit
                            showingDeleteAlert = true
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No visits recorded")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Office visits for \(monthName(for: selectedMonth)) will appear here when you spend time at your office location.")
                .font(.body)
                .foregroundColor(.secondary)
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
                    DatePicker("Visit Date", selection: $visitDate, displayedComponents: .date)
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
                .foregroundColor(.blue)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct VisitDetailRow: View {
    let visit: OfficeVisit
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(visit.formattedDate)
                        .font(.headline)
                        .fontWeight(.medium)
                    Text(visit.dayOfWeek)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(visit.formattedDuration)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Entry Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(visit.entryTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if let exitTime = visit.exitTime {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Exit Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatTime(exitTime))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                } else {
                    Text("In Progress")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", role: .destructive) {
                onDelete()
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
