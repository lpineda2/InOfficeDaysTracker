//
//  CalendarErrorBanner.swift
//  InOfficeDaysTracker
//
//  Error banner system for calendar integration issues
//

import SwiftUI

struct CalendarErrorBanner: View {
    let error: CalendarBannerError
    let onAction: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.icon)
                .foregroundColor(error.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !error.actionTitle.isEmpty {
                Button(error.actionTitle) {
                    onAction()
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            }
            
            if error.canDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(error.backgroundColor)
                .stroke(error.color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct CalendarBannerError {
    let type: ErrorType
    let title: String
    let message: String
    let actionTitle: String
    let canDismiss: Bool
    let persistenceLevel: PersistenceLevel
    
    // Computed properties that delegate to ErrorType
    var icon: String {
        return type.icon
    }
    
    var color: Color {
        return type.color
    }
    
    var backgroundColor: Color {
        return type.backgroundColor
    }
    
    enum ErrorType {
        case permissionRevoked
        case calendarUnavailable
        case syncFailed
        case quotaExceeded
        
        var icon: String {
            switch self {
            case .permissionRevoked:
                return "calendar.badge.exclamationmark"
            case .calendarUnavailable:
                return "calendar.badge.minus"
            case .syncFailed:
                return "exclamationmark.triangle"
            case .quotaExceeded:
                return "calendar.badge.clock"
            }
        }
        
        var color: Color {
            switch self {
            case .permissionRevoked:
                return .orange
            case .calendarUnavailable:
                return .red
            case .syncFailed:
                return .yellow
            case .quotaExceeded:
                return .blue
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .permissionRevoked:
                return .orange.opacity(0.1)
            case .calendarUnavailable:
                return .red.opacity(0.1)
            case .syncFailed:
                return .yellow.opacity(0.1)
            case .quotaExceeded:
                return .blue.opacity(0.1)
            }
        }
    }
    
    enum PersistenceLevel {
        case session      // Until app restart
        case threeDays    // Show for 3 days max
        case untilFixed   // Until user fixes or disables feature
    }
    
    static let permissionRevoked = CalendarBannerError(
        type: .permissionRevoked,
        title: "Calendar Access Revoked",
        message: "Calendar integration is disabled",
        actionTitle: "Re-enable",
        canDismiss: true,
        persistenceLevel: .untilFixed
    )
    
    static let calendarUnavailable = CalendarBannerError(
        type: .calendarUnavailable,
        title: "Calendar Unavailable",
        message: "Selected calendar no longer available",
        actionTitle: "Choose Calendar",
        canDismiss: true,
        persistenceLevel: .untilFixed
    )
    
    static let syncFailed = CalendarBannerError(
        type: .syncFailed,
        title: "Calendar Sync Failed",
        message: "Unable to create calendar events",
        actionTitle: "Retry",
        canDismiss: true,
        persistenceLevel: .session
    )
}

// MARK: - Banner Manager

@MainActor
class CalendarBannerManager: ObservableObject {
    @Published var currentBanner: CalendarBannerError?
    @Published var dismissedBanners: Set<String> = []
    
    private let userDefaults = UserDefaults.standard
    private let dismissedBannersKey = "DismissedCalendarBanners"
    
    init() {
        loadDismissedBanners()
    }
    
    func showBanner(_ banner: CalendarBannerError) {
        let bannerId = "\(banner.type)"
        
        // Check if banner was dismissed and still within persistence window
        if dismissedBanners.contains(bannerId) {
            return
        }
        
        currentBanner = banner
        
        // Auto-dismiss after 8 seconds if dismissible
        if banner.canDismiss && banner.persistenceLevel == .session {
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                if self.currentBanner?.type == banner.type {
                    self.dismissBanner()
                }
            }
        }
    }
    
    func dismissBanner() {
        guard let banner = currentBanner else { return }
        
        currentBanner = nil
        
        // Mark as dismissed based on persistence level
        let bannerId = "\(banner.type)"
        dismissedBanners.insert(bannerId)
        saveDismissedBanners()
        
        // Schedule cleanup based on persistence level
        switch banner.persistenceLevel {
        case .session:
            // Will be cleared on next app launch
            break
        case .threeDays:
            DispatchQueue.main.asyncAfter(deadline: .now() + 3 * 24 * 3600) {
                self.dismissedBanners.remove(bannerId)
                self.saveDismissedBanners()
            }
        case .untilFixed:
            // Stays dismissed until manually cleared
            break
        }
    }
    
    func clearDismissedBanner(for type: CalendarBannerError.ErrorType) {
        let bannerId = "\(type)"
        dismissedBanners.remove(bannerId)
        saveDismissedBanners()
    }
    
    private func loadDismissedBanners() {
        if let data = userDefaults.data(forKey: dismissedBannersKey),
           let dismissed = try? JSONDecoder().decode(Set<String>.self, from: data) {
            dismissedBanners = dismissed
        }
    }
    
    private func saveDismissedBanners() {
        if let data = try? JSONEncoder().encode(dismissedBanners) {
            userDefaults.set(data, forKey: dismissedBannersKey)
        }
    }
}

// MARK: - Preview

struct CalendarErrorBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            CalendarErrorBanner(
                error: .permissionRevoked,
                onAction: { },
                onDismiss: { }
            )
            
            CalendarErrorBanner(
                error: .calendarUnavailable,
                onAction: { },
                onDismiss: { }
            )
            
            CalendarErrorBanner(
                error: .syncFailed,
                onAction: { },
                onDismiss: { }
            )
        }
        .padding()
    }
}