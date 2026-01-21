//
//  TrendChartCard.swift
//  InOfficeDaysTracker
//
//  Created for MFP-style redesign
//  Attendance trend chart using Swift Charts with 30/60/90 day picker
//

import SwiftUI
import Charts

/// Data point for the trend chart
struct TrendDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
}

/// A card displaying attendance trends over time using Swift Charts
/// Features a segmented picker for 30/60/90 day ranges
struct TrendChartCard: View {
    let data: [TrendDataPoint]
    let hasEnoughData: Bool
    
    @State private var selectedRange: TrendRange = .threeMonths

    enum TrendRange: Int, CaseIterable {
        case threeMonths = 3
        case sixMonths = 6
        case nineMonths = 9

        var label: String {
            switch self {
            case .threeMonths: return "3M"
            case .sixMonths: return "6M"
            case .nineMonths: return "9M"
            }
        }
    }
    
    private var filteredData: [TrendDataPoint] {
        // Use month-aligned cutoff and exclude the current month.
        let calendar = Calendar.current
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else {
            return []
        }

        guard let cutoffDate = calendar.date(byAdding: .month, value: -selectedRange.rawValue, to: currentMonthStart) else {
            return []
        }

        // Include dates in full months between cutoffDate (inclusive) and currentMonthStart (exclusive)
        return data.filter { $0.date >= cutoffDate && $0.date < currentMonthStart }
    }
    
    private var aggregatedData: [TrendDataPoint] {
        // Aggregate by month and ensure months with zero values are present
        let calendar = Calendar.current

        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else {
            return []
        }

        guard let cutoffDate = calendar.date(byAdding: .month, value: -selectedRange.rawValue, to: currentMonthStart) else {
            return []
        }

        var monthlyData: [Date: Int] = [:]
        for point in filteredData {
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: point.date)) ?? point.date
            monthlyData[monthStart, default: 0] += point.value
        }

        // Build ordered list of month starts between cutoffDate and currentMonthStart (exclusive)
        var months: [Date] = []
        var iter = cutoffDate
        while iter < currentMonthStart {
            months.append(iter)
            guard let next = calendar.date(byAdding: .month, value: 1, to: iter) else { break }
            iter = next
        }

        return months.map { monthStart in
            TrendDataPoint(date: monthStart, value: monthlyData[monthStart] ?? 0)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with title and range picker
            HStack {
                Text("Attendance Trend")
                    .font(Typography.cardTitle)
                    .foregroundColor(DesignTokens.textPrimary)
                
                Spacer()
                
                Picker("Range", selection: $selectedRange) {
                    ForEach(TrendRange.allCases, id: \.self) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            
            // Chart area
            ZStack {
                if aggregatedData.isEmpty {
                    // Empty state
                    emptyStateView
                } else {
                    // Chart with optional "not enough data" overlay
                    chartView
                        .overlay {
                            if !hasEnoughData {
                                notEnoughDataOverlay
                            }
                        }
                }
            }
            .frame(height: 180)
        }
        .cardStyle()
    }
    
    // MARK: - Chart View
    
    private var chartView: some View {
        Chart(aggregatedData) { point in
            // Area fill
            AreaMark(
                x: .value("Month", point.date, unit: .month),
                y: .value("Days", point.value)
            )
            .foregroundStyle(DesignTokens.chartFill)
            .interpolationMethod(.catmullRom)
            
            // Line
            LineMark(
                x: .value("Month", point.date, unit: .month),
                y: .value("Days", point.value)
            )
            .foregroundStyle(DesignTokens.chartLine)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            // Points
            PointMark(
                x: .value("Month", point.date, unit: .month),
                y: .value("Days", point.value)
            )
            .foregroundStyle(DesignTokens.chartLine)
            .symbolSize(30)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: xAxisStrideCount)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DesignTokens.chartGrid.opacity(0.5))
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DesignTokens.chartGrid.opacity(0.5))
                AxisValueLabel()
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
        .chartYScale(domain: 0...maxYValue)
    }
    
    private var xAxisStrideCount: Int {
        switch selectedRange {
        case .threeMonths: return 1
        case .sixMonths: return 2
        case .nineMonths: return 3
        }
    }
    
    private var maxYValue: Int {
        let maxValue = aggregatedData.map(\.value).max() ?? 5
        return max(maxValue + 1, 5) // At least 5 for nice scale
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.textTertiary)
            
            Text("No data yet")
                .font(Typography.bodySecondary)
                .foregroundColor(DesignTokens.textSecondary)
            
            Text("Your attendance trend will appear here")
                .font(Typography.caption)
                .foregroundColor(DesignTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Not Enough Data Overlay
    
    private var notEnoughDataOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text("Limited data available")
                    .font(Typography.caption)
            }
            .foregroundColor(DesignTokens.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(DesignTokens.surfaceElevated)
            )
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Preview

#Preview("Trend Chart Card") {
    let calendar = Calendar.current
    let today = Date()
    
    // Generate sample data
    let sampleData: [TrendDataPoint] = (0..<90).compactMap { dayOffset in
        guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return nil }
        // Random attendance (0 or 1 per day)
        let weekday = calendar.component(.weekday, from: date)
        let isWeekday = weekday >= 2 && weekday <= 6
        let attended = isWeekday && Bool.random() && Bool.random() // ~25% chance on weekdays
        return TrendDataPoint(date: date, value: attended ? 1 : 0)
    }
    
    ScrollView {
        VStack(spacing: 20) {
            TrendChartCard(data: sampleData, hasEnoughData: true)
            TrendChartCard(data: Array(sampleData.prefix(5)), hasEnoughData: false)
            TrendChartCard(data: [], hasEnoughData: false)
        }
        .padding()
    }
    .background(DesignTokens.appBackground)
}
