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

    private var weekly: WeeklyComplianceResult? {
        data.trackingCadence.includesWeekly ? data.weeklyResult : nil
    }

    private var displayCurrent: Int { weekly?.officeDaysCompleted ?? data.current }
    private var displayGoal: Int { weekly?.requiredDays ?? data.goal }

    var body: some View {
        Gauge(value: progressValue, in: 0...1) {
            // Gauge label (not shown in accessory circular)
            AnyView(Text(weekly != nil ? "This Week" : "Office Days"))
        } currentValueLabel: {
            // Large center number (current days) - more prominent
            AnyView(
                Text("\(displayCurrent)")
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
                Text("\(displayGoal)")
                    .font(.system(.caption, design: .rounded, weight: .regular))
                    .foregroundColor(.secondary)
            )
        }
        .gaugeStyle(.accessoryCircular)
        .animation(.easeInOut(duration: 0.3), value: progressValue)
    }

    private var progressValue: Double {
        guard displayGoal > 0 else { return 0.0 }
        let progress = Double(displayCurrent) / Double(displayGoal)
        return min(progress, 1.0)
    }

    private var statusIndicator: String {
        if let weekly {
            return WeeklyStatusPresentation.icon(for: weekly.status)
        }
        if data.isCurrentlyInOffice {
            return "clock.badge.fill"  // Clock with badge for "in office" (time-based)
        } else {
            return "figure.walk"       // Walking figure for "away"
        }
    }
}

#Preview(as: .accessoryCircular) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleWeekly)
}