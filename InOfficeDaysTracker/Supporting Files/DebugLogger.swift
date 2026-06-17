//
//  DebugLogger.swift
//  InOfficeDaysTracker
//
//  Debug logging utility that only logs in DEBUG builds
//  Prevents sensitive user data from appearing in production logs
//  Now includes persistent file-based logging for troubleshooting (main app only)
//

import Foundation

/// Debug logging that only outputs in DEBUG builds
/// Use this instead of print() to avoid leaking sensitive data in production
/// Logs are written to both console and persistent log file (main app only)
func debugLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logMessage = "[\(timestamp)] [\(fileName):\(line)] \(function) - \(message)"
    
    // Print to console for immediate visibility
    print(logMessage)
    
    // Write to persistent log file for later troubleshooting (main app only)
    // Widget extension doesn't have access to PersistentLogger
    #if !WIDGET_EXTENSION
    PersistentLogger.shared.log(message, level: .info, file: file, function: function, line: line)
    #endif
    #endif
}

/// Debug logging with emoji prefix for easier visual scanning
func debugLog(_ emoji: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logMessage = "\(emoji) [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)"
    
    // Print to console for immediate visibility
    print(logMessage)
    
    // Write to persistent log file for later troubleshooting (main app only)
    // Widget extension doesn't have access to PersistentLogger
    #if !WIDGET_EXTENSION
    PersistentLogger.shared.log(emoji, message, file: file, function: function, line: line)
    #endif
    #endif
}
