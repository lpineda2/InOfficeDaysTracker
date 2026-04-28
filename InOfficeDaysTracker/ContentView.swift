//
//  ContentView.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var notificationService: NotificationService
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            if appData.settings.isSetupComplete {
                MainTabView()
            } else {
                SetupView(
                    appData: appData,
                    locationService: locationService,
                    notificationService: notificationService
                )
            }
        }
        .preferredColorScheme(.none) // Support both light and dark mode
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                handleAppBecameActive()
            }
        }
    }
    
    /// Handle app entering foreground - trigger location verification
    private func handleAppBecameActive() {
        // Only verify if setup is complete and location is enabled
        guard appData.settings.isSetupComplete,
              locationService.isLocationEnabled else {
            return
        }
        
        Task {
            await locationService.verifyLocationOnForeground()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppData())
        .environmentObject(LocationService())
        .environmentObject(NotificationService.shared)
}
