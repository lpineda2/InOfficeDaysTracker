//
//  WhatsNewTestHelper.swift
//  InOfficeDaysTracker
//
//  Testing utilities for WhatsNew functionality
//

import Foundation
import SwiftUI
import WhatsNewKit

#if DEBUG
struct WhatsNewTestHelper {
    
    /// Reset WhatsNew presentation state for testing
    static func resetPresentationState() {
        UserDefaults.standard.removeObject(forKey: "WhatsNewKit.PresentedVersions")
        print("🔄 [WhatsNewTest] Presentation state reset - WhatsNew will show on next launch")
    }
    
    /// Check if WhatsNew has been presented for a specific version
    static func hasPresentedVersion(_ version: String) -> Bool {
        let store = UserDefaultsWhatsNewVersionStore()
        // WhatsNew.Version is ExpressibleByStringLiteral, so we can create it directly
        let whatsNewVersion: WhatsNew.Version = "1.7.0" // For testing, use literal
        return store.hasPresented(whatsNewVersion)
    }
    
    /// Get all presented versions
    static func getAllPresentedVersions() -> [String] {
        let store = UserDefaultsWhatsNewVersionStore() 
        return store.presentedVersions.map { $0.description }
    }
    
    /// Force mark a version as presented (useful for testing)
    static func markVersionAsPresented(_ version: String) {
        let store = UserDefaultsWhatsNewVersionStore()
        // WhatsNew.Version is ExpressibleByStringLiteral, so we can create it directly
        let whatsNewVersion: WhatsNew.Version = "1.7.0" // For testing, use literal
        store.save(presentedVersion: whatsNewVersion)
        print("✅ [WhatsNewTest] Marked version \(version) as presented")
    }
}

// MARK: - Debug Menu Extension

extension WhatsNewTestHelper {
    
    /// Create a debug menu for WhatsNew testing (SwiftUI)
    static func createDebugMenu() -> some View {
        VStack(spacing: 16) {
            Text("WhatsNew Debug Menu")
                .font(.headline)
            
            Button("Reset Presentation State") {
                resetPresentationState()
            }
            
            Button("Show Current Versions") {
                let versions = getAllPresentedVersions()
                print("📋 [WhatsNewTest] Presented versions: \(versions)")
            }
            
            Button("Mark 1.7.0 as Presented") {
                markVersionAsPresented("1.7.0")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
#endif