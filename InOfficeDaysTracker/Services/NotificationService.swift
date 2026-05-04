//
//  NotificationService.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import Foundation
import UserNotifications

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private override init() {
        super.init()
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            await MainActor.run {
                self.authorizationStatus = granted ? .authorized : .denied
            }
            
            return granted
        } catch {
            debugLog("❌", "Error requesting notification permission: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            self.authorizationStatus = settings.authorizationStatus
        }
    }
    
    func sendVisitNotification(type: VisitNotificationType) {
        guard authorizationStatus == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        switch type {
        case .entry:
            content.title = "Office Visit Started"
            content.body = "You've arrived at your office. Visit tracking has begun."
        case .exit:
            content.title = "Office Visit Ended"
            content.body = "You've left your office. Visit has been logged."
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate delivery
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("❌", "Error sending notification: \(error)")
            }
        }
    }
    
    /// Schedule exit notification with delay to work around iOS app suspension
    /// Uses UNTimeIntervalNotificationTrigger so notification delivery is handled by iOS
    /// This ensures the notification fires even if the app is suspended/terminated
    func scheduleExitNotification(afterDelay delay: TimeInterval) {
        guard authorizationStatus == .authorized else { return }
        
        // Cancel any existing pending exit notification
        cancelPendingExitNotification()
        
        let content = UNMutableNotificationContent()
        content.title = "Office Visit Ended"
        content.body = "You've left your office. Visit has been logged."
        content.sound = .default
        
        // Use time interval trigger so iOS delivers notification even if app is suspended
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "pending_exit_notification",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("❌", "Error scheduling exit notification: \(error)")
            } else {
                debugLog("✅", "Exit notification scheduled for \(Int(delay))s from now")
            }
        }
    }
    
    /// Cancel pending exit notification (e.g., when user re-enters during grace period)
    func cancelPendingExitNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["pending_exit_notification"]
        )
        debugLog("🔔", "Cancelled pending exit notification")
    }
    
    func sendGoalReminderNotification(current: Int, goal: Int) {
        guard authorizationStatus == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Office Goal Reminder"
        content.body = "You have \(current) of \(goal) office days this month. Keep it up!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "goal_reminder",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("❌", "Error sending goal reminder: \(error)")
            }
        }
    }
    
    func scheduleWeeklyGoalReminder() {
        guard authorizationStatus == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Office Check-in"
        content.body = "How's your office goal coming along this week?"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.weekday = 2 // Monday
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "weekly_reminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("❌", "Error scheduling weekly reminder: \(error)")
            }
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

enum VisitNotificationType {
    case entry
    case exit
}
