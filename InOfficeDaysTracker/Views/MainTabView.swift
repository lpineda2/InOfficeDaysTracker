//
//  MainTabView.swift
//  InOfficeDaysTracker
//
//  Tab bar navigation following Apple Human Interface Guidelines
//  - Uses filled SF Symbols for consistency
//  - Single-word labels for clarity
//  - sidebarAdaptable style for iPad support
//

import SwiftUI

/// Main tab bar container for app navigation
/// Per Apple HIG: Tab bars help people understand different types of information
/// and let them quickly switch between sections while preserving navigation state
struct MainTabView: View {
    @EnvironmentObject var appData: AppData
    @State private var selectedTab: Tab = .home
    
    /// Tab identifiers following Apple HIG naming conventions
    enum Tab: Hashable {
        case home
        case history
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab - Main dashboard
            NavigationStack {
                MainProgressView(appData: appData, selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Dashboard", systemImage: "square.grid.2x2.fill")
            }
            .tag(Tab.home)
            
            // History Tab - Visit history
            NavigationStack {
                HistoryView(appData: appData)
            }
            .tabItem {
                Label("History", systemImage: "calendar")
            }
            .tag(Tab.history)
            
            // Settings Tab - App configuration
            NavigationStack {
                SettingsView(appData: appData)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(Tab.settings)
        }
        // Use sidebarAdaptable for iPad - converts to sidebar per HIG
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppData())
}
