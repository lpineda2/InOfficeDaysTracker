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
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.primary.opacity(0.2), lineWidth: 4)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(
                    Color.primary,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progressValue)
            
            // Center content
            VStack(spacing: 1) {
                Text("\(data.current)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("/\(data.goal)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var progressValue: Double {
        guard data.goal > 0 else { return 0.0 }
        let progress = Double(data.current) / Double(data.goal)
        return min(progress, 1.0)
    }
}

#Preview(as: .accessoryCircular) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
}