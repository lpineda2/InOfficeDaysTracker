//
//  CalendarSettingsView.swift
//  InOfficeDaysTracker
//
//  Calendar integration settings UI
//

import SwiftUI
import EventKit

struct CalendarSettingsView: View {
    @ObservedObject var appData: AppData
    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var permissionHandler = CalendarPermissionHandler()
    
    @State private var calendarSettings: CalendarSettings
    @State private var tempSettings: CalendarSettings
    @State private var selectedCalendar: EKCalendar?
    @State private var showingResetConfirmation = false
    @State private var showingCalendarPicker = false
    
    init(appData: AppData) {
        self.appData = appData
        self._calendarSettings = State(initialValue: appData.settings.calendarSettings)
        self._tempSettings = State(initialValue: appData.settings.calendarSettings)
    }
    
    var body: some View {
        Form {
            if permissionHandler.hasAccess {
                enabledSettingsView
            } else {
                permissionSectionView
            }
        }
        .navigationTitle("Calendar Integration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveSettings()
                }
                .disabled(!tempSettings.isValidConfiguration)
            }
        }
        .onAppear {
            loadCurrentSettings()
            permissionHandler.updateAuthorizationStatus()
        }
        .alert("Reset Calendar Settings", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) {
                resetSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reset all calendar integration settings to their defaults. This action cannot be undone.")
        }
    }
    
    // MARK: - Permission Section
    
    private var permissionSectionView: some View {
        Section {
            CalendarPermissionView(
                permissionHandler: permissionHandler,
                onGranted: {
                    permissionHandler.updateAuthorizationStatus()
                    calendarService.loadAvailableCalendars()
                },
                onSkipped: { }
            )
        }
    }
    
    // MARK: - Enabled Settings View
    
    private var enabledSettingsView: some View {
        Group {
            mainSettingsSection
            eventCustomizationSection
            timingSection
            advancedSection
        }
    }
    
    private var mainSettingsSection: some View {
        Section {
            CalendarSettingsRow(
                calendarService: calendarService,
                selectedCalendar: $selectedCalendar,
                isEnabled: $tempSettings.isEnabled
            )
            
            if tempSettings.isEnabled && selectedCalendar != nil {
                calendarStatusView
            }
        } header: {
            Text("Calendar Integration")
        } footer: {
            Text("Create calendar events for office visits and remote work days to visualize your work patterns.")
        }
    }
    
    private var calendarStatusView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading) {
                Text("Calendar Connected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let calendar = selectedCalendar {
                    Text("Events will be created in \"\(calendar.title)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var eventCustomizationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Event Titles")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Office Event")
                            .frame(width: 100, alignment: .leading)
                        TextField("Office Day", text: $tempSettings.officeEventTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Remote Event")
                            .frame(width: 100, alignment: .leading)
                        TextField("Remote Work", text: $tempSettings.remoteEventTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
            .disabled(!tempSettings.isEnabled)
        } header: {
            Text("Event Customization")
        } footer: {
            Text("Customize how your work events appear in your calendar.")
        }
    }
    
    private var timingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Use actual visit times", isOn: $tempSettings.useActualTimes)
                    .disabled(!tempSettings.isEnabled)
                
                if !tempSettings.useActualTimes {
                    Text("Events will use your standard work hours (9:00 AM - 5:00 PM)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Toggle("Create all-day events", isOn: $tempSettings.createAllDayEvents)
                    .disabled(!tempSettings.isEnabled)
                
                Toggle("Include remote work events", isOn: $tempSettings.includeRemoteEvents)
                    .disabled(!tempSettings.isEnabled)
            }
        } header: {
            Text("Event Timing")
        } footer: {
            Text("Choose how event times are calculated and which events to create.")
        }
    }
    
    private var advancedSection: some View {
        Section {
            Picker("Time Zone", selection: $tempSettings.timeZoneMode) {
                ForEach(CalendarSettings.TimeZoneMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .disabled(!tempSettings.isEnabled)
            
            Picker("Update Frequency", selection: $tempSettings.batchMode) {
                ForEach(CalendarSettings.BatchMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .disabled(!tempSettings.isEnabled)
            
            Button("Reset to Defaults") {
                showingResetConfirmation = true
            }
            .foregroundColor(.red)
            .disabled(!tempSettings.isEnabled)
            
        } header: {
            Text("Advanced Options")
        } footer: {
            Text("Configure time zones and event update behavior.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentSettings() {
        tempSettings = appData.settings.calendarSettings
        
        // Load selected calendar if available
        if let calendarId = tempSettings.selectedCalendarId,
           calendarService.hasCalendarAccess {
            calendarService.loadAvailableCalendars()
            selectedCalendar = calendarService.availableCalendars.first { calendar in
                calendar.calendarIdentifier == calendarId
            }
        }
    }
    
    private func saveSettings() {
        // Update the calendar settings
        var updatedSettings = appData.settings
        updatedSettings.calendarSettings = calendarSettings
        
        // Save using the public method
        appData.updateSettings(updatedSettings)
    }
    
    private func resetSettings() {
        tempSettings.resetToDefaults()
        selectedCalendar = nil
    }
}

// MARK: - Preview

struct CalendarSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CalendarSettingsView(appData: AppData())
        }
    }
}