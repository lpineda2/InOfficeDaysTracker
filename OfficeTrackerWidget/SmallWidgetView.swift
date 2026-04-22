//
//  SmallWidgetView.swift
//  OfficeTrackerWidget
//
//  Small widget (2x2) - Minimal display with just circular progress
//  Updated for MFP-style design
//

import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let data: WidgetData
    
    var body: some View {
        VStack(spacing: 8) {
            // Month name (compact)
            Text(monthAbbreviation)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(WidgetDesignTokens.textSecondary)
            
            // Circular Progress
            CircularProgressViewWidget(
                current: data.current,
                goal: data.goal,
                percentage: data.safePercentage,
                gradient: data.progressGradient
            )
            .frame(width: 80, height: 80)
            
            // Status indicator dot
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                
                Text(data.isCurrentlyInOffice ? "In Office" : "Away")
                    .font(.caption2)
                    .foregroundColor(WidgetDesignTokens.textSecondary)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            // Minimal background with status-aware border
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .stroke(statusColor.opacity(0.4), lineWidth: 1.5)
        }
    }
    
    private var monthAbbreviation: String {
        let components = data.monthName.split(separator: " ")
        if let month = components.first {
            let monthStr = String(month)
            return String(monthStr.prefix(3)) // Oct, Nov, etc.
        }
        return "Month"
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
}

#Preview(as: .systemSmall) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
}