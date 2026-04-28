//
//  InOfficeDaysTrackerApp.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import SwiftUI
import WhatsNewKit

@main
struct InOfficeDaysTrackerApp: App {
    @StateObject private var appData = AppData()
    @StateObject private var locationService = LocationService()
    @StateObject private var notificationService = NotificationService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
                .environmentObject(locationService)
                .environmentObject(notificationService)
                .onAppear {
                    locationService.setAppData(appData)
                }
                // Automatically present WhatsNew for lock screen widgets
                .whatsNewSheet(
                    layout: .inOfficeDaysStyle
                )
                // Configure WhatsNew environment for automatic presentation
                .environment(
                    \.whatsNew,
                    WhatsNewEnvironment(
                        versionStore: UserDefaultsWhatsNewVersionStore(),
                        whatsNewCollection: self
                    )
                )
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Run repair when app comes to foreground
                Task { @MainActor in
                    appData.triggerForegroundRepair()
                }
            }
        }
    }
}
