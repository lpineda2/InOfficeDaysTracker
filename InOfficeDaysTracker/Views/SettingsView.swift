//
//  SettingsView.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import SwiftUI
import CoreLocation
import UIKit

struct SettingsView: View {
    private var usesImperial: Bool {
        if #available(iOS 16.0, *) {
            return Locale.current.measurementSystem != .metric
        } else {
            return !Locale.current.usesMetricSystem
        }
    }

    private var regionSpecificRadius: String {
        if usesImperial {
            let miles = detectionRadius / 1609.34
            return String(format: "%.2f miles", miles)
        } else {
            let km = detectionRadius / 1000.0
            return String(format: "%.2f km", km)
        }
    }
    @ObservedObject var appData: AppData
    
    @State private var officeAddress: String = ""
    @State private var officeCoordinate: CLLocationCoordinate2D?
    @State private var detectionRadius: Double = 1609.34
    @State private var trackingDays: Set<Int> = []
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var monthlyGoal: Int = 12
    @State private var notificationsEnabled: Bool = true
    
    @State private var showingResetAlert = false
    @State private var isUpdatingLocation = false
    @State private var updateError: String?
    
    var body: some View {
        Form {
            goalsSection
            officeLocationsSection
            trackingSection
            calendarSection
            notificationsSection
            dataSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadCurrentSettings()
        }
        .onChange(of: trackingDays) {
            autoSaveSettings()
        }
        .onChange(of: notificationsEnabled) {
            autoSaveSettings()
        }
        .alert("Reset All Data", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                appData.clearAllData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all visit history and reset your settings. This action cannot be undone.")
        }
    }
    
    // MARK: - Goals Section (Updated for Auto-Calculate)
    
    private var goalsSection: some View {
        Section {
            NavigationLink(destination: PolicySettingsView(appData: appData)) {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(DesignTokens.cyanAccent)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly Goal")
                            .font(.body)
                        
                        Text(goalStatusText)
                            .font(.caption)
                                .foregroundColor(DesignTokens.textSecondary)
                    }
                    
                    Spacer()
                }
            }
        } header: {
            Text("Goals")
        } footer: {
            Text("Configure manual or policy-based goal calculation.")
        }
    }
    
    private var goalStatusText: String {
        if appData.settings.autoCalculateGoal {
            let goal = appData.getGoalForMonth(Date())
            return "Auto-calculate: \(goal) days this month"
        } else {
            return "Manual: \(appData.settings.monthlyGoal) days"
        }
    }
    
    // MARK: - Office Locations Section (New)
    
    private var officeLocationsSection: some View {
        Section {
            NavigationLink(destination: OfficeLocationsView(appData: appData)) {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(DesignTokens.cyanAccent)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Office Locations")
                            .font(.body)
                        
                        Text(locationsStatusText)
                            .font(.caption)
                                .foregroundColor(DesignTokens.textSecondary)
                    }
                    
                    Spacer()
                }
            }
        } header: {
            Text("Locations")
        } footer: {
            Text("Visits to any configured location count toward your goal.")
        }
    }
    
    private var locationsStatusText: String {
        let count = appData.settings.officeLocations.count
        if count == 0 {
            // Check legacy single location
            if appData.settings.officeLocation != nil {
                return "1 location configured"
            }
            return "No locations configured"
        } else if count == 1 {
            return "1 location configured"
        } else {
            return "\(count) locations configured"
        }
    }
    
    private var locationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Office Address")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.textSecondary)
                
                AddressAutocompleteField(
                    selectedAddress: $officeAddress,
                    selectedCoordinate: $officeCoordinate,
                    placeholder: "Enter office address"
                )
                
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
                    Text(regionSpecificRadius)
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.cyanAccent)
                }

                // Slider always stores meters, but endpoints are region-specific
                // Step is .25 miles (402.335 meters) or .25 km (250 meters)
                // Range: 0.25 to 1 mile (402.335m to 1609.34m) or 0.25 to 1 km (250m to 1000m)
                Slider(value: $detectionRadius,
                       in: usesImperial ? 402.335...1609.34 : 250...1000,
                       step: usesImperial ? 402.335 : 250)
                    .tint(DesignTokens.cyanAccent)

                // Only show min/max labels matching slider range
                HStack {
                    Text(usesImperial ? "0.25 mile" : "0.25 km")
                        .font(.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                    Spacer()
                    Text(usesImperial ? "1 mile" : "1 km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Removed outdated '1 mile'/'10 miles' labels
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
    
    private var calendarSection: some View {
        Section {
            NavigationLink(destination: CalendarSettingsView(appData: appData)) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calendar Integration")
                            .font(.body)
                        
                        Text(calendarStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        } header: {
            Text("Integration")
        } footer: {
            Text("Automatically create calendar events for office visits and remote work days.")
        }
    }
    
    private var calendarStatusText: String {
        if appData.settings.calendarSettings.isEnabled {
            return "Enabled - Events will be created"
        } else {
            return "Tap to configure calendar integration"
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
    
    /// Auto-save settings when simple values change (for tab-based navigation)
    private func autoSaveSettings() {
        var newSettings = appData.settings
        newSettings.trackingDays = Array(trackingDays)
        newSettings.notificationsEnabled = notificationsEnabled
        newSettings.officeHours.startTime = startTime
        newSettings.officeHours.endTime = endTime
        newSettings.monthlyGoal = monthlyGoal
        appData.updateSettings(newSettings)
    }
    
    private func saveSettings() {
        isUpdatingLocation = true
        updateError = nil
        
        Task {
            do {
                // Use coordinate from autocomplete if available, otherwise geocode the address
                var newLocation = appData.settings.officeLocation
                if officeAddress != appData.settings.officeAddress && !officeAddress.isEmpty {
                    if let officeCoordinate = officeCoordinate {
                        newLocation = officeCoordinate
                    } else {
                        let locationService = LocationService()
                        newLocation = try await locationService.geocodeAddress(officeAddress)
                    }
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
    @State private var exportFileURL: URL?
    
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
                .disabled(appData.visits.isEmpty && appData.currentVisit == nil)
                
                if appData.visits.isEmpty && appData.currentVisit == nil {
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
            .sheet(isPresented: $showingShareSheet, onDismiss: {
                // Reset state when ShareSheet is dismissed
                exportFileURL = nil
                exportedData = ""
            }) {
                ShareSheet(
                    fileURL: exportFileURL,
                    csvContent: exportedData
                )
            }
            .onChange(of: exportFileURL) { _, _ in
                // Only present if file/data is ready and not already showing
                if (exportFileURL != nil || !exportedData.isEmpty) && !showingShareSheet {
                    showingShareSheet = true
                }
            }
        }
    }
    
    private func exportData() {
        // Use visits array directly - currentVisit is already synchronized with visits array
        // by our duplicate prevention system, so no need to add it separately
        var allVisits = appData.visits
        
        // Sort visits by date (most recent first)
        allVisits.sort { $0.date > $1.date }
        
        // Create CSV content
        let header = "Date,Day,Entry Time,Exit Time,Duration (hours)\n"
        var csvContent = header
        
        if allVisits.isEmpty {
            csvContent += "No visits recorded yet,,,0.00\n"
        } else {
            var rows: [String] = []
            
            for visit in allVisits {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short
                
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEEE"
                
                let date = dateFormatter.string(from: visit.date)
                let day = dayFormatter.string(from: visit.date)
                let entryTime = timeFormatter.string(from: visit.entryTime)
                let exitTime = visit.exitTime != nil ? timeFormatter.string(from: visit.exitTime!) : "In Progress"
                let duration = visit.duration != nil ? String(format: "%.2f", visit.duration! / 3600) : "N/A"
                
                let row = "\(date),\(day),\(entryTime),\(exitTime),\(duration)"
                rows.append(row)
            }
            
            csvContent += rows.joined(separator: "\n")
        }
        
        // Create a file for sharing
        let finalCSVContent = csvContent
        
        if let fileURL = createCSVFile(content: finalCSVContent) {
            exportFileURL = fileURL
            exportedData = finalCSVContent
        } else {
            // Create a temporary file with proper CSV content for fallback
            if let fallbackFileURL = createFallbackCSVFile(content: finalCSVContent) {
                exportFileURL = fallbackFileURL
                exportedData = finalCSVContent
            } else {
                // Final fallback to text sharing
                exportFileURL = nil
                exportedData = finalCSVContent
            }
        }
        // Sheet will be presented by .onChange of exportFileURL
    }
    
    private func createCSVFile(content: String) -> URL? {
        // Ensure we have valid content to write
        guard !content.isEmpty && content.count > 10 else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "office_visits_\(dateFormatter.string(from: Date())).csv"
        
        // Strategy 1: Try temporary directory (often works better for sharing)
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try content.write(to: tempFileURL, atomically: true, encoding: .utf8)
            
            // Verify file was written correctly
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: tempFileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                if fileSize > 0 {
                    return tempFileURL
                }
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 2: Try documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let docFileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try content.write(to: docFileURL, atomically: true, encoding: .utf8)
            
            // Verify file was written correctly
            if FileManager.default.fileExists(atPath: docFileURL.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: docFileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                if fileSize > 0 {
                    return docFileURL
                }
            }
        } catch {
            // File creation failed
        }
        
        return nil
    }
    
    private func createFallbackCSVFile(content: String) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "office_visits_fallback_\(dateFormatter.string(from: Date())).csv"
        
        // Try creating in the app's cache directory
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let cacheFileURL = cachesDir.appendingPathComponent(fileName)
        
        do {
            try content.write(to: cacheFileURL, atomically: true, encoding: .utf8)
            
            // Verify file exists and has content
            if FileManager.default.fileExists(atPath: cacheFileURL.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: cacheFileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                if fileSize > 0 {
                    return cacheFileURL
                }
            }
        } catch {
            // File creation failed
        }
        
        return nil
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let fileURL: URL?
    let csvContent: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Determine items to share based on current state
        let items: [Any]
        
        // Always prioritize file sharing if we have a valid file URL
        if let fileURL = fileURL {
            items = [fileURL]
        } else if !csvContent.isEmpty && csvContent.count > 50 { // Ensure we have substantial content
            items = [csvContent]
        } else {
            // Provide a meaningful fallback message
            let fallbackMessage = "No visit data available to export. Start tracking your office visits to generate exportable data."
            items = [fallbackMessage]
        }
        
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // For files, ensure we're setting the proper content type
        if let fileURL = fileURL {
            controller.setValue(fileURL.lastPathComponent, forKey: "subject")
        } else {
            controller.setValue("Office Visits Data", forKey: "subject")
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView(appData: AppData())
}
