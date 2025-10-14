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
                .font(.system(size: 23, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 27, height: 27)
            
            // Center: Progress text (centered between icon and progress ring)
            Spacer()
            
            VStack(alignment: .center, spacing: 1) {
                Text("\(data.current) of \(data.goal)")
                    .font(.system(size: dynamicFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .allowsTightening(true)
                Text("days")
                    .font(.system(size: 8, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
            }
            
            Spacer()
            
            // Right: Circular progress indicator
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                    .frame(width: 31, height: 31)
                
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
                    .frame(width: 31, height: 31)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
                
                // Center status indicator matching circular widget
                Image(systemName: statusIcon)
                    .font(.system(size: 13, weight: .semibold))
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
    
    private var dynamicFontSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return screenWidth < 400 ? 11 : 12  // More conservative sizing for better fit
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