//
//  LargeWidgetView.swift
//  OfficeTrackerWidget
//
//  Large widget (4x4) - Comprehensive display with detailed statistics
//  Updated for MFP-style design
//

import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let data: WidgetData
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with month and current status
            headerView
            
            // Main progress section
            mainProgressSection
            
            // Statistics grid
            statisticsGrid
            
            Spacer()
        }
        .padding(20)
        .containerBackground(for: .widget) {
            // Rich gradient background based on status
            LinearGradient(
                gradient: Gradient(colors: [
                    statusColor.opacity(0.15),
                    statusColor.opacity(0.05),
                    Color.clear
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(.background)
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(data.monthName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(WidgetDesignTokens.textPrimary)
                
                HStack(spacing: 6) {
                    Image(systemName: data.isCurrentlyInOffice ? "clock.badge.fill" : "figure.walk")
                        .font(.caption)
                        .foregroundColor(statusColor)
                    
                    Text(data.isCurrentlyInOffice ? "Currently in office" : "Currently away")
                        .font(.caption)
                        .foregroundColor(WidgetDesignTokens.textSecondary)
                }
            }
            
            Spacer()
            
            // Goal badge
            VStack {
                Text("\(data.goal)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(WidgetDesignTokens.textPrimary)
                Text("goal")
                    .font(.caption2)
                    .foregroundColor(WidgetDesignTokens.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(WidgetDesignTokens.ringBackground.opacity(0.5))
            .cornerRadius(8)
        }
    }
    
    private var mainProgressSection: some View {
        HStack(spacing: 20) {
            // Circular progress
            CircularProgressViewWidget(
                current: data.current,
                goal: data.goal,
                percentage: data.safePercentage,
                gradient: data.progressGradient
            )
            .frame(width: 100, height: 100)
            
            // Additional context if currently in office (visit duration only)
            VStack(alignment: .leading, spacing: 8) {
                if data.isCurrentlyInOffice, let duration = data.currentVisitDuration {
                    let hours = Int(duration / 3600)
                    let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
                    Text("Visit duration: \(hours)h \(minutes)m")
                        .font(.caption)
                        .foregroundColor(WidgetDesignTokens.textSecondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var statisticsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            StatisticCard(
                title: "Days Left",
                value: "\(data.daysLeftInMonth)",
                subtitle: "in month",
                color: WidgetDesignTokens.cyanAccent
            )
            .frame(height: 60)
            
            StatisticCard(
                title: "Pace",
                value: data.paceNeeded,
                subtitle: "needed",
                color: data.paceNeeded.contains("Complete") ? WidgetDesignTokens.successGreen : WidgetDesignTokens.orangeAccent
            )
            .frame(height: 60)
        }
    }
    
    private var statusColor: Color {
        switch data.statusColor {
        case .green:
            return WidgetDesignTokens.statusInOffice
        case .orange:
            return WidgetDesignTokens.statusAway
        case .blue:
            return WidgetDesignTokens.cyanAccent
        }
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(WidgetDesignTokens.textSecondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(WidgetDesignTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(WidgetDesignTokens.ringBackground.opacity(0.3))
        .cornerRadius(10)
    }
}

#Preview(as: .systemLarge) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
}