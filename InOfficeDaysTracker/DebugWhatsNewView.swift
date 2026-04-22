//
//  DebugWhatsNewView.swift  
//  InOfficeDaysTracker
//
//  Debug view to test WhatsNew functionality
//

import SwiftUI
import WhatsNewKit

#if DEBUG
struct DebugWhatsNewView: View {
    @State private var whatsNew: WhatsNew?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("WhatsNew Debug Panel")
                .font(.title2)
                .fontWeight(.bold)
            
            Button("🎉 Show WhatsNew Screen") {
                whatsNew = WhatsNewConfiguration.lockScreenWidgets
            }
            
            Button("🔄 Reset Presentation State") {
                WhatsNewTestHelper.resetPresentationState()
            }
            
            Button("📋 Check Presented Versions") {
                let versions = WhatsNewTestHelper.getAllPresentedVersions()
                print("📋 Presented versions: \(versions)")
            }
            
            Text("Check console for debug output")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .sheet(
            whatsNew: $whatsNew,
            layout: .inOfficeDaysStyle
        )
    }
}

struct DebugWhatsNewView_Previews: PreviewProvider {
    static var previews: some View {
        DebugWhatsNewView()
    }
}
#endif
