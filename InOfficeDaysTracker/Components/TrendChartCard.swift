//
//  TrendChartCard.swift
//  InOfficeDaysTracker
//
//  Created for MFP-style redesign
//  Attendance trend chart using Swift Charts with 3/6/9 month picker
//

import SwiftUI
import Charts

/// Data point for the trend chart
struct TrendDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
}

/// A card displaying attendance trends over time using Swift Charts.
///
/// Two modes, driven by `isWeekly`:
/// - Monthly (default): 3M/6M/9M ranges, bucketed by calendar month, excluding
///   the current (incomplete) month.
/// - Weekly: 8W/12W/16W ranges, bucketed by `weekOfYear`, **including** the
///   current partial week, with a reference line at the weekly minimum.
struct TrendChartCard: View {
    let data: [TrendDataPoint]
    let hasEnoughData: Bool
    /// When true, bucket by week instead of month (weekly tracking cadence).
    var isWeekly: Bool = false
    /// Weekly minimum office days, drawn as a reference line in weekly mode.
    var weeklyMinimumDays: Int? = nil

    @State private var selectedRange: TrendRange = .threeMonths
    @State private var selectedWeeklyRange: WeeklyTrendRange = .eightWeeks

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

    enum WeeklyTrendRange: Int, CaseIterable {
        case eightWeeks = 8
        case twelveWeeks = 12
        case sixteenWeeks = 16

        var label: String {
            switch self {
            case .eightWeeks: return "8W"
            case .twelveWeeks: return "12W"
            case .sixteenWeeks: return "16W"
            }
        }
    }

    private var filteredData: [TrendDataPoint] {
        // Use month-aligned cutoff and exclude the current month.
        guard let info = monthRange() else { return [] }
        let currentMonthStart = info.currentMonthStart
        let cutoffDate = info.cutoffDate

        // Include dates in full months between cutoffDate (inclusive) and currentMonthStart (exclusive)
        return data.filter { $0.date >= cutoffDate && $0.date < currentMonthStart }
    }
    
    private var aggregatedData: [TrendDataPoint] {
        if isWeekly {
            return Self.aggregatedByWeek(from: data, weeks: selectedWeeklyRange.rawValue)
        }
        return aggregatedMonthlyData
    }

    private var aggregatedMonthlyData: [TrendDataPoint] {
        // Aggregate by month and ensure months with zero values are present
        guard let info = monthRange() else { return [] }
        let calendar = info.calendar
        let currentMonthStart = info.currentMonthStart
        let cutoffDate = info.cutoffDate

        var monthlyData: [Date: Int] = [:]
        for point in filteredData {
            let monthStart = monthStart(for: point.date, calendar: calendar)
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
            // Position the plotted point in the middle of the month so it visually aligns with the month label
            let midDate = midMonthDate(for: monthStart, calendar: calendar)
            return TrendDataPoint(date: midDate, value: monthlyData[monthStart] ?? 0)
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
                
                if isWeekly {
                    Picker("Range", selection: $selectedWeeklyRange) {
                        ForEach(WeeklyTrendRange.allCases, id: \.self) { range in
                            Text(range.label).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                } else {
                    Picker("Range", selection: $selectedRange) {
                        ForEach(TrendRange.allCases, id: \.self) { range in
                            Text(range.label).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chartAccessibilityLabel)
        }
        .cardStyle()
    }
    
    // MARK: - Chart View
    
    private var chartView: some View {
        Chart {
            ForEach(aggregatedData) { point in
                // Area fill
                AreaMark(
                    x: .value(xAxisLabel, point.date, unit: xAxisUnit),
                    y: .value("Days", point.value)
                )
                .foregroundStyle(DesignTokens.chartFill)
                .interpolationMethod(.catmullRom)

                // Line
                LineMark(
                    x: .value(xAxisLabel, point.date, unit: xAxisUnit),
                    y: .value("Days", point.value)
                )
                .foregroundStyle(DesignTokens.chartLine)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                // Points
                PointMark(
                    x: .value(xAxisLabel, point.date, unit: xAxisUnit),
                    y: .value("Days", point.value)
                )
                .foregroundStyle(DesignTokens.chartLine)
                .symbolSize(30)
            }

            // Weekly minimum reference line. Dashed + annotated so the target is
            // conveyed by shape and text, not by color alone.
            if isWeekly, let minimum = weeklyMinimumDays, minimum > 0 {
                RuleMark(y: .value("Weekly minimum", minimum))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal: \(minimum)")
                            .font(Typography.caption)
                            .foregroundColor(DesignTokens.textSecondary)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: aggregatedData.map { $0.date }) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DesignTokens.chartGrid.opacity(0.5))
                AxisTick()
                if isWeekly {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(DesignTokens.textSecondary)
                } else {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(DesignTokens.textSecondary)
                }
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
    
    // MARK: - Axis Configuration

    private var xAxisLabel: String { isWeekly ? "Week" : "Month" }

    private var xAxisUnit: Calendar.Component { isWeekly ? .weekOfYear : .month }

    /// Spoken summary of the chart contents, since the plotted marks themselves
    /// aren't meaningfully navigable by VoiceOver.
    private var chartAccessibilityLabel: String {
        guard !aggregatedData.isEmpty else {
            return "Attendance trend. No data yet."
        }

        let period = isWeekly ? "week" : "month"
        let rangeLabel = isWeekly ? selectedWeeklyRange.label : selectedRange.label
        let values = aggregatedData.map { "\($0.value)" }.joined(separator: ", ")

        var label = "Attendance trend, last \(rangeLabel). Office days per \(period): \(values)."
        if isWeekly, let minimum = weeklyMinimumDays, minimum > 0 {
            label += " Weekly goal: \(minimum) days."
        }
        if !hasEnoughData {
            label += " Limited data available."
        }
        return label
    }

    // MARK: - Date Helpers

    private func monthRange() -> (calendar: Calendar, currentMonthStart: Date, cutoffDate: Date)? {
        let calendar = Calendar.current
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else {
            return nil
        }
        guard let cutoffDate = calendar.date(byAdding: .month, value: -selectedRange.rawValue, to: currentMonthStart) else {
            return nil
        }
        return (calendar, currentMonthStart, cutoffDate)
    }

    private func monthStart(for date: Date, calendar: Calendar) -> Date {
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func midMonthDate(for monthStart: Date, calendar: Calendar) -> Date {
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let midOffset = daysInMonth / 2
        return calendar.date(byAdding: .day, value: midOffset, to: monthStart) ?? monthStart
    }

    // Exposed helper for testing: aggregate arbitrary data into month buckets (previous N full months)
    static func aggregated(from data: [TrendDataPoint], months: Int, now: Date = Date(), calendar: Calendar = Calendar.current) -> [TrendDataPoint] {
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return [] }
        guard let cutoffDate = calendar.date(byAdding: .month, value: -months, to: currentMonthStart) else { return [] }

        var monthlyData: [Date: Int] = [:]
        for point in data {
            if point.date >= cutoffDate && point.date < currentMonthStart {
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: point.date)) ?? point.date
                monthlyData[monthStart, default: 0] += point.value
            }
        }

        var monthsArr: [Date] = []
        var iter = cutoffDate
        while iter < currentMonthStart {
            monthsArr.append(iter)
            guard let next = calendar.date(byAdding: .month, value: 1, to: iter) else { break }
            iter = next
        }

        return monthsArr.map { monthStart in
            let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
            let midOffset = daysInMonth / 2
            let midDate = calendar.date(byAdding: .day, value: midOffset, to: monthStart) ?? monthStart
            return TrendDataPoint(date: midDate, value: monthlyData[monthStart] ?? 0)
        }
    }
    
    /// Aggregate daily data into week buckets for the last `weeks` weeks.
    ///
    /// Unlike the month-based aggregator, this **includes the current partial
    /// week**: a weekly tracker cares most about the week they're actively
    /// working on, so hiding it would defeat the purpose of the chart.
    ///
    /// Week boundaries use `Calendar.dateInterval(of: .weekOfYear:)` — the same
    /// definition `WeeklyComplianceEvaluator` uses — so this chart and the
    /// weekly compliance card can never disagree about where a week starts.
    static func aggregatedByWeek(
        from data: [TrendDataPoint],
        weeks: Int,
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> [TrendDataPoint] {
        guard weeks > 0 else { return [] }
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return []
        }
        guard let cutoffWeekStart = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: currentWeekStart) else {
            return []
        }

        // Bucket points by the start of their containing week.
        var weeklyData: [Date: Int] = [:]
        for point in data {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: point.date)?.start else { continue }
            guard weekStart >= cutoffWeekStart && weekStart <= currentWeekStart else { continue }
            weeklyData[weekStart, default: 0] += point.value
        }

        // Build a contiguous, zero-filled run of week starts through the current week.
        var weekStarts: [Date] = []
        var iter = cutoffWeekStart
        while iter <= currentWeekStart {
            weekStarts.append(iter)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: iter) else { break }
            iter = next
        }

        return weekStarts.map { weekStart in
            // Plot mid-week so the point aligns with its axis label.
            let midDate = calendar.date(byAdding: .day, value: 3, to: weekStart) ?? weekStart
            return TrendDataPoint(date: midDate, value: weeklyData[weekStart] ?? 0)
        }
    }

    private var maxYValue: Int {
        let maxValue = aggregatedData.map(\.value).max() ?? 5
        // In weekly mode keep the weekly minimum reference line on-screen.
        let floorValue = isWeekly ? max(weeklyMinimumDays ?? 0, 5) : 5
        return max(maxValue + 1, floorValue)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(Typography.ringNumber)
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

#Preview("Trend Chart Card - Weekly") {
    let calendar = Calendar.current
    let today = Date()

    let sampleData: [TrendDataPoint] = (0..<120).compactMap { dayOffset in
        guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return nil }
        let weekday = calendar.component(.weekday, from: date)
        let isWeekday = weekday >= 2 && weekday <= 6
        let attended = isWeekday && Bool.random()
        return TrendDataPoint(date: date, value: attended ? 1 : 0)
    }

    ScrollView {
        VStack(spacing: 20) {
            TrendChartCard(data: sampleData, hasEnoughData: true, isWeekly: true, weeklyMinimumDays: 3)
            TrendChartCard(data: [], hasEnoughData: false, isWeekly: true, weeklyMinimumDays: 3)
        }
        .padding()
    }
    .background(DesignTokens.appBackground)
}
