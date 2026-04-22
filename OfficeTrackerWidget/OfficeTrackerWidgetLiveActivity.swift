//
//  OfficeTrackerWidgetLiveActivity.swift
//  OfficeTrackerWidget
//
//  Created by Luis Pineda on 10/3/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct OfficeTrackerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct OfficeTrackerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OfficeTrackerWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension OfficeTrackerWidgetAttributes {
    fileprivate static var preview: OfficeTrackerWidgetAttributes {
        OfficeTrackerWidgetAttributes(name: "World")
    }
}

extension OfficeTrackerWidgetAttributes.ContentState {
    fileprivate static var smiley: OfficeTrackerWidgetAttributes.ContentState {
        OfficeTrackerWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: OfficeTrackerWidgetAttributes.ContentState {
         OfficeTrackerWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: OfficeTrackerWidgetAttributes.preview) {
   OfficeTrackerWidgetLiveActivity()
} contentStates: {
    OfficeTrackerWidgetAttributes.ContentState.smiley
    OfficeTrackerWidgetAttributes.ContentState.starEyes
}
