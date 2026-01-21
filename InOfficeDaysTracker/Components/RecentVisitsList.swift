//
//  RecentVisitsList.swift
//  InOfficeDaysTracker
//
//  Created for MFP-style redesign
//  Compact recent visits section styled as a card
//

import SwiftUI

/// A card displaying recent office visits in a compact list format
struct RecentVisitsList: View {
    let visits: [VisitDisplayItem]
    let onSeeAllTapped: () -> Void
    
    /// Maximum number of visits to display
    private let maxDisplayCount = 5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Recent Visits")
                    .font(Typography.cardTitle)
                    .foregroundColor(DesignTokens.textPrimary)
                
                Spacer()
                
                Button(action: onSeeAllTapped) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(Typography.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(DesignTokens.cyanAccent)
                }
            }
            
            if visits.isEmpty {
                // Empty state
                emptyStateView
            } else {
                // Visit list
                VStack(spacing: 0) {
                    ForEach(Array(visits.prefix(maxDisplayCount).enumerated()), id: \.element.id) { index, visit in
                        VisitRowCompact(visit: visit)
                        
                        if index < min(visits.count, maxDisplayCount) - 1 {
                            Divider()
                                .background(DesignTokens.ringBackground)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
    
    private var emptyStateView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "building.2")
                    .font(.title2)
                    .foregroundColor(DesignTokens.textTertiary)
                
                Text("No visits yet")
                    .font(Typography.bodySecondary)
                    .foregroundColor(DesignTokens.textSecondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
}

/// Display model for a visit row
struct VisitDisplayItem: Identifiable {
    let id: UUID
    let date: Date
    let dayOfWeek: String
    let duration: String
    let isActiveSession: Bool
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }
    
    var displayDate: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            return formattedDate
        }
    }
}

/// Compact row view for a single visit
struct VisitRowCompact: View {
    let visit: VisitDisplayItem
    
    var body: some View {
        HStack {
            // Date and day
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.displayDate)
                    .font(Typography.bodySecondary)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.textPrimary)
                
                Text(visit.dayOfWeek)
                    .font(Typography.caption)
                    .foregroundColor(DesignTokens.textSecondary)
            }
            
            Spacer()
            
            // Duration or active indicator
            if visit.isActiveSession {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DesignTokens.statusInOffice)
                        .frame(width: 8, height: 8)
                    Text("In Office")
                        .font(Typography.caption)
                        .foregroundColor(DesignTokens.statusInOffice)
                }
            } else {
                Text(visit.duration)
                    .font(Typography.bodySecondary)
                    .foregroundColor(DesignTokens.textSecondary)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#Preview("Recent Visits List") {
    let calendar = Calendar.current
    let today = Date()
    
    let sampleVisits: [VisitDisplayItem] = [
        VisitDisplayItem(
            id: UUID(),
            date: today,
            dayOfWeek: "Tuesday",
            duration: "In Progress",
            isActiveSession: true
        ),
        VisitDisplayItem(
            id: UUID(),
            date: calendar.date(byAdding: .day, value: -1, to: today)!,
            dayOfWeek: "Monday",
            duration: "8h 30m",
            isActiveSession: false
        ),
        VisitDisplayItem(
            id: UUID(),
            date: calendar.date(byAdding: .day, value: -4, to: today)!,
            dayOfWeek: "Friday",
            duration: "6h 15m",
            isActiveSession: false
        ),
        VisitDisplayItem(
            id: UUID(),
            date: calendar.date(byAdding: .day, value: -5, to: today)!,
            dayOfWeek: "Thursday",
            duration: "9h 0m",
            isActiveSession: false
        ),
    ]
    
    ScrollView {
        VStack(spacing: 20) {
            RecentVisitsList(visits: sampleVisits) {
                print("See all tapped")
            }
            
            RecentVisitsList(visits: []) {
                print("See all tapped")
            }
        }
        .padding()
    }
    .background(DesignTokens.appBackground)
}
