//
//  InOfficeDaysTrackerApp.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import SwiftUI

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
        }
    }
}
