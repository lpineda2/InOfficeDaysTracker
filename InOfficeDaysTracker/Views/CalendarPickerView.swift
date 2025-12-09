//
//  CalendarPickerView.swift
//  InOfficeDaysTracker
//
//  Calendar picker grouped by account source
//

import SwiftUI
import EventKit

struct CalendarPickerView: View {
    @ObservedObject var calendarService: CalendarService
    @Binding var selectedCalendar: EKCalendar?
    @Environment(\.dismiss) private var dismiss
    
    /// Group calendars by their source title
    private var calendarsBySource: [(source: String, calendars: [EKCalendar])] {
        let grouped = Dictionary(grouping: calendarService.availableCalendars) { $0.source.title }
        return grouped.sorted { $0.key < $1.key }.map { (source: $0.key, calendars: $0.value) }
    }
    
    var body: some View {
        List {
            ForEach(calendarsBySource, id: \.source) { group in
                Section(header: Text(group.source)) {
                    ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                        CalendarPickerRow(
                            calendar: calendar,
                            isSelected: selectedCalendar?.calendarIdentifier == calendar.calendarIdentifier
                        ) {
                            selectedCalendar = calendar
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A row in the calendar picker showing color, name, and selection state
private struct CalendarPickerRow: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 14, height: 14)
                
                Text(calendar.title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
