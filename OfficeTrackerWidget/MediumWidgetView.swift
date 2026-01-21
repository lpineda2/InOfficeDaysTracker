//
//  MediumWidgetView.swift
//  OfficeTrackerWidget
//
//  Medium widget (4x2) - Core widget with circular progress and key status
//  Updated for MFP-style design
//

import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let data: WidgetData
    
    var body: some View {
        HStack(spacing: 16) {
            // Circular Progress (adapted from MainProgressView)
            CircularProgressViewWidget(
                current: data.current,
                goal: data.goal,
                percentage: data.safePercentage,
                gradient: data.progressGradient
            )
            .frame(width: 100, height: 100)
            
            // Status Information
            VStack(alignment: .leading, spacing: 8) {
                // Month name
                Text(data.monthName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(WidgetDesignTokens.textPrimary)
                
                // Current status
                HStack(spacing: 6) {
                    Image(systemName: data.isCurrentlyInOffice ? "clock.badge.fill" : "figure.walk")
                        .font(.caption)
                        .foregroundColor(statusColor)
                    
                    Text(data.isCurrentlyInOffice ? "In Office" : "Away")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                }
                
                // Weekly progress
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(WidgetDesignTokens.cyanAccent)
                        .font(.caption)
                    
                    Text("This Week: \(data.weeklyProgress)")
                        .font(.subheadline)
                        .foregroundColor(WidgetDesignTokens.textSecondary)
                }
                
                // Current visit duration (if in office)
                if data.isCurrentlyInOffice, let duration = data.currentVisitDuration {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(WidgetDesignTokens.cyanAccent)
                            .font(.caption)
                        
                        Text(formatDuration(duration))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(WidgetDesignTokens.cyanAccent)
                    }
                }
                
                Spacer()
            }
            
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            // Widget background with subtle status-aware accent
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .stroke(statusColor.opacity(0.3), lineWidth: 2)
        }
    }
    
    private var statusColor: Color {
        switch data.statusColor {
        case .green:
            return WidgetDesignTokens.statusInOffice
        case .orange:
            return WidgetDesignTokens.statusAway
        case .blue:
            return WidgetDesignTokens.cyanAccent
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours == 0 && minutes == 0 && duration > 0 {
            return "< 1m"
        } else if hours == 0 {
            return "\(minutes)m"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
}

#Preview(as: .systemMedium) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
}