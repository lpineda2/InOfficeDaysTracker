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
    @Environment(\.dismiss) private var dismiss
    
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
                    dismiss()
                }
                .disabled(!tempSettings.isValidConfiguration)
            }
        }
        .onAppear {
            loadCurrentSettings()
            permissionHandler.updateAuthorizationStatus()
        }
        .onChange(of: selectedCalendar) { oldCalendar, newCalendar in
            print("📅 [CalendarSettings] Selected calendar changed")
            if let calendar = newCalendar {
                print("  - New calendar: \(calendar.title) (ID: \(calendar.calendarIdentifier))")
                tempSettings.selectedCalendarId = calendar.calendarIdentifier
            } else {
                print("  - Calendar deselected")
                tempSettings.selectedCalendarId = nil
            }
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
                    // Use enhanced loading method with retry logic instead of immediate loading
                    Task {
                        await calendarService.loadCalendarsAfterPermissionGrant()
                    }
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
                        TextField("In Office Day", text: $tempSettings.officeEventTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    if tempSettings.includeRemoteEvents {
                        HStack {
                            Text("Remote Event")
                                .frame(width: 100, alignment: .leading)
                            TextField("Remote Work", text: $tempSettings.remoteEventTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
            }
            .disabled(!tempSettings.isEnabled)
        } header: {
            Text("Event Customization")
        } footer: {
            if tempSettings.includeRemoteEvents {
                Text("Customize how your office and remote work events appear in your calendar.")
            } else {
                Text("Customize how your office events appear in your calendar. Enable remote work events below to add remote event customization.")
            }
        }
    }
    
    private var timingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Create all-day events", isOn: $tempSettings.createAllDayEvents)
                    .disabled(!tempSettings.isEnabled)
                
                if !tempSettings.createAllDayEvents {
                    Toggle("Use actual visit times", isOn: $tempSettings.useActualTimes)
                        .disabled(!tempSettings.isEnabled)
                    
                    if !tempSettings.useActualTimes {
                        Text("Events will use your standard work hours (9:00 AM - 5:00 PM)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("All-day events don't use specific times")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Toggle("Include remote work events", isOn: $tempSettings.includeRemoteEvents)
                    .disabled(!tempSettings.isEnabled)
            }
        } header: {
            Text("Event Timing")
        } footer: {
            Text("All-day events span the entire day without specific times. Timed events can use either your actual visit times or standard work hours.")
        }
    }
    
    private var advancedSection: some View {
        Section {
            Button("Reset to Defaults") {
                showingResetConfirmation = true
            }
            .foregroundColor(.red)
            .disabled(!tempSettings.isEnabled)
            
        } header: {
            Text("Advanced Options")
        } footer: {
            Text("Reset all calendar settings to their default values.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentSettings() {
        print("📖 [CalendarSettings] Loading current settings...")
        tempSettings = appData.settings.calendarSettings
        print("  - Loaded enabled: \(tempSettings.isEnabled)")
        print("  - Loaded calendar ID: \(tempSettings.selectedCalendarId ?? "none")")
        
        // Load selected calendar if available
        if let calendarId = tempSettings.selectedCalendarId,
           calendarService.hasCalendarAccess {
            print("  - Loading available calendars...")
            calendarService.loadAvailableCalendars()
            print("  - Available calendars: \(calendarService.availableCalendars.count)")
            
            selectedCalendar = calendarService.availableCalendars.first { calendar in
                calendar.calendarIdentifier == calendarId
            }
            
            if let calendar = selectedCalendar {
                print("  ✅ Found matching calendar: \(calendar.title)")
            } else {
                print("  ❌ No matching calendar found for ID: \(calendarId)")
            }
        } else {
            print("  - No calendar ID or no access")
        }
    }
    
    private func saveSettings() {
        print("💾 [CalendarSettings] Saving settings...")
        print("  - Enabled: \(tempSettings.isEnabled)")
        print("  - Selected calendar ID: \(tempSettings.selectedCalendarId ?? "none")")
        print("  - Office title: '\(tempSettings.officeEventTitle)'")
        
        // Make sure selected calendar ID is set if we have a selected calendar
        if let calendar = selectedCalendar {
            tempSettings.selectedCalendarId = calendar.calendarIdentifier
            print("  - Updated calendar ID from selected calendar: \(calendar.calendarIdentifier)")
        }
        
        // Update the calendar settings using tempSettings
        var updatedSettings = appData.settings
        updatedSettings.calendarSettings = tempSettings
        
        print("  - Calling appData.updateSettings...")
        
        // Save using the public method
        appData.updateSettings(updatedSettings)
        
        // Update the local copy to match what we just saved
        calendarSettings = tempSettings
        
        print("  ✅ Settings saved successfully")
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