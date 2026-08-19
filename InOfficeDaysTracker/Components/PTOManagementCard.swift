//
//  PTOManagementCard.swift
//  InOfficeDaysTracker
//
//  Standalone PTO/sick day management for the dashboard.
//

import SwiftUI

/// Lists and edits PTO/sick days for the current month.
///
/// Previously this lived inside `GoalProgressSection`, which mixed two
/// unrelated concerns: monthly-goal statistics and time-off entry. Hiding that
/// section for weekly-only tracking also removed the only way to record PTO —
/// which weekly users need most, since time off can reduce their weekly goal.
/// Extracted so it stands on its own in every cadence.
struct PTOManagementCard: View {
    @ObservedObject var appData: AppData

    @State private var showingPTOPicker = false
    @State private var editingPTODate: Date?
    @State private var isExpanded = false
    @State private var showingDeleteConfirmation = false
    @State private var dateToDelete: Date?

    private let currentMonth = Date()

    private var ptoDays: [Date] {
        appData.getPTODays(for: currentMonth).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isExpanded {
                expandedList
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .cardStyle()
        .sheet(isPresented: $showingPTOPicker) {
            PTOPickerSheet(appData: appData, month: currentMonth, editingDate: editingPTODate)
        }
        .alert("Remove PTO Day?", isPresented: $showingDeleteConfirmation, presenting: dateToDelete) { date in
            Button("Cancel", role: .cancel) {
                dateToDelete = nil
            }
            Button("Remove", role: .destructive) {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                appData.removePTODay(date)
                dateToDelete = nil
            }
        } message: { date in
            Text("Remove PTO/Sick day for \(formatDeleteConfirmation(date))?")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                if ptoDays.isEmpty {
                    editingPTODate = nil
                    showingPTOPicker = true
                } else {
                    isExpanded.toggle()
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.walk")
                    .iconBackground(color: DesignTokens.successGreen)

                VStack(alignment: .leading, spacing: 2) {
                    Text("PTO & Sick Days")
                        .font(Typography.cardTitle)
                        .foregroundColor(DesignTokens.textPrimary)

                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                }

                Spacer()

                Image(systemName: ptoDays.isEmpty
                      ? "plus.circle.fill"
                      : (isExpanded ? "chevron.up" : "chevron.down"))
                    .foregroundColor(DesignTokens.cyanAccent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("PTO and sick days. \(subtitle)")
        .accessibilityHint(ptoDays.isEmpty ? "Adds a day" : "Shows the list")
    }

    private var expandedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ptoDays, id: \.self) { date in
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(DesignTokens.successGreen)
                        .font(.subheadline)

                    Text(formatPTODate(date))
                        .foregroundColor(DesignTokens.textPrimary)

                    Spacer()

                    Button {
                        dateToDelete = date
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignTokens.textSecondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(formatPTODate(date))")
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    editingPTODate = date
                    showingPTOPicker = true
                }
                .accessibilityLabel("\(formatPTODate(date)), double tap to edit")
            }

            Button {
                editingPTODate = nil
                showingPTOPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(DesignTokens.cyanAccent)
                    Text("Add PTO Day")
                        .foregroundColor(DesignTokens.cyanAccent)
                    Spacer()
                }
                .padding(.top, 8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Derived values

    private var subtitle: String {
        let count = ptoDays.count
        guard count > 0 else { return "None recorded this month" }
        return "\(count) day\(count == 1 ? "" : "s") this month"
    }

    private func formatPTODate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func formatDeleteConfirmation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("PTO Management") {
    VStack {
        PTOManagementCard(appData: AppData())
        Spacer()
    }
    .padding()
    .background(DesignTokens.appBackground)
}
