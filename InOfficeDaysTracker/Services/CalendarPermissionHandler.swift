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
    }
    
    func requestPermission() async -> Bool {
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            updateAuthorizationStatus()
            return granted
        } catch {
            print("📅 [Calendar] Permission request failed: \(error.localizedDescription)")
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
