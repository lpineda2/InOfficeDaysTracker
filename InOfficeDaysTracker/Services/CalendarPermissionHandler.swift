//
//  CalendarPermissionHandler.swift
//  InOfficeDaysTracker
//
//  Handles calendar permission requests and states
//

import Foundation
import EventKit
import SwiftUI

@MainActor
class CalendarPermissionHandler: ObservableObject {
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isRequestingPermission = false
    @Published var permissionError: String?
    
    private let eventStore = EKEventStore()
    
    init() {
        updateAuthorizationStatus()
    }
    
    var hasAccess: Bool {
        return authorizationStatus == .fullAccess
    }
    
    var needsPermission: Bool {
        return authorizationStatus == .notDetermined
    }
    
    var wasdenied: Bool {
        return authorizationStatus == .denied
    }
    
    var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Calendar access not yet requested"
        case .restricted:
            return "Calendar access is restricted on this device"
        case .denied:
            return "Calendar access was denied"
        case .fullAccess:
            return "Full calendar access granted"
        case .writeOnly:
            return "Write-only calendar access granted"
        @unknown default:
            return "Unknown calendar permission status"
        }
    }
    
    var canWriteEvents: Bool {
        return authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
    }
    
    func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestPermission() async -> Bool {
        print("🔍 [CalendarPermissionHandler] Starting permission request")
        print("  - Initial status: \(authorizationStatus.rawValue)")
        
        await MainActor.run {
            isRequestingPermission = true
            permissionError = nil
        }
        
        do {
            print("🔍 [CalendarPermissionHandler] Calling requestFullAccessToEvents()")
            let granted = try await eventStore.requestFullAccessToEvents()
            print("🔍 [CalendarPermissionHandler] Request completed - granted: \(granted)")
            
            await MainActor.run {
                print("🔍 [CalendarPermissionHandler] Updating status...")
                print("  - Status before update: \(authorizationStatus.rawValue)")
                updateAuthorizationStatus()
                print("  - Status after update: \(authorizationStatus.rawValue)")
                print("  - hasAccess: \(hasAccess)")
                
                isRequestingPermission = false
                
                // Simulator fallback: if permission was granted but status didn't update,
                // manually set to fullAccess to work around simulator EventKit issues
                if granted && authorizationStatus == .notDetermined {
                    print("🔍 [CalendarPermissionHandler] Simulator fallback - manually setting fullAccess")
                    authorizationStatus = .fullAccess
                }
                
                if !granted && authorizationStatus == .denied {
                    permissionError = "Calendar access is required to create events for your office visits"
                }
            }
            
            return granted
        } catch {
            await MainActor.run {
                updateAuthorizationStatus()
                isRequestingPermission = false
                permissionError = "Failed to request calendar permission: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    // Check if we should show permission prompts based on setup state
    func shouldShowPermissionPrompt(hasSeenCalendarSetup: Bool) -> Bool {
        return needsPermission && !hasSeenCalendarSetup
    }
}

// MARK: - Permission UI Components

struct CalendarPermissionView: View {
    @ObservedObject var permissionHandler: CalendarPermissionHandler
    let onGranted: () -> Void
    let onSkipped: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            if permissionHandler.needsPermission {
                requestPermissionView
            } else if permissionHandler.wasdenied {
                deniedPermissionView
            } else if permissionHandler.hasAccess {
                grantedView
            }
        }
        .onAppear {
            permissionHandler.updateAuthorizationStatus()
        }
        .onChange(of: permissionHandler.hasAccess) {
            print("🔍 [CalendarPermissionView] onChange triggered - hasAccess: \(permissionHandler.hasAccess)")
            if permissionHandler.hasAccess {
                print("🔍 [CalendarPermissionView] Permission granted detected via onChange - calling onGranted()")
                onGranted()
            }
        }
    }
    
    private var requestPermissionView: some View {
        VStack(spacing: 16) {
            Text("Create calendar events for your office visits to visualize your work patterns.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                PermissionFeatureRow(
                    icon: "checkmark.circle",
                    title: "Automatic Event Creation",
                    description: "Office visits become calendar events"
                )
                
                PermissionFeatureRow(
                    icon: "lock.shield",
                    title: "Privacy First",
                    description: "Events stored in your calendar app"
                )
            }
            
            if permissionHandler.isRequestingPermission {
                ProgressView("Requesting permission...")
                    .padding()
            } else {
                VStack(spacing: 12) {
                    Button("Grant Calendar Access") {
                        Task {
                            print("🔍 [CalendarPermissionView] Grant button tapped")
                            print("  - Before request - Status: \(permissionHandler.authorizationStatus.rawValue)")
                            
                            let granted = await permissionHandler.requestPermission()
                            print("  - Request result: \(granted)")
                            print("  - After request - Status: \(permissionHandler.authorizationStatus.rawValue)")
                            
                            // Add a delay to allow system to update, then refresh status
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            
                            await MainActor.run {
                                // Don't call updateAuthorizationStatus here as it may override 
                                // the simulator fallback that was set in requestPermission()
                                print("  - Status after request: \(permissionHandler.authorizationStatus.rawValue)")
                                print("  - hasAccess: \(permissionHandler.hasAccess)")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("Or continue to complete setup without calendar integration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if let error = permissionHandler.permissionError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var deniedPermissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Calendar Access Denied")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Calendar integration is disabled. To enable it, grant access in Settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button("Open Settings") {
                    permissionHandler.openSettings()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Continue Without Calendar") {
                    onSkipped()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var grantedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Calendar Access Granted")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You can now select a calendar for your office visit events.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Continue") {
                onGranted()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct PermissionFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}