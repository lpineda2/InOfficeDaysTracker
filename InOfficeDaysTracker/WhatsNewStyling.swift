//
//  WhatsNewStyling.swift
//  InOfficeDaysTracker
//
//  Custom styling and colors for WhatsNew to match app design
//

import SwiftUI
import WhatsNewKit

extension WhatsNew.Layout {
    /// Custom layout that matches InOfficeDaysTracker design language
    static var inOfficeDaysStyle: WhatsNew.Layout {
        WhatsNew.Layout(
            showsScrollViewIndicators: false,
            contentSpacing: 32,
            contentPadding: EdgeInsets(
                top: 50,
                leading: 24,
                bottom: 24, 
                trailing: 24
            ),
            featureListSpacing: 24,
            featureImageWidth: 64,
            featureHorizontalSpacing: 16,
            footerActionSpacing: 20
        )
    }
}

extension Color {
    /// App-specific colors for WhatsNew (matching your existing design)
    static var whatsNewAccent: Color {
        // This should match your app's accent color
        .accentColor
    }
    
    static var whatsNewSecondary: Color {
        .secondary
    }
}

// MARK: - Preview Support

#if DEBUG
struct WhatsNewPreview: View {
    @State private var whatsNew: WhatsNew? = WhatsNewConfiguration.lockScreenWidgets
    
    var body: some View {
        Button("Show WhatsNew") {
            whatsNew = WhatsNewConfiguration.lockScreenWidgets
        }
        .sheet(
            whatsNew: $whatsNew,
            layout: .inOfficeDaysStyle
        )
    }
}

struct WhatsNewPreview_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewPreview()
    }
}
#endif