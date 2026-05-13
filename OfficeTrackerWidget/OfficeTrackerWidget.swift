//
//  OfficeTrackerWidget.swift
//  OfficeTrackerWidget
//
//  Main widget entry point with TimelineProvider
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), widgetData: WidgetData.placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let data = WidgetDataManager.shared.createWidgetData()
        let entry = SimpleEntry(date: Date(), widgetData: data)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        
        debugLog("🔄", "[Widget] getTimeline called at \(currentDate)")
        
        // Get fresh data for the timeline
        let widgetData = WidgetDataManager.shared.createWidgetData()
        
        debugLog("🔄", "[Widget] Timeline data - isInOffice: \(widgetData.isCurrentlyInOffice), visits: \(widgetData.current)")
        
        // Check if there's an active exit grace period
        let gracePeriodExpires = checkForActiveGracePeriod()
        
        if let expiryDate = gracePeriodExpires, expiryDate > currentDate {
            // Grace period is active - schedule next update for when it expires
            let timeUntilExpiry = expiryDate.timeIntervalSince(currentDate)
            debugLog("🔄", "[Widget] Grace period active, expires in \(Int(timeUntilExpiry))s")
            
            // Create current entry
            let entry = SimpleEntry(date: currentDate, widgetData: widgetData)
            entries.append(entry)
            
            // Create entry for grace period expiration (widget will refresh and show new status)
            let expiryEntry = SimpleEntry(date: expiryDate, widgetData: widgetData)
            entries.append(expiryEntry)
            
            // Schedule timeline to update when grace period expires (with small buffer)
            let nextUpdate = expiryDate.addingTimeInterval(10) // 10 second buffer
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            debugLog("🔄", "[Widget] Scheduled next update for grace period expiry: \(nextUpdate)")
            completion(timeline)
        } else if widgetData.isCurrentlyInOffice {
            // CRITICAL: When user is in office, create entries every 15 minutes
            // so the visit duration display stays accurate
            debugLog("🔄", "[Widget] User is in office - using 15-minute update intervals")
            
            for intervalOffset in 0..<8 { // 8 entries × 15 min = 2 hours
                let entryDate = Calendar.current.date(byAdding: .minute, value: intervalOffset * 15, to: currentDate)!
                let entry = SimpleEntry(date: entryDate, widgetData: widgetData)
                entries.append(entry)
            }

            // Refresh timeline every 15 minutes for live duration updates
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            debugLog("🔄", "[Widget] Scheduled next update in 15 min for in-office duration tracking")
            completion(timeline)
        } else {
            // Not in office, no grace period - use hourly updates
            // Create entries for the next 6 hours, updating hourly
            for hourOffset in 0..<6 {
                let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
                // Use the same data for all timeline entries since they represent the current state
                let entry = SimpleEntry(date: entryDate, widgetData: widgetData)
                entries.append(entry)
            }

            // Update hourly
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    /// Check UserDefaults for active grace period and return expiry date
    private func checkForActiveGracePeriod() -> Date? {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.lpineda.InOfficeDaysTracker"),
              let expiryDate = sharedDefaults.object(forKey: "GracePeriodExpires") as? Date else {
            return nil
        }
        
        // Only return if grace period hasn't expired yet
        return expiryDate > Date() ? expiryDate : nil
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let widgetData: WidgetData
}

struct OfficeTrackerWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        // Home Screen widgets
        case .systemSmall:
            SmallWidgetView(data: entry.widgetData)
        case .systemMedium:
            MediumWidgetView(data: entry.widgetData, entryDate: entry.date)
        case .systemLarge:
            LargeWidgetView(data: entry.widgetData, entryDate: entry.date)
        // Lock Screen widgets
        case .accessoryCircular:
            AccessoryCircularView(data: entry.widgetData)
        case .accessoryRectangular:
            AccessoryRectangularView(data: entry.widgetData)
        case .accessoryInline:
            AccessoryInlineView(data: entry.widgetData)
        default:
            MediumWidgetView(data: entry.widgetData, entryDate: entry.date)
        }
    }
}

struct OfficeTrackerWidget: Widget {
    let kind: String = "OfficeTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            OfficeTrackerWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Office Tracker")
        .description("Track your office visit progress.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,  // Home Screen widgets
            .accessoryCircular, .accessoryRectangular, .accessoryInline  // Lock Screen widgets
        ])
    }
}

#Preview("Home Screen Small", as: .systemSmall) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
}

#Preview("Lock Screen Circular", as: .accessoryCircular) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
}

#Preview("Lock Screen Rectangular", as: .accessoryRectangular) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
}

#Preview("Lock Screen Inline", as: .accessoryInline) {
    OfficeTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData.placeholder)
    SimpleEntry(date: .now, widgetData: WidgetData.sampleProgress)
}
