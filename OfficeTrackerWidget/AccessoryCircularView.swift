//
//  AccessoryCircularView.swift
//  OfficeTrackerWidget
//
//  Circular widget for iPhone lock screen showing office progress
//

import SwiftUI
import WidgetKit

struct AccessoryCircularView: View {
    let data: WidgetData
    
    var body: some View {
        Gauge(value: progressValue, in: 0...1) {
            // Gauge label (not shown in accessory circular)
            AnyView(Text("Office Days"))
        } currentValueLabel: {
            // Large center number (current days) - more prominent
            AnyView(
                Text("\(data.current)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
            )
        } minimumValueLabel: {
            // Visual status indicator on bottom left (smaller)
            AnyView(
                Image(systemName: statusIndicator)
                    .font(.system(size: 8, design: .rounded))
                    .foregroundColor(.primary)
            )
        } maximumValueLabel: {
            // Goal number on bottom right - smaller and subtle
            AnyView(
                Text("\(data.goal)")
                    .font(.system(.caption, design: .rounded, weight: .regular))
                    .foregroundColor(.secondary)
            )
        }
        .gaugeStyle(.accessoryCircular)
        .animation(.easeInOut(duration: 0.3), value: progressValue)
    }
    
    private var progressValue: Double {
        guard data.goal > 0 else { return 0.0 }
        let progress = Double(data.current) / Double(data.goal)
        return min(progress, 1.0)
    }
    
    private var statusIndicator: String {
        if data.isCurrentlyInOffice {
            return "building.2.fill.badge.clock"  // Office building with clock badge for "in office"
        } else {
            return "figure.walk"      // Walking figure for "away"
        }
    }
}

#Preview(as: .accessoryCircular) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
}