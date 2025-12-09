//
//  CalendarSettingsView.swift
//  InOfficeDaysTracker
//
//  Simplified calendar integration settings UI
//

import SwiftUI
import EventKit

struct CalendarSettingsView: View {
    @ObservedObject var appData: AppData
    @ObservedObject private var calendarService = CalendarService.shared
    @StateObject private var permissionHandler = CalendarPermissionHandler()
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempSettings: CalendarSettings
    @State private var selectedCalendar: EKCalendar?
    @State private var showingResetConfirmation = false
    
    init(appData: AppData) {
        self.appData = appData
        self._tempSettings = State(initialValue: appData.settings.calendarSettings)
    }
    
    /// Check both permission handler and calendar service for access
    private var hasCalendarAccess: Bool {
        permissionHandler.hasAccess || calendarService.hasCalendarAccess
    }
    
    var body: some View {
        Form {
            if hasCalendarAccess {
                calendarSettingsSection
                eventCustomizationSection
                resetSection
            } else {
                permissionSection
            }
        }
        .navigationTitle("Calendar Integration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveSettings()
                    dismiss()
                }
                .disabled(!tempSettings.isValidConfiguration)
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
        .onChange(of: tempSettings.isEnabled) { _, isEnabled in
            if isEnabled && calendarService.availableCalendars.isEmpty {
                calendarService.loadAvailableCalendars()
            }
        }
        .onChange(of: selectedCalendar) { _, newCalendar in
            tempSettings.selectedCalendarId = newCalendar?.calendarIdentifier
        }
        .alert("Reset Settings", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) { resetSettings() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Reset calendar settings to defaults?")
        }
    }
    
    // MARK: - Permission Section
    
    private var permissionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundColor(.orange)
                        .font(.title2)
                    Text("Calendar Access Required")
                        .font(.headline)
                }
                
                Text("Grant calendar access to create events for your office visits.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if permissionHandler.wasDenied {
                    Button("Open Settings") {
                        permissionHandler.openSettings()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Grant Access") {
                        print("📅 [CalendarSettings] Grant Access button tapped")
                        print("📅 [CalendarSettings] isRequestingPermission: \(permissionHandler.isRequestingPermission)")
                        Task {
                            print("📅 [CalendarSettings] Starting permission request task")
                            let granted = await permissionHandler.requestPermission()
                            print("📅 [CalendarSettings] Permission granted: \(granted)")
                            if granted {
                                // Sync CalendarService status and load calendars
                                calendarService.setAccessGranted()
                                calendarService.loadAvailableCalendars()
                                // Auto-enable calendar integration since user just granted access
                                tempSettings.isEnabled = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(permissionHandler.isRequestingPermission)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Calendar Settings Section
    
    private var calendarSettingsSection: some View {
        Section {
            Toggle("Enable Calendar Integration", isOn: $tempSettings.isEnabled)
            
            if tempSettings.isEnabled {
                Picker("Calendar", selection: $selectedCalendar) {
                    Text("Select Calendar").tag(nil as EKCalendar?)
                    ForEach(calendarService.availableCalendars, id: \.calendarIdentifier) { calendar in
                        HStack {
                            Circle()
                                .fill(Color(cgColor: calendar.cgColor))
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(calendar.title)
                                Text(calendar.source.title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(calendar as EKCalendar?)
                    }
                }
                
                if selectedCalendar != nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Calendar connected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Calendar")
        } footer: {
            Text("Office visit events will be created as all-day events in your selected calendar.")
        }
    }
    
    // MARK: - Event Customization Section
    
    private var eventCustomizationSection: some View {
        Section {
            HStack {
                Text("Event Title")
                Spacer()
                TextField("In Office Day", text: $tempSettings.officeEventTitle)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 200)
            }
            .disabled(!tempSettings.isEnabled)
        } header: {
            Text("Event Appearance")
        } footer: {
            Text("Customize how your office events appear in your calendar.")
        }
    }
    
    // MARK: - Reset Section
    
    private var resetSection: some View {
        Section {
            Button("Reset to Defaults", role: .destructive) {
                showingResetConfirmation = true
            }
            .disabled(!tempSettings.isEnabled)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentSettings() {
        tempSettings = appData.settings.calendarSettings
        
        // Sync permission handler status
        permissionHandler.updateAuthorizationStatus()
        
        // Check both permission handler and calendar service for access
        let hasAccess = permissionHandler.hasAccess || calendarService.hasCalendarAccess
        print("📅 [CalendarSettings] loadCurrentSettings - permissionHandler.hasAccess: \(permissionHandler.hasAccess), calendarService.hasCalendarAccess: \(calendarService.hasCalendarAccess)")
        
        // Always load available calendars when we have access
        if hasAccess {
            calendarService.loadAvailableCalendars()
            print("📅 [CalendarSettings] Loaded \(calendarService.availableCalendars.count) calendars")
            
            // If we have a previously selected calendar, find it
            if let calendarId = tempSettings.selectedCalendarId {
                selectedCalendar = calendarService.availableCalendars.first { $0.calendarIdentifier == calendarId }
            }
        }
    }
    
    private func saveSettings() {
        if let calendar = selectedCalendar {
            tempSettings.selectedCalendarId = calendar.calendarIdentifier
        }
        
        var updatedSettings = appData.settings
        updatedSettings.calendarSettings = tempSettings
        appData.updateSettings(updatedSettings)
    }
    
    private func resetSettings() {
        tempSettings.resetToDefaults()
        selectedCalendar = nil
    }
}
