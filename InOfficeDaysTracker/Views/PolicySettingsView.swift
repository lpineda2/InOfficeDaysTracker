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
    @State private var showingPTOPicker = false
    
    private let currentMonth = Date()
    
    init(appData: AppData) {
        self.appData = appData
        _autoCalculateGoal = State(initialValue: appData.settings.autoCalculateGoal)
        _manualGoal = State(initialValue: appData.settings.monthlyGoal)
        _policyType = State(initialValue: appData.settings.companyPolicy.policyType)
        _customPercentage = State(initialValue: appData.settings.companyPolicy.customPercentage)
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
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(customPercentage) },
                        set: { customPercentage = Int($0) }
                    ), in: 0...100, step: 5)
                    .tint(.blue)
                    
                    HStack {
                        Text("0%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Company Policy")
        } footer: {
            Text(policyType.description)
        }
    }
    
    // MARK: - Holiday Calendar Section
    
    private var holidayCalendarSection: some View {
        Section {
            NavigationLink(destination: HolidaySettingsView(appData: appData)) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Holiday Calendar")
                            .font(.body)
                        Text("\(appData.settings.holidayCalendar.preset.displayName) (\(appData.settings.holidayCalendar.preset.holidayCount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        .foregroundColor(.blue)
                    Text("Add PTO/Sick Day")
                        .foregroundColor(.primary)
                }
            }
            
            let ptoDays = appData.getPTODays(for: currentMonth)
            if ptoDays.isEmpty {
                Text("No PTO days added for this month")
                    .foregroundColor(.secondary)
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
                                .foregroundColor(.secondary)
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
                    CalculationRow(label: "Holidays", value: "− \(breakdown.holidayCount)", color: .orange)
                }
                
                CalculationRow(label: "Business days", value: "\(breakdown.businessDays)")
                
                if breakdown.ptoCount > 0 {
                    CalculationRow(label: "PTO/Sick days", value: "− \(breakdown.ptoCount)", color: .orange)
                }
                
                CalculationRow(label: "Working days", value: "\(breakdown.workingDays)")
                
                CalculationRow(label: "Policy (\(breakdown.percentageString))", value: "× \(breakdown.percentageString)", color: .blue)
                
                Divider()
                
                HStack {
                    Text("Required days")
                        .font(.headline)
                    Spacer()
                    Text("\(breakdown.requiredDays)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
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
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                Slider(value: Binding(
                    get: { Double(manualGoal) },
                    set: { manualGoal = Int($0) }
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
        appData.settings.autoCalculateGoal = value
        appData.updateSettings(appData.settings)
    }
    
    private func saveManualGoal(_ value: Int) {
        appData.settings.monthlyGoal = value
        appData.updateSettings(appData.settings)
    }
    
    private func savePolicyType(_ value: PolicyType) {
        appData.settings.companyPolicy.policyType = value
        appData.updateSettings(appData.settings)
    }
    
    private func saveCustomPercentage(_ value: Int) {
        appData.settings.companyPolicy.customPercentage = value
        appData.updateSettings(appData.settings)
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
                .foregroundColor(.secondary)
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
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
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
            .navigationTitle("Add PTO Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        appData.addPTODay(selectedDate)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var monthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)
        let startOfMonth = calendar.date(from: components) ?? month
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? month
        return startOfMonth...endOfMonth
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
