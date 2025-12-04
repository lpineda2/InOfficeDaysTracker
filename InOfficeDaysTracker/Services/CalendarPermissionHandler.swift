//
//  CalendarPermissionHandler.swift
//  InOfficeDaysTracker
//
//  Simplified calendar permission handling
//

import Foundation
import EventKit
import SwiftUI

@MainActor
class CalendarPermissionHandler: ObservableObject {
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isRequestingPermission = false
    
    private let eventStore = EKEventStore()
    
    init() {
        updateAuthorizationStatus()
    }
    
    var hasAccess: Bool {
        return authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
    }
    
    var needsPermission: Bool {
        return authorizationStatus == .notDetermined
    }
    
    var wasDenied: Bool {
        return authorizationStatus == .denied
    }
    
    var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Calendar access not yet requested"
        case .restricted:
            return "Calendar access is restricted"
        case .denied:
            return "Calendar access was denied"
        case .fullAccess:
            return "Full calendar access granted"
        case .writeOnly:
            return "Write-only calendar access granted"
        @unknown default:
            return "Unknown status"
        }
    }
    
    func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        print("📅 [CalendarPermission] Status updated: \(authorizationStatus.rawValue), hasAccess: \(hasAccess)")
    }
    
    func requestPermission() async -> Bool {
        print("📅 [CalendarPermission] requestPermission called")
        isRequestingPermission = true
        defer { 
            isRequestingPermission = false 
            print("📅 [CalendarPermission] requestPermission completed")
        }
        
        do {
            print("📅 [CalendarPermission] Requesting full access to events...")
            let granted = try await eventStore.requestFullAccessToEvents()
            print("📅 [CalendarPermission] Permission result: \(granted)")
            
            // If granted, set status directly rather than re-querying
            // (iOS may not have updated the class-level status yet)
            if granted {
                authorizationStatus = .fullAccess
                print("📅 [CalendarPermission] Status set to fullAccess")
            } else {
                // Small delay to let iOS update the status
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                updateAuthorizationStatus()
            }
            return granted
        } catch {
            print("📅 [CalendarPermission] Permission request failed: \(error.localizedDescription)")
            updateAuthorizationStatus()
            return false
        }
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
