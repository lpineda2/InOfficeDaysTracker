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
            Image(systemName: "building.2.fill.badge.clock")
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
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                Text("days")
                    .font(.system(size: dynamicDaysTextSize, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .minimumScaleFactor(0.9)
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
        // iPhone 16 Pro: 393px, iPhone 16 Pro Max: 430px
        if screenWidth >= 430 {
            return 14  // Pro Max gets larger text
        } else if screenWidth >= 400 {
            return 13  // Regular Pro size
        } else {
            return 12  // Compact displays
        }
    }
    
    private var dynamicDaysTextSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        // Scale the "days" text proportionally
        if screenWidth >= 430 {
            return 10  // Pro Max
        } else if screenWidth >= 400 {
            return 9   // Regular Pro
        } else {
            return 8   // Compact displays
        }
    }
    
    private var statusIcon: String {
        data.isCurrentlyInOffice ? "building.2.fill.badge.clock" : "figure.walk"
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