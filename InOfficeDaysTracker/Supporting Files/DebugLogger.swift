//
//  DebugLogger.swift
//  InOfficeDaysTracker
//
//  Debug logging utility that only logs in DEBUG builds
//  Prevents sensitive user data from appearing in production logs
//

import Foundation

/// Debug logging that only outputs in DEBUG builds
/// Use this instead of print() to avoid leaking sensitive data in production
func debugLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("[\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
    #endif
}

/// Debug logging with emoji prefix for easier visual scanning
func debugLog(_ emoji: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("\(emoji) [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
    #endif
}
