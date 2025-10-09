//
//  AccessoryInlineView.swift
//  OfficeTrackerWidget
//
//  Inline text widget for iPhone lock screen showing office progress in one line
//

import SwiftUI
import WidgetKit

struct AccessoryInlineView: View {
    let data: WidgetData
    
    var body: some View {
        HStack(spacing: 4) {
            // Office emoji/icon
            Text("🏢")
                .font(.caption)
            
            // Progress text
            Text(progressText)
                .font(.system(.caption, design: .rounded, weight: .medium))
            
            // Status indicator
            Text(statusIndicator)
                .font(.caption2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var progressText: String {
        let percentage = data.goal > 0 ? Int((Double(data.current) / Double(data.goal)) * 100) : 0
        return "\(data.current)/\(data.goal) days (\(percentage)%)"
    }
    
    private var statusIndicator: String {
        if data.isCurrentlyInOffice {
            return "🏢"  // Building emoji to match the concept
        } else if data.current >= data.goal {
            return "✅"  // Checkmark for goal achieved
        } else {
            return "🚶"  // Walking person emoji to match figure.walk concept
        }
    }
}

#Preview(as: .accessoryInline) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
}