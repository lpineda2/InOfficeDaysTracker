//
//  LogExportView.swift
//  InOfficeDaysTracker
//
//  View for exporting debug logs for troubleshooting
//

import SwiftUI

struct LogExportView: View {
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var logFileSize: String = "Calculating..."
    @State private var numberOfLogFiles: Int = 0
    @State private var showingClearConfirmation = false
    @State private var isGeneratingCombinedLog = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Debug Logs")
                        .font(.headline)
                    Text("Export logs to troubleshoot issues with office tracking, calendar integration, and geofence detection.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Log Information")) {
                HStack {
                    Text("Current Log Size")
                    Spacer()
                    Text(logFileSize)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Total Log Files")
                    Spacer()
                    Text("\(numberOfLogFiles)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Retention Period")
                    Spacer()
                    Text("7 days")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Export Options")) {
                Button(action: exportCurrentLog) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Current Log")
                        Spacer()
                        if isGeneratingCombinedLog {
                            ProgressView()
                        }
                    }
                }
                .disabled(isGeneratingCombinedLog)
                
                Button(action: exportAllLogs) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Export All Logs (Combined)")
                        Spacer()
                        if isGeneratingCombinedLog {
                            ProgressView()
                        }
                    }
                }
                .disabled(isGeneratingCombinedLog)
            }
            
            Section(header: Text("Management")) {
                Button(role: .destructive, action: {
                    showingClearConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Logs")
                    }
                }
            }
            
            Section(header: Text("What's Included")) {
                VStack(alignment: .leading, spacing: 12) {
                    LogInfoRow(icon: "location.circle", title: "Location Events", description: "Entry/exit detection, geofence status")
                    LogInfoRow(icon: "calendar", title: "Calendar Integration", description: "Event creation, updates, errors")
                    LogInfoRow(icon: "clock", title: "Timestamps", description: "Precise timing of all events")
                    LogInfoRow(icon: "exclamationmark.triangle", title: "Errors & Warnings", description: "Issues and diagnostic information")
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Privacy")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        Text("Logs only contain technical debugging information")
                            .font(.subheadline)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        Text("No personal information or exact GPS coordinates")
                            .font(.subheadline)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        Text("Only available in TestFlight/debug builds")
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }
            
            #if DEBUG
            Section(header: Text("Debug Info")) {
                Text("Logs are stored in the app's Documents directory and automatically cleaned up after 7 days. Maximum log file size is 5MB before rotation.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            #endif
        }
        .navigationTitle("Export Logs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateLogInfo()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(fileURL: shareURL, csvContent: "")
        }
        .alert("Clear All Logs?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearLogs()
            }
        } message: {
            Text("This will permanently delete all log files. This action cannot be undone.")
        }
    }
    
    private func updateLogInfo() {
        logFileSize = PersistentLogger.shared.getLogFileSize()
        numberOfLogFiles = PersistentLogger.shared.getAllLogFiles().count
    }
    
    private func exportCurrentLog() {
        guard let url = PersistentLogger.shared.getCurrentLogFileURL() else {
            print("❌ [LogExportView] DIAGNOSTIC: Current log URL is nil")
            return
        }
        
        print("📄 [LogExportView] DIAGNOSTIC: Exporting current log")
        print("📍 [LogExportView] DIAGNOSTIC: File URL: \(url.absoluteString)")
        print("📍 [LogExportView] DIAGNOSTIC: File path: \(url.path)")
        print("📍 [LogExportView] DIAGNOSTIC: File exists: \(FileManager.default.fileExists(atPath: url.path))")
        
        shareURL = url
        showingShareSheet = true
    }
    
    private func exportAllLogs() {
        isGeneratingCombinedLog = true
        
        print("🔄 [LogExportView] DIAGNOSTIC: Starting export all logs")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let combinedURL = PersistentLogger.shared.createCombinedLogFile()
            
            print("📦 [LogExportView] DIAGNOSTIC: Combined URL returned: \(combinedURL?.path ?? "nil")")
            
            DispatchQueue.main.async {
                isGeneratingCombinedLog = false
                if let url = combinedURL {
                    print("✅ [LogExportView] DIAGNOSTIC: Setting shareURL and showing sheet")
                    print("📍 [LogExportView] DIAGNOSTIC: File URL: \(url.absoluteString)")
                    print("📍 [LogExportView] DIAGNOSTIC: File path: \(url.path)")
                    print("📍 [LogExportView] DIAGNOSTIC: File exists: \(FileManager.default.fileExists(atPath: url.path))")
                    
                    shareURL = url
                    showingShareSheet = true
                } else {
                    print("❌ [LogExportView] DIAGNOSTIC: Combined URL is nil, not showing share sheet")
                }
            }
        }
    }
    
    private func clearLogs() {
        PersistentLogger.shared.clearAllLogs()
        updateLogInfo()
    }
}

struct LogInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 20))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationView {
        LogExportView()
    }
}
