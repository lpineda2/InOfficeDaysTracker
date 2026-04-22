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
            MediumWidgetView(data: entry.widgetData)
        case .systemLarge:
            LargeWidgetView(data: entry.widgetData)
        // Lock Screen widgets
        case .accessoryCircular:
            AccessoryCircularView(data: entry.widgetData)
        case .accessoryRectangular:
            AccessoryRectangularView(data: entry.widgetData)
        case .accessoryInline:
            AccessoryInlineView(data: entry.widgetData)
        default:
            MediumWidgetView(data: entry.widgetData)
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
