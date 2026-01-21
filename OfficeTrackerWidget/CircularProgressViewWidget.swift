//
//  CircularProgressViewWidget.swift
//  OfficeTrackerWidget
//
//  Widget-optimized version of the circular progress from MainProgressView
//  Updated for MFP-style design with new color tokens
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
            return WidgetDesignTokens.accentCyan
        case .celebration:
            return WidgetDesignTokens.accentSuccess
        }
    }
    
    private var accentColor: Color {
        switch gradient {
        case .standard:
            return WidgetDesignTokens.cyanAccent
        case .celebration:
            return WidgetDesignTokens.successGreen
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(WidgetDesignTokens.ringBackground, lineWidth: WidgetDesignTokens.ringStrokeWidth)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: safePercentage)
                .stroke(
                    progressGradient,
                    style: StrokeStyle(lineWidth: WidgetDesignTokens.ringStrokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1), value: safePercentage)
            
            // Center content
            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetDesignTokens.textPrimary)
                
                Text("of \(goal)")
                    .font(.caption)
                    .foregroundColor(WidgetDesignTokens.textSecondary)
                
                if current >= goal {
                    Text("Complete!")
                        .font(.caption2)
                        .foregroundColor(WidgetDesignTokens.successGreen)
                        .fontWeight(.medium)
                } else {
                    Text("\(safePercentageDisplay)%")
                        .font(.caption2)
                        .foregroundColor(accentColor)
                        .fontWeight(.medium)
                }
            }
        }
    }
}

// Preview removed - widget extensions can only host widget previews
// To test this view, use it within a widget configuration or move to main app target