//
//  PersistentLogger.swift
//  InOfficeDaysTracker
//
//  Persistent file-based logging for troubleshooting
//  Logs are written to app's Documents directory and can be exported
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Persistent logger that writes to a file for troubleshooting
/// Active in DEBUG and TestFlight builds for troubleshooting
/// Automatically disabled in App Store production builds
class PersistentLogger {
    static let shared = PersistentLogger()
    
    private let fileManager = FileManager.default
    private let logFileName = "InOfficeDaysTracker.log"
    private let maxLogFileSize: Int64 = 5 * 1024 * 1024 // 5MB
    private let maxLogAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    private var logFileURL: URL?
    private let logQueue = DispatchQueue(label: "com.lpineda.InOfficeDaysTracker.logging", qos: .utility)
    private var isEnabled = false
    
    private init() {
        // Enable logging in DEBUG and TestFlight builds
        // TestFlight builds have the embedded.mobileprovision file
        #if DEBUG
        setupLogFile()
        isEnabled = true
        cleanupOldLogs()
        #else
        // Check if this is a TestFlight build (has embedded.mobileprovision)
        if isTestFlightBuild() {
            setupLogFile()
            isEnabled = true
            cleanupOldLogs()
        }
        #endif
    }
    
    /// Check if running in TestFlight
    private func isTestFlightBuild() -> Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return receiptURL.path.contains("sandboxReceipt")
    }
    
    // MARK: - Setup
    
    private func setupLogFile() {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ [PersistentLogger] Could not access documents directory")
            return
        }
        
        logFileURL = documentsURL.appendingPathComponent(logFileName)
        
        // Create log file if it doesn't exist
        if let logURL = logFileURL, !fileManager.fileExists(atPath: logURL.path) {
            fileManager.createFile(atPath: logURL.path, contents: nil, attributes: nil)
            writeHeader()
        }
    }
    
    private func writeHeader() {
        #if canImport(UIKit)
        let deviceInfo = """
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        """
        #else
        let deviceInfo = """
        Device: Unknown (Widget Extension)
        iOS Version: Unknown
        """
        #endif
        
        let header = """
        ================================================================================
        InOfficeDaysTracker Debug Log
        Started: \(ISO8601DateFormatter().string(from: Date()))
        \(deviceInfo)
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
        ================================================================================
        
        """
        writeToFile(header)
    }
    
    // MARK: - Logging
    
    /// Log a message to the persistent log file
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled, let logURL = logFileURL else { return }
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            let fileName = (file as NSString).lastPathComponent
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let logEntry = "\(level.emoji) [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)\n"
            
            // Also print to console for immediate visibility
            print(logEntry.trimmingCharacters(in: .newlines))
            
            self.writeToFile(logEntry)
            self.checkAndRotateLogIfNeeded()
        }
    }
    
    /// Log with emoji prefix (for compatibility with existing debugLog calls)
    func log(_ emoji: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled, let logURL = logFileURL else { return }
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            let fileName = (file as NSString).lastPathComponent
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let logEntry = "\(emoji) [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)\n"
            
            // Also print to console
            print(logEntry.trimmingCharacters(in: .newlines))
            
            self.writeToFile(logEntry)
            self.checkAndRotateLogIfNeeded()
        }
    }
    
    private func writeToFile(_ content: String) {
        guard let logURL = logFileURL else { return }
        
        do {
            let fileHandle = try FileHandle(forWritingTo: logURL)
            fileHandle.seekToEndOfFile()
            if let data = content.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } catch {
            // If file doesn't exist or can't be opened, try creating it
            do {
                try content.write(to: logURL, atomically: true, encoding: .utf8)
            } catch {
                print("❌ [PersistentLogger] Failed to write to log file: \(error)")
            }
        }
    }
    
    // MARK: - Log Management
    
    private func checkAndRotateLogIfNeeded() {
        guard let logURL = logFileURL else { return }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: logURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if fileSize > maxLogFileSize {
                rotateLog()
            }
        } catch {
            print("❌ [PersistentLogger] Failed to check log file size: \(error)")
        }
    }
    
    private func rotateLog() {
        guard let logURL = logFileURL else { return }
        
        // Archive current log with timestamp
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        }.string(from: Date())
        
        let archiveFileName = "InOfficeDaysTracker_\(timestamp).log"
        let archiveURL = logURL.deletingLastPathComponent().appendingPathComponent(archiveFileName)
        
        do {
            try fileManager.moveItem(at: logURL, to: archiveURL)
            fileManager.createFile(atPath: logURL.path, contents: nil, attributes: nil)
            writeHeader()
            print("✅ [PersistentLogger] Rotated log file to \(archiveFileName)")
        } catch {
            print("❌ [PersistentLogger] Failed to rotate log file: \(error)")
        }
    }
    
    private func cleanupOldLogs() {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.creationDateKey], options: [])
            let logFiles = files.filter { $0.lastPathComponent.hasPrefix("InOfficeDaysTracker") && $0.pathExtension == "log" }
            
            for file in logFiles {
                let attributes = try fileManager.attributesOfItem(atPath: file.path)
                if let creationDate = attributes[.creationDate] as? Date {
                    let age = Date().timeIntervalSince(creationDate)
                    if age > maxLogAge {
                        try fileManager.removeItem(at: file)
                        print("🗑️ [PersistentLogger] Deleted old log file: \(file.lastPathComponent)")
                    }
                }
            }
        } catch {
            print("❌ [PersistentLogger] Failed to cleanup old logs: \(error)")
        }
    }
    
    // MARK: - Export
    
    /// Get all log files for export
    func getAllLogFiles() -> [URL] {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.creationDateKey], options: [])
            let logFiles = files.filter { $0.lastPathComponent.hasPrefix("InOfficeDaysTracker") && $0.pathExtension == "log" }
            
            // Sort by creation date, newest first
            return logFiles.sorted { file1, file2 in
                let date1 = (try? fileManager.attributesOfItem(atPath: file1.path)[.creationDate] as? Date) ?? Date.distantPast
                let date2 = (try? fileManager.attributesOfItem(atPath: file2.path)[.creationDate] as? Date) ?? Date.distantPast
                return date1 > date2
            }
        } catch {
            print("❌ [PersistentLogger] Failed to get log files: \(error)")
            return []
        }
    }
    
    /// Get the current log file URL for export
    func getCurrentLogFileURL() -> URL? {
        return logFileURL
    }
    
    /// Create a combined log file with all logs for easy export
    func createCombinedLogFile() -> URL? {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ [PersistentLogger] DIAGNOSTIC: Could not access documents directory")
            return nil
        }
        
        print("📁 [PersistentLogger] DIAGNOSTIC: Documents URL: \(documentsURL.path)")
        
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        }.string(from: Date())
        
        let combinedFileName = "InOfficeDaysTracker_Combined_\(timestamp).log"
        let combinedURL = documentsURL.appendingPathComponent(combinedFileName)
        
        print("📄 [PersistentLogger] DIAGNOSTIC: Combined file URL: \(combinedURL.path)")
        
        let logFiles = getAllLogFiles()
        print("📚 [PersistentLogger] DIAGNOSTIC: Found \(logFiles.count) log files")
        
        var combinedContent = """
        ================================================================================
        InOfficeDaysTracker Combined Debug Log
        Generated: \(ISO8601DateFormatter().string(from: Date()))
        Number of log files: \(logFiles.count)
        ================================================================================
        
        """
        
        for (index, logFile) in logFiles.enumerated() {
            combinedContent += "\n\n"
            combinedContent += "================================================================================\n"
            combinedContent += "Log File \(index + 1): \(logFile.lastPathComponent)\n"
            combinedContent += "================================================================================\n\n"
            
            if let content = try? String(contentsOf: logFile, encoding: .utf8) {
                combinedContent += content
            } else {
                combinedContent += "[Error: Could not read log file]\n"
            }
        }
        
        do {
            try combinedContent.write(to: combinedURL, atomically: true, encoding: .utf8)
            
            // Verify file was created
            let fileExists = fileManager.fileExists(atPath: combinedURL.path)
            print("✅ [PersistentLogger] DIAGNOSTIC: File created successfully, exists: \(fileExists)")
            
            // Check file attributes
            if let attributes = try? fileManager.attributesOfItem(atPath: combinedURL.path) {
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("📊 [PersistentLogger] DIAGNOSTIC: File size: \(fileSize) bytes")
            }
            
            return combinedURL
        } catch {
            print("❌ [PersistentLogger] DIAGNOSTIC: Failed to create combined log file: \(error)")
            print("❌ [PersistentLogger] DIAGNOSTIC: Error details: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get log file size in human-readable format
    func getLogFileSize() -> String {
        guard let logURL = logFileURL else { return "Unknown" }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: logURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        } catch {
            return "Unknown"
        }
    }
    
    /// Clear all log files
    func clearAllLogs() {
        let logFiles = getAllLogFiles()
        
        for file in logFiles {
            do {
                try fileManager.removeItem(at: file)
                print("🗑️ [PersistentLogger] Deleted log file: \(file.lastPathComponent)")
            } catch {
                print("❌ [PersistentLogger] Failed to delete log file: \(error)")
            }
        }
        
        // Recreate the main log file
        setupLogFile()
    }
}

// MARK: - Log Level

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

// MARK: - Helper Extension

private extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}
