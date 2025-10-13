//
//  AccessoryRectangularView.swift
//  OfficeTrackerWidget
//
//  Rectangular widget for iPhone lock screen: Icon left, text center, progress ring right
//

import SwiftUI
import WidgetKit

struct AccessoryRectangularView: View {
    let data: WidgetData
    
    var body: some View {
        HStack(spacing: 8) {
            // Left: Building icon
            Image(systemName: "building.2.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 24, height: 24)
            
            // Center: Progress text (centered between icon and progress ring)
            Spacer()
            
            VStack(alignment: .center, spacing: 0) {
                Text("\(data.current) of \(data.goal)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                Text("days")
                    .font(.caption.weight(.regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Right: Circular progress indicator
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                    .frame(width: 28, height: 28)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        statusColor,
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round
                        )
                    )
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
                
                // Center status indicator matching circular widget
                Image(systemName: statusIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(statusColor)
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var progress: Double {
        guard data.goal > 0 else { return 0.0 }
        let calculatedProgress = Double(data.current) / Double(data.goal)
        return min(max(calculatedProgress, 0.0), 1.0)
    }
    
    private var statusIcon: String {
        data.isCurrentlyInOffice ? "building.2.fill" : "figure.walk"
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
}

#Preview(as: .accessoryRectangular) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
}