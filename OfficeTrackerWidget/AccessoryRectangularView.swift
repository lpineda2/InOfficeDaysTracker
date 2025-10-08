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
        VStack(alignment: .leading, spacing: 1) {
            // Top line: Office label and percentage
            HStack {
                Image(systemName: "building.2")
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.primary)
                Text("Office")
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(progressPercentage)%")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.accentColor)
            }
            
            // Bottom line: Progress count and status
            HStack {
                Text("\(data.current) of \(data.goal) days")
                    .font(.caption.weight(.regular))
                    .foregroundColor(.secondary)
                Spacer()
                statusIcon
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(statusColor)
            }
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
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