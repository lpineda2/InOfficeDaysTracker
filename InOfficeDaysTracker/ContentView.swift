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
    }
}

#Preview {
    ContentView()
        .environmentObject(AppData())
        .environmentObject(LocationService())
        .environmentObject(NotificationService.shared)
}
