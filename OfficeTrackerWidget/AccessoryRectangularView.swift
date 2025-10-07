//
//  AccessoryRectangularView.swift
//  OfficeTrackerWidget
//
//  Rectangular widget for iPhone lock screen showing office progress and status
//

import SwiftUI
import WidgetKit

struct AccessoryRectangularView: View {
    let data: WidgetData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Progress line
            HStack(spacing: 4) {
                Image(systemName: "building.2")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text("Office: \(data.current)/\(data.goal)")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(progressPercentage)%")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            // Status line
            HStack(spacing: 4) {
                statusIcon
                    .font(.caption2)
                    .foregroundColor(statusColor)
                
                Text(statusText)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
    
    private var progressPercentage: Int {
        guard data.goal > 0 else { return 0 }
        return Int((Double(data.current) / Double(data.goal)) * 100)
    }
    
    private var statusIcon: Image {
        if data.isCurrentlyInOffice {
            return Image(systemName: "location.fill")
        } else if data.current >= data.goal {
            return Image(systemName: "checkmark.circle.fill")
        } else {
            return Image(systemName: "clock")
        }
    }
    
    private var statusColor: Color {
        if data.isCurrentlyInOffice {
            return .green
        } else if data.current >= data.goal {
            return .blue
        } else {
            return .orange
        }
    }
    
    private var statusText: String {
        if data.isCurrentlyInOffice {
            return "Currently in office"
        } else if data.current >= data.goal {
            return "Goal achieved!"
        } else {
            let remaining = data.goal - data.current
            return "\(remaining) day\(remaining == 1 ? "" : "s") to go"
        }
    }
}

#Preview(as: .accessoryRectangular) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
}