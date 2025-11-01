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
    }
}
