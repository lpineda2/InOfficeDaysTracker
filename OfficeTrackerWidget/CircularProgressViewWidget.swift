//
//  CircularProgressViewWidget.swift
//  OfficeTrackerWidget
//
//  Widget-optimized version of the circular progress from MainProgressView
//

import SwiftUI

struct CircularProgressViewWidget: View {
    let current: Int
    let goal: Int
    let percentage: Double
    let gradient: WidgetData.ProgressGradient
    
    private var safePercentage: Double {
        guard !percentage.isNaN && !percentage.isInfinite && percentage >= 0 else { return 0.0 }
        return min(percentage, 1.0)
    }
    
    private var safePercentageDisplay: Int {
        let displayValue = Int(safePercentage * 100)
        return max(0, min(100, displayValue))
    }
    
    private var progressGradient: LinearGradient {
        switch gradient {
        case .standard:
            return LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .celebration:
            return LinearGradient(
                colors: [.orange, .green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 8)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: safePercentage)
                .stroke(
                    progressGradient,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1), value: safePercentage)
            
            // Center content
            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("of \(goal)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if current >= goal {
                    Text("Complete!")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                } else {
                    Text("\(safePercentageDisplay)%")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
            }
        }
    }
}

// Preview removed - widget extensions can only host widget previews
// To test this view, use it within a widget configuration or move to main app target