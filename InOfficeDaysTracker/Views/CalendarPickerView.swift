//
//  CalendarPickerView.swift
//  InOfficeDaysTracker
//
//  Calendar selection component for setup and settings
//

import SwiftUI
import EventKit

struct CalendarPickerView: View {
    @ObservedObject var calendarService: CalendarService
    @Binding var selectedCalendar: EKCalendar?
    
    let title: String
    let subtitle: String?
    let showSkipOption: Bool
    let onCalendarSelected: (EKCalendar?) -> Void
    let onSkipped: (() -> Void)?
    
    init(
        calendarService: CalendarService,
        selectedCalendar: Binding<EKCalendar?>,
        title: String = "Choose Your Calendar",
        subtitle: String? = nil,
        showSkipOption: Bool = false,
        onCalendarSelected: @escaping (EKCalendar?) -> Void,
        onSkipped: (() -> Void)? = nil
    ) {
        self.calendarService = calendarService
        self._selectedCalendar = selectedCalendar
        self.title = title
        self.subtitle = subtitle
        self.showSkipOption = showSkipOption
        self.onCalendarSelected = onCalendarSelected
        self.onSkipped = onSkipped
    }
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            
            if calendarService.availableCalendars.isEmpty {
                emptyStateView
            } else {
                calendarListView
            }
            
            if showSkipOption {
                skipButtonView
            }
        }
        .onAppear {
            calendarService.loadAvailableCalendars()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("No Available Calendars")
                .font(.headline)
            
            Text("No writable calendars found. Please check your calendar settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var calendarListView: some View {
        VStack(spacing: 0) {
            ForEach(calendarService.availableCalendars, id: \.calendarIdentifier) { calendar in
                CalendarRowView(
                    calendar: calendar,
                    isSelected: selectedCalendar?.calendarIdentifier == calendar.calendarIdentifier,
                    onTap: {
                        selectedCalendar = calendar
                        onCalendarSelected(calendar)
                    }
                )
            }
        }
        .background(Color(.systemGroupedBackground))
        .cornerRadius(10)
    }
    
    private var skipButtonView: some View {
        Button("Skip Calendar Setup") {
            onSkipped?()
        }
        .buttonStyle(.bordered)
    }
}

struct CalendarRowView: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Calendar color indicator
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 16, height: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(calendarSourceName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var calendarSourceName: String {
        guard let source = calendar.source else {
            return "Local"
        }
        
        switch source.sourceType {
        case .local:
            return "On My Device"
        case .exchange:
            return "Exchange"
        case .calDAV:
            return source.title.contains("iCloud") ? "iCloud" : "CalDAV"
        case .mobileMe:
            return "iCloud"
        case .subscribed:
            return "Subscribed"
        case .birthdays:
            return "Birthdays"
        @unknown default:
            return source.title
        }
    }
}

// MARK: - Calendar Selection for Settings

struct CalendarSettingsRow: View {
    @ObservedObject var calendarService: CalendarService
    @Binding var selectedCalendar: EKCalendar?
    @Binding var isEnabled: Bool
    
    @State private var showingCalendarPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable Calendar Integration", isOn: $isEnabled)
                .font(.body)
            
            if isEnabled {
                Button(action: {
                    showingCalendarPicker = true
                }) {
                    HStack {
                        Text("Selected Calendar")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if let calendar = selectedCalendar {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(cgColor: calendar.cgColor))
                                    .frame(width: 12, height: 12)
                                
                                Text(calendar.title)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Choose Calendar")
                                .foregroundColor(.blue)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showingCalendarPicker) {
            NavigationView {
                CalendarPickerSheet(
                    calendarService: calendarService,
                    selectedCalendar: $selectedCalendar
                )
            }
        }
        .onAppear {
            if isEnabled && calendarService.hasCalendarAccess {
                calendarService.loadAvailableCalendars()
            }
        }
        .onChange(of: isEnabled) { _, enabled in
            if enabled && calendarService.hasCalendarAccess {
                calendarService.loadAvailableCalendars()
            }
        }
    }
}

struct CalendarPickerSheet: View {
    @ObservedObject var calendarService: CalendarService
    @Binding var selectedCalendar: EKCalendar?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(calendarService.availableCalendars, id: \.calendarIdentifier) { calendar in
                        CalendarRowView(
                            calendar: calendar,
                            isSelected: selectedCalendar?.calendarIdentifier == calendar.calendarIdentifier,
                            onTap: {
                                selectedCalendar = calendar
                                dismiss()
                            }
                        )
                    }
                } header: {
                    Text("Available Calendars")
                } footer: {
                    Text("Events will be created in the selected calendar.")
                }
            }
        }
        .navigationTitle("Choose Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            calendarService.loadAvailableCalendars()
        }
    }
}