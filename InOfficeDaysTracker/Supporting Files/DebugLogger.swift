//
//  DebugLogger.swift
//  InOfficeDaysTracker
//
//  Debug logging utilities that work in both DEBUG and TestFlight builds
//  - Console output in DEBUG builds for immediate feedback
//  - File logging in all builds for TestFlight troubleshooting
//

import Foundation

/// Debug logging that prints to console in DEBUG and writes to file in all builds
/// Use this instead of print() to avoid leaking sensitive data in production
func debugLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    // Console logging in debug builds for immediate feedback
    let fileName = (file as NSString).lastPathComponent
    print("[\(fileName):\(line)] \(function) - \(message)")
    #endif
    
    // File logging in all builds (for TestFlight export)
    PersistentLogger.shared.log(message, level: .info, file: file, function: function, line: line)
}

/// Debug logging with emoji prefix for easier visual scanning
func debugLog(_ emoji: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    // Console logging in debug builds
    let fileName = (file as NSString).lastPathComponent
    print("\(emoji) [\(fileName):\(line)] \(function) - \(message)")
    #endif
    
    // File logging in all builds
    PersistentLogger.shared.log(emoji, message, file: file, function: function, line: line)
}
