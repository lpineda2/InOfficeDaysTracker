//
//  HolidaySettingsView.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 1/13/26.
//

import SwiftUI

struct HolidaySettingsView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPreset: HolidayPreset
    @State private var customRemovals: Set<USHoliday> = []
    @State private var showingAddCustomHoliday = false
    @State private var customHolidayDate = Date()
    @State private var customHolidayName = ""
    
    private let currentYear = Calendar.current.component(.year, from: Date())
    
    init(appData: AppData) {
        self.appData = appData
        _selectedPreset = State(initialValue: appData.settings.holidayCalendar.preset)
        _customRemovals = State(initialValue: Set(appData.settings.holidayCalendar.customRemovals.compactMap { $0.holiday }))
    }
    
    var body: some View {
        Form {
            presetSection
            holidaysListSection
            customHolidaysSection
        }
        .navigationTitle("Holiday Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPreset) { _, newValue in
            updatePreset(newValue)
        }
        .sheet(isPresented: $showingAddCustomHoliday) {
            addCustomHolidaySheet
        }
    }
    
    // MARK: - Preset Section
    
    private var presetSection: some View {
        Section {
            Picker("Preset", selection: $selectedPreset) {
                ForEach(HolidayPreset.allCases) { preset in
                    VStack(alignment: .leading) {
                        Text(preset.displayName)
                        Text(preset.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(preset)
                }
            }
            .pickerStyle(.navigationLink)
            
            HStack {
                Text("Total Holidays")
                Spacer()
                Text("\(appData.settings.holidayCalendar.holidayCount(for: currentYear)) days")
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }
        } header: {
            Text("Preset")
        } footer: {
            Text(presetFooterText)
        }
    }
    
    private var presetFooterText: String {
        switch selectedPreset {
        case .sifma:
            return "Standard 12-day schedule for brokerages and financial services."
        case .sifmaModified:
            return "SIFMA schedule excluding Columbus Day and Veterans Day."
        case .nyse:
            return "New York Stock Exchange market holiday schedule."
        case .usFederal:
            return "US Federal government holiday schedule."
        case .none:
            return "No preset holidays. Add custom holidays below."
        }
    }
    
    // MARK: - Holidays List Section
    
    private var holidaysListSection: some View {
        Section {
            ForEach(selectedPreset.holidays) { holiday in
                HolidayRow(
                    holiday: holiday,
                    year: currentYear,
                    isEnabled: !customRemovals.contains(holiday),
                    onToggle: { toggleHoliday(holiday) }
                )
            }
        } header: {
            Text(verbatim: "\(currentYear) Holidays")
        } footer: {
            if selectedPreset != .none {
                Text("Tap to include or exclude individual holidays from the preset.")
            }
        }
    }
    
    // MARK: - Custom Holidays Section
    
    private var customHolidaysSection: some View {
        Section {
            Button {
                showingAddCustomHoliday = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("Add Custom Holiday")
                        .foregroundColor(.primary)
                }
            }
            
            ForEach(appData.settings.holidayCalendar.customAdditions, id: \.displayName) { holidayDate in
                if let date = holidayDate.date(for: currentYear) {
                    HStack {
                        Text(holidayDate.displayName)
                        Spacer()
                        Text(formatDate(date))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteCustomHoliday)
        } header: {
            Text("Custom Holidays")
        } footer: {
            Text("Add company-specific holidays not included in the preset.")
        }
    }
    
    // MARK: - Add Custom Holiday Sheet
    
    private var addCustomHolidaySheet: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Holiday Name", text: $customHolidayName)
                    DatePicker("Date", selection: $customHolidayDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Custom Holiday")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingAddCustomHoliday = false
                        customHolidayName = ""
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addCustomHoliday()
                    }
                    .disabled(customHolidayName.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func updatePreset(_ preset: HolidayPreset) {
        var newSettings = appData.settings
        newSettings.holidayCalendar.preset = preset
        // Clear custom removals when changing preset
        newSettings.holidayCalendar.customRemovals = []
        customRemovals = []
        appData.updateSettings(newSettings)
    }
    
    private func toggleHoliday(_ holiday: USHoliday) {
        var newSettings = appData.settings
        if customRemovals.contains(holiday) {
            customRemovals.remove(holiday)
            newSettings.holidayCalendar.customRemovals.removeAll { $0.holiday == holiday }
        } else {
            customRemovals.insert(holiday)
            newSettings.holidayCalendar.customRemovals.append(HolidayDate(holiday: holiday))
        }
        appData.updateSettings(newSettings)
    }
    
    private func addCustomHoliday() {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: customHolidayDate)
        let day = calendar.component(.day, from: customHolidayDate)
        
        var newSettings = appData.settings
        let newHoliday = HolidayDate(month: month, day: day, name: customHolidayName)
        newSettings.holidayCalendar.customAdditions.append(newHoliday)
        appData.updateSettings(newSettings)
        
        showingAddCustomHoliday = false
        customHolidayName = ""
    }
    
    private func deleteCustomHoliday(at offsets: IndexSet) {
        var newSettings = appData.settings
        newSettings.holidayCalendar.customAdditions.remove(atOffsets: offsets)
        appData.updateSettings(newSettings)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Holiday Row

struct HolidayRow: View {
    let holiday: USHoliday
    let year: Int
    let isEnabled: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isEnabled ? .blue : .secondary)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(holiday.rawValue)
                        .foregroundColor(isEnabled ? .primary : .secondary)
                    
                    if let date = holiday.date(for: year) {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        HolidaySettingsView(appData: AppData())
    }
}
