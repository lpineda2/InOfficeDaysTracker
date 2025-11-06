//
//  CalendarErrorNotificationCenter.swift
//  InOfficeDaysTracker
//
//  Error notification system for calendar operations with recovery mechanisms
//

import Foundation
import EventKit

// MARK: - Calendar Error Notification System

/// Detailed error information for calendar operations
struct CalendarOperationError {
    let type: CalendarError
    let operation: String
    let context: [String: Any]
    let timestamp: Date
    let canRetry: Bool
    let suggestedAction: SuggestedAction
    
    enum SuggestedAction {
        case checkPermissions
        case selectDifferentCalendar
        case retryOperation
        case contactSupport
        case noAction
        
        var userMessage: String {
            switch self {
            case .checkPermissions:
                return "Check calendar permissions in Settings"
            case .selectDifferentCalendar:
                return "Select a different calendar in Settings"
            case .retryOperation:
                return "Tap to retry this operation"
            case .contactSupport:
                return "Contact support if this continues"
            case .noAction:
                return "This error was automatically handled"
            }
        }
    }
}

/// Notification center for calendar error reporting
class CalendarErrorNotificationCenter {
    static let shared = CalendarErrorNotificationCenter()
    
    /// Notification name for calendar operation errors
    static let errorNotification = Notification.Name("CalendarOperationError")
    
    private init() {}
    
    /// Post an error notification with detailed context
    func reportError(_ error: CalendarOperationError) {
        print("📢 [CalendarErrorCenter] Reporting error: \(error.type.localizedDescription)")
        print("   Operation: \(error.operation)")
        print("   Suggested Action: \(error.suggestedAction.userMessage)")
        print("   Can Retry: \(error.canRetry)")
        
        NotificationCenter.default.post(
            name: Self.errorNotification,
            object: error,
            userInfo: [
                "type": error.type,
                "operation": error.operation,
                "timestamp": error.timestamp,
                "canRetry": error.canRetry,
                "suggestedAction": error.suggestedAction
            ]
        )
    }
    
    /// Create and report a calendar operation error
    func reportError(
        type: CalendarError,
        operation: String,
        context: [String: Any] = [:],
        canRetry: Bool = true,
        suggestedAction: CalendarOperationError.SuggestedAction = .retryOperation
    ) {
        let error = CalendarOperationError(
            type: type,
            operation: operation,
            context: context,
            timestamp: Date(),
            canRetry: canRetry,
            suggestedAction: suggestedAction
        )
        reportError(error)
    }
}

// MARK: - Error Recovery Extensions

extension CalendarService {
    /// Enhanced error handling with recovery attempts
    func handleOperationError(_ error: Error, operation: String, canRetry: Bool = true) {
        let calendarError: CalendarError
        let suggestedAction: CalendarOperationError.SuggestedAction
        
        // Convert error to CalendarError with appropriate recovery strategy
        if let ekError = error as? NSError, ekError.domain == EKErrorDomain {
            switch EKError.Code(rawValue: ekError.code) {
            case .eventNotMutable:
                calendarError = .noWriteAccess
                suggestedAction = .selectDifferentCalendar
            case .noCalendar:
                calendarError = .calendarNotFound
                suggestedAction = .selectDifferentCalendar
            case .calendarReadOnly:
                calendarError = .noWriteAccess
                suggestedAction = .selectDifferentCalendar
            case .calendarIsImmutable:
                calendarError = .noWriteAccess
                suggestedAction = .selectDifferentCalendar
            default:
                calendarError = .eventCreationFailed(error.localizedDescription)
                suggestedAction = .retryOperation
            }
        } else if error is CalendarError {
            calendarError = error as! CalendarError
            suggestedAction = .retryOperation
        } else {
            calendarError = .eventCreationFailed(error.localizedDescription)
            suggestedAction = .retryOperation
        }
        
        // Report the error with context
        CalendarErrorNotificationCenter.shared.reportError(
            type: calendarError,
            operation: operation,
            context: ["originalError": error.localizedDescription],
            canRetry: canRetry,
            suggestedAction: suggestedAction
        )
    }
}