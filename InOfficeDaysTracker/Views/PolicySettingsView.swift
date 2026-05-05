//
//  PolicySettingsView.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 1/13/26.
//

import SwiftUI

struct PolicySettingsView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) private var dismiss
    
    @State private var autoCalculateGoal: Bool
    @State private var manualGoal: Int
    @State private var policyType: PolicyType
    @State private var customPercentage: Int
    @State private var roundingMode: RoundingMode
    @State private var showingPTOPicker = false
    
    private let currentMonth = Date()
    
    init(appData: AppData) {
        self.appData = appData
        _autoCalculateGoal = State(initialValue: appData.settings.autoCalculateGoal)
        _manualGoal = State(initialValue: appData.settings.monthlyGoal)
        _policyType = State(initialValue: appData.settings.companyPolicy.policyType)
        _customPercentage = State(initialValue: appData.settings.companyPolicy.customPercentage)
        _roundingMode = State(initialValue: appData.settings.companyPolicy.roundingMode)
    }
    
    var body: some View {
        Form {
            calculationMethodSection
            
            if autoCalculateGoal {
                companyPolicySection
                holidayCalendarSection
                ptoSection
                calculationPreviewSection
            } else {
                manualGoalSection
            }
        }
        .navigationTitle("Monthly Goal")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: autoCalculateGoal) { _, newValue in
            saveAutoCalculateSetting(newValue)
        }
        .onChange(of: manualGoal) { _, newValue in
            saveManualGoal(newValue)
        }
        .onChange(of: policyType) { _, newValue in
            savePolicyType(newValue)
        }
        .onChange(of: customPercentage) { _, newValue in
            saveCustomPercentage(newValue)
        }
        .onChange(of: roundingMode) { _, newValue in
            saveRoundingMode(newValue)
        }
        .sheet(isPresented: $showingPTOPicker) {
            PTOPickerSheet(appData: appData, month: currentMonth)
        }
    }
    
    // MARK: - Calculation Method Section
    
    private var calculationMethodSection: some View {
        Section {
            Toggle("Auto-calculate based on policy", isOn: $autoCalculateGoal)
        } header: {
            Text("Calculation Method")
        } footer: {
            Text(autoCalculateGoal 
                 ? "Goal is calculated from business days, holidays, and PTO."
                 : "You set a fixed goal each month manually.")
        }
    }
    
    // MARK: - Company Policy Section
    
    private var companyPolicySection: some View {
        Section {
            Picker("Policy Type", selection: $policyType) {
                ForEach(PolicyType.allCases) { type in
                    VStack(alignment: .leading) {
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.navigationLink)
            
            if policyType == .custom {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Required Percentage")
                            .font(.body)
                        Spacer()
                        Text("\(customPercentage)%")
                            .font(.body)
                            .foregroundColor(DesignTokens.cyanAccent)
                            .fontWeight(.medium)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(customPercentage) },
                        set: { customPercentage = Int($0) }
                    ), in: 0...100, step: 5)
                    .tint(DesignTokens.cyanAccent)
                    
                    HStack {
                        Text("0%")
                            .font(.caption)
                            .foregroundColor(DesignTokens.textSecondary)
                        Spacer()
                        Text("100%")
                            .font(.caption)
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Rounding Mode Picker
            Picker("Rounding Mode", selection: $roundingMode) {
                ForEach(RoundingMode.allCases) { mode in
                    Text(mode.displayName)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Company Policy")
        } footer: {
            Text(roundingMode.description)
        }
    }
    
    // MARK: - Holiday Calendar Section
    
    private var holidayCalendarSection: some View {
        Section {
            NavigationLink(destination: HolidaySettingsView(appData: appData)) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(DesignTokens.cyanAccent)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Holiday Calendar")
                            .font(.body)
                        Text("\(appData.settings.holidayCalendar.preset.displayName) (\(appData.settings.holidayCalendar.preset.holidayCount))")
                            .font(.caption)
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - PTO Section
    
    private var ptoSection: some View {
        Section {
            Button {
                showingPTOPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(DesignTokens.cyanAccent)
                    Text("Add PTO/Sick Day")
                        .foregroundColor(DesignTokens.textPrimary)
                }
            }
            
            let ptoDays = appData.getPTODays(for: currentMonth)
            if ptoDays.isEmpty {
                Text("No PTO days added for this month")
                    .foregroundColor(DesignTokens.textSecondary)
                    .font(.subheadline)
            } else {
                ForEach(ptoDays, id: \.self) { date in
                    HStack {
                        Text(formatDate(date))
                        Spacer()
                        Button {
                            appData.removePTODay(date)
                        } label: {
                                Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignTokens.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            Text("PTO / Sick Days — \(currentMonthName)")
        } footer: {
            Text("Days off reduce your required total for the month.")
        }
    }
    
    // MARK: - Calculation Preview Section
    
    private var calculationPreviewSection: some View {
        Section {
            let breakdown = appData.getGoalCalculationBreakdown(for: currentMonth)
            
            VStack(alignment: .leading, spacing: 12) {
                CalculationRow(label: "Weekdays in month", value: "\(breakdown.weekdaysInMonth)")
                
                if breakdown.holidayCount > 0 {
                    CalculationRow(label: "Holidays", value: "− \(breakdown.holidayCount)", color: DesignTokens.orangeAccent)
                }
                
                CalculationRow(label: "Business days", value: "\(breakdown.businessDays)")
                
                if breakdown.ptoCount > 0 {
                    CalculationRow(label: "PTO/Sick days", value: "− \(breakdown.ptoCount)", color: DesignTokens.orangeAccent)
                }
                
                CalculationRow(label: "Working days", value: "\(breakdown.workingDays)")
                
                CalculationRow(label: "Policy (\(breakdown.percentageString))", value: "× \(breakdown.percentageString)", color: DesignTokens.cyanAccent)
                
                Divider()
                
                HStack {
                    Text("Required days")
                        .font(.headline)
                    Spacer()
                    Text("\(breakdown.requiredDays)")
                        .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.cyanAccent)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("\(currentMonthName) Calculation")
        }
    }
    
    // MARK: - Manual Goal Section
    
    private var manualGoalSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Monthly Goal")
                        .font(.body)
                    Spacer()
                    Text("\(manualGoal) days")
                        .font(.body)
                        .foregroundColor(DesignTokens.cyanAccent)
                        .fontWeight(.medium)
                }
                
                Slider(value: Binding(
                    get: { Double(manualGoal) },
                    set: { manualGoal = Int($0) }
                ), in: 1...31, step: 1)
                .tint(DesignTokens.cyanAccent)
                
                HStack {
                    Text("1 day")
                        .font(.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                    Spacer()
                    Text("31 days")
                        .font(.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Manual Goal")
        } footer: {
            Text("Your target number of office days per month.")
        }
    }
    
    // MARK: - Helper Methods
    
    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
    
    // MARK: - Save Methods
    
    private func saveAutoCalculateSetting(_ value: Bool) {
        var newSettings = appData.settings
        newSettings.autoCalculateGoal = value
        appData.updateSettings(newSettings)
    }
    
    private func saveManualGoal(_ value: Int) {
        var newSettings = appData.settings
        newSettings.monthlyGoal = value
        appData.updateSettings(newSettings)
    }
    
    private func savePolicyType(_ value: PolicyType) {
        var newSettings = appData.settings
        newSettings.companyPolicy.policyType = value
        appData.updateSettings(newSettings)
    }
    
    private func saveCustomPercentage(_ value: Int) {
        var newSettings = appData.settings
        newSettings.companyPolicy.customPercentage = value
        appData.updateSettings(newSettings)
    }
    
    private func saveRoundingMode(_ value: RoundingMode) {
        var newSettings = appData.settings
        newSettings.companyPolicy.roundingMode = value
        appData.updateSettings(newSettings)
    }
}

// MARK: - Calculation Row

struct CalculationRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(DesignTokens.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .font(.subheadline)
    }
}

// MARK: - PTO Picker Sheet

struct PTOPickerSheet: View {
    @ObservedObject var appData: AppData
    let month: Date
    let editingDate: Date?
    @Environment(\.dismiss) private var dismiss
    
    enum SelectionMode {
        case single
        case range
    }
    
    @State private var mode: SelectionMode = .single
    @State private var selectedDate = Date()
    @State private var startDate = Date()
    @State private var endDate = Date()
    
    init(appData: AppData, month: Date, editingDate: Date? = nil) {
        self.appData = appData
        self.month = month
        self.editingDate = editingDate
        _selectedDate = State(initialValue: editingDate ?? Date())
        _startDate = State(initialValue: editingDate ?? Date())
        _endDate = State(initialValue: editingDate ?? Date())
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Mode selection (only show for new entries, not edits)
                if editingDate == nil {
                    Section {
                        Picker("Selection Mode", selection: $mode) {
                            Text("Single Day").tag(SelectionMode.single)
                            Text("Date Range").tag(SelectionMode.range)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                // Date selection based on mode
                if mode == .single {
                    singleDaySection
                } else {
                    dateRangeSection
                }
                
                // Validation and summary
                validationSection
                
                // Holidays reference
                holidaysSection
            }
            .navigationTitle(editingDate == nil ? "Add PTO Days" : "Edit PTO Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editingDate == nil ? "Add" : "Update") {
                        saveDays()
                    }
                    .disabled(mode == .range && startDate > endDate)
                }
            }
        }
    }
    
    private var singleDaySection: some View {
        Section {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: monthDateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
        } header: {
            Text("Select PTO/Sick Day")
        }
    }
    
    private var dateRangeSection: some View {
        Section {
            DatePicker(
                "Start Date",
                selection: $startDate,
                in: monthDateRange,
                displayedComponents: .date
            )
            
            DatePicker(
                "End Date",
                selection: $endDate,
                in: startDate...monthEnd,
                displayedComponents: .date
            )
        } header: {
            Text("Select Date Range")
        } footer: {
            if startDate > endDate {
                Text("End date must be after start date")
                    .foregroundColor(.red)
            } else {
                Text("Weekends and holidays will be excluded automatically")
                    .foregroundColor(DesignTokens.textSecondary)
            }
        }
    }
    
    private var validationSection: some View {
        Section {
            if mode == .range {
                let dates = generateDateRange()
                let holidays = getHolidaysInRange(dates)
                
                // Show effective count
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Total Days:")
                        Spacer()
                        Text("\(dates.count)")
                            .fontWeight(.semibold)
                    }
                    
                    // Show warning if range includes holidays
                    if !holidays.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                        
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Holidays in Range")
                                    .fontWeight(.semibold)
                                    .font(.subheadline)
                                
                                Text("These dates are already excluded as holidays:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(holidays, id: \.self) { date in
                                    Text("• \(formatDate(date))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        HStack {
                            Text("PTO Days to Add:")
                            Spacer()
                            Text("\(dates.count)")
                                .fontWeight(.semibold)
                                .foregroundColor(DesignTokens.cyanAccent)
                        }
                        
                        Text("(\(holidays.count) holiday\(holidays.count == 1 ? "" : "s") excluded)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            if mode == .range {
                Text("Summary")
            }
        }
    }
    
    private var holidaysSection: some View {
        Section {
            let holidays = appData.getHolidaysInMonth(month)
            if !holidays.isEmpty {
                ForEach(holidays, id: \.self) { date in
                    HStack {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text(formatDate(date))
                        Text("(Holiday)")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
            } else {
                Text("No holidays this month")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Holidays (Already Excluded)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateDateRange() -> [Date] {
        guard mode == .range else { return [selectedDate] }
        
        var dates: [Date] = []
        var current = startDate
        let calendar = Calendar.current
        let holidays = appData.getHolidaysInMonth(month)
        
        while current <= endDate {
            // Include if it's a tracking day AND not a holiday
            let weekday = calendar.component(.weekday, from: current)
            let isTrackingDay = appData.settings.trackingDays.contains(weekday)
            let isHolidayDate = holidays.contains { holiday in
                calendar.isDate(current, inSameDayAs: holiday)
            }
            
            if isTrackingDay && !isHolidayDate {
                dates.append(current)
            }
            
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        return dates
    }
    
    private func getHolidaysInRange(_ dates: [Date]) -> [Date] {
        let allHolidays = appData.getHolidaysInMonth(month)
        let calendar = Calendar.current
        
        return dates.compactMap { date in
            // Check if this date was supposed to be in the range (before filtering)
            guard date >= startDate && date <= endDate else { return nil }
            
            // Return if it's a holiday
            return allHolidays.contains { holiday in
                calendar.isDate(date, inSameDayAs: holiday)
            } ? date : nil
        }
    }
    
    private func saveDays() {
        if let oldDate = editingDate {
            appData.removePTODay(oldDate)
        }
        
        let dates = mode == .single ? [selectedDate] : generateDateRange()
        
        // Add all dates
        for date in dates {
            appData.addPTODay(date)
        }
        
        dismiss()
    }
    
    private var monthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)
        let startOfMonth = calendar.date(from: components) ?? month
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? month
        return startOfMonth...endOfMonth
    }
    
    private var monthEnd: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)
        let startOfMonth = calendar.date(from: components) ?? month
        return calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? month
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        PolicySettingsView(appData: AppData())
    }
}
