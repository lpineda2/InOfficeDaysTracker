//
//  SettingsView.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import SwiftUI
import CoreLocation

struct SettingsView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) private var dismiss
    
    @State private var officeAddress: String = ""
    @State private var detectionRadius: Double = 1609.34
    @State private var trackingDays: Set<Int> = []
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var monthlyGoal: Int = 12
    @State private var notificationsEnabled: Bool = true
    
    @State private var showingLocationUpdate = false
    @State private var showingResetAlert = false
    @State private var isUpdatingLocation = false
    @State private var updateError: String?
    
    var body: some View {
        NavigationView {
            Form {
                locationSection
                trackingSection
                goalsSection
                notificationsSection
                dataSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
            .alert("Reset All Data", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) {
                    appData.clearAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all visit history and reset your settings. This action cannot be undone.")
            }
        }
    }
    
    private var locationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Office Address")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Enter office address", text: $officeAddress)
                    .textFieldStyle(.roundedBorder)
                
                if let error = updateError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Detection Radius")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.0f", detectionRadius))m")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Slider(value: $detectionRadius, in: 500...5000, step: 100)
                    .tint(.blue)
                
                HStack {
                    Text("500m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("5km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Office Location")
        } footer: {
            Text("Your office location is used for automatic visit detection. The detection radius determines how close you need to be to your office.")
        }
    }
    
    private var trackingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tracking Days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    ForEach(Array(zip(1...7, ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])), id: \.0) { dayIndex, dayName in
                        HStack {
                            Text(dayName)
                                .font(.body)
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { trackingDays.contains(dayIndex) },
                                set: { isOn in
                                    if isOn {
                                        trackingDays.insert(dayIndex)
                                    } else {
                                        trackingDays.remove(dayIndex)
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Office Hours")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Start Time")
                        .font(.body)
                    Spacer()
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                
                HStack {
                    Text("End Time")
                        .font(.body)
                    Spacer()
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Tracking Preferences")
        } footer: {
            Text("Choose which days to track and set your typical office hours for more accurate visit detection.")
        }
    }
    
    private var goalsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Monthly Goal")
                        .font(.body)
                    Spacer()
                    Text("\(monthlyGoal) days")
                        .font(.body)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                Slider(value: Binding(
                    get: { Double(monthlyGoal) },
                    set: { monthlyGoal = Int($0) }
                ), in: 1...31, step: 1)
                .tint(.blue)
                
                HStack {
                    Text("1 day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("31 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Goals")
        } footer: {
            Text("Set your target number of office days per month to track your progress.")
        }
    }
    
    private var notificationsSection: some View {
        Section {
            Toggle("Enable Notifications", isOn: $notificationsEnabled)
                .font(.body)
        } header: {
            Text("Notifications")
        } footer: {
            Text("Receive notifications when office visits are detected and goal reminders.")
        }
    }
    
    private var dataSection: some View {
        Section {
            NavigationLink {
                DataExportView(appData: appData)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("Export Data")
                        .font(.body)
                }
            }
            
            Button {
                showingResetAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("Reset All Data")
                        .font(.body)
                        .foregroundColor(.red)
                }
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("Export your visit history or reset all data. Resetting cannot be undone.")
        }
    }
    
    private func loadCurrentSettings() {
        let settings = appData.settings
        officeAddress = settings.officeAddress
        detectionRadius = settings.detectionRadius
        trackingDays = Set(settings.trackingDays)
        startTime = settings.officeHours.startTime
        endTime = settings.officeHours.endTime
        monthlyGoal = settings.monthlyGoal
        notificationsEnabled = settings.notificationsEnabled
    }
    
    private func saveSettings() {
        isUpdatingLocation = true
        updateError = nil
        
        Task {
            do {
                // If address changed, geocode it
                var newLocation = appData.settings.officeLocation
                if officeAddress != appData.settings.officeAddress && !officeAddress.isEmpty {
                    let locationService = LocationService()
                    newLocation = try await locationService.geocodeAddress(officeAddress)
                }
                
                // Update settings
                var newSettings = appData.settings
                newSettings.officeAddress = officeAddress
                newSettings.officeLocation = newLocation
                newSettings.detectionRadius = detectionRadius
                newSettings.trackingDays = Array(trackingDays)
                newSettings.officeHours.startTime = startTime
                newSettings.officeHours.endTime = endTime
                newSettings.monthlyGoal = monthlyGoal
                newSettings.notificationsEnabled = notificationsEnabled
                
                await MainActor.run {
                    appData.updateSettings(newSettings)
                    
                    // Update geofencing if location changed
                    if let newLoc = newLocation,
                       let oldLoc = appData.settings.officeLocation,
                       !coordinatesEqual(newLoc, oldLoc) {
                        let locationService = LocationService()
                        locationService.setAppData(appData)
                        locationService.setupGeofencing()
                    } else if newLocation != nil && appData.settings.officeLocation == nil {
                        // First time setting location
                        let locationService = LocationService()
                        locationService.setAppData(appData)
                        locationService.setupGeofencing()
                    }
                    
                    isUpdatingLocation = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpdatingLocation = false
                    updateError = "Could not find the office location. Please check the address."
                }
            }
        }
    }
    
    private func coordinatesEqual(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Bool {
        return abs(coord1.latitude - coord2.latitude) < 0.000001 && abs(coord1.longitude - coord2.longitude) < 0.000001
    }
}

struct DataExportView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) private var dismiss
    
    @State private var exportedData = ""
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Visit History")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Export your visit history as a CSV file that can be opened in spreadsheet applications.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Export CSV") {
                    exportData()
                }
                .buttonStyle(.borderedProminent)
                .disabled(appData.visits.isEmpty)
                
                if appData.visits.isEmpty {
                    Text("No visit history to export")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [exportedData])
            }
        }
    }
    
    private func exportData() {
        let header = "Date,Day,Entry Time,Exit Time,Duration (hours)\n"
        let rows = appData.visits.map { visit in
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            
            let date = formatter.string(from: visit.date)
            let day = visit.dayOfWeek
            let entryTime = formatter.string(from: visit.entryTime)
            let exitTime = visit.exitTime != nil ? formatter.string(from: visit.exitTime!) : "In Progress"
            let duration = visit.duration != nil ? String(format: "%.2f", visit.duration! / 3600) : "N/A"
            
            return "\(date),\(day),\(entryTime),\(exitTime),\(duration)"
        }.joined(separator: "\n")
        
        exportedData = header + rows
        showingShareSheet = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView(appData: AppData())
}
