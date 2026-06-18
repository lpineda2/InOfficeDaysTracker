# Debug Diagnostics Section - Implementation Plan
**Location:** Settings → Help & Support  
**Purpose:** Provide easy access to diagnostic tools for troubleshooting

## 🎯 Overview

Add a new "Debug Diagnostics" section under Settings with three features:
1. Export Debug Logs
2. Copy App Diagnostics
3. Reset Debug Logs

## 📋 Current State Analysis

### Existing Implementation
- **Location:** [`SettingsView.swift:312-358`](InOfficeDaysTracker/Views/SettingsView.swift:312-358)
- **Current Section:** "Data Management"
- **Existing Features:**
  - Export Data (CSV) - Always visible
  - Export Debug Logs - `#if DEBUG` only
  - Reset All Data - Always visible

### Existing Components
- **PersistentLogger:** [`PersistentLogger.swift`](InOfficeDaysTracker/Services/PersistentLogger.swift) - Already implemented
- **LogExportView:** [`LogExportView.swift`](InOfficeDaysTracker/Views/LogExportView.swift) - Already implemented
- **Export functionality:** Working in DEBUG builds

## 🏗️ Architecture Design

### Option 1: Separate "Help & Support" Section (RECOMMENDED)
Create a new section specifically for support and diagnostics:

```
Settings
├── Goals
├── Office Locations
├── Tracking
├── Calendar
├── Notifications
├── Data Management
│   ├── Export Data (CSV)
│   └── Reset All Data
└── Help & Support (NEW)
    ├── Export Debug Logs
    ├── Copy App Diagnostics
    └── Reset Debug Logs
```

**Pros:**
- Clear separation of concerns
- Better organization
- Room for future support features (FAQ, Contact Support, etc.)
- Doesn't clutter Data Management section

**Cons:**
- Adds another section to Settings

### Option 2: Expand "Data Management" Section
Add debug features to existing "Data Management" section:

```
Data Management
├── Export Data (CSV)
├── Export Debug Logs (NEW - always visible)
├── Copy App Diagnostics (NEW)
├── Reset Debug Logs (NEW)
└── Reset All Data
```

**Pros:**
- No new section needed
- All data-related features in one place

**Cons:**
- Section becomes crowded
- Mixes user data with debug data
- Less clear organization

**RECOMMENDATION:** Option 1 - Create separate "Help & Support" section

## 📱 UI/UX Design

### Help & Support Section

```swift
private var helpAndSupportSection: some View {
    Section {
        // 1. Export Debug Logs
        NavigationLink {
            LogExportView()
        } label: {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Debug Logs")
                        .font(.body)
                    Text("Share detailed logs for troubleshooting")
                        .font(.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
        }
        
        // 2. Copy App Diagnostics
        Button {
            copyAppDiagnostics()
        } label: {
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Copy App Diagnostics")
                        .font(.body)
                    Text("Copy system info to clipboard")
                        .font(.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                }
                
                Spacer()
                
                if diagnosticsCopied {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                }
            }
        }
        
        // 3. Reset Debug Logs
        Button {
            showingResetLogsAlert = true
        } label: {
            HStack {
                Image(systemName: "trash.circle")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset Debug Logs")
                        .font(.body)
                    Text("Clear all diagnostic logs")
                        .font(.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
        }
    } header: {
        Text("Help & Support")
    } footer: {
        Text("Diagnostic tools for troubleshooting issues. Debug logs help identify problems with entry/exit detection.")
    }
}
```

### State Variables Needed

```swift
@State private var diagnosticsCopied = false
@State private var showingResetLogsAlert = false
@State private var showingDiagnosticsCopiedToast = false
```

## 🔧 Implementation Details

### Feature 1: Export Debug Logs

**Status:** ✅ Already implemented  
**Location:** [`LogExportView.swift`](InOfficeDaysTracker/Views/LogExportView.swift)

**Changes Needed:**
1. Remove `#if DEBUG` wrapper in SettingsView
2. Make always visible (not just DEBUG builds)
3. Move to new Help & Support section

**Rationale:** Users need access to logs in production builds for troubleshooting

### Feature 2: Copy App Diagnostics

**Status:** ❌ New feature  
**Purpose:** Quick way to copy system info for support requests

**Implementation:**

```swift
private func copyAppDiagnostics() {
    let diagnostics = generateAppDiagnostics()
    UIPasteboard.general.string = diagnostics
    
    // Show feedback
    diagnosticsCopied = true
    showingDiagnosticsCopiedToast = true
    
    // Reset after 2 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        diagnosticsCopied = false
    }
}

private func generateAppDiagnostics() -> String {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    let deviceModel = UIDevice.current.model
    let iosVersion = UIDevice.current.systemVersion
    let deviceName = UIDevice.current.name
    
    // Get current state
    let isInOffice = appData.isCurrentlyInOffice
    let hasCurrentVisit = appData.currentVisit != nil
    let visitsCount = appData.visits.count
    let validVisitsThisMonth = appData.getValidVisits(for: Date()).count
    
    // Get location permissions
    let locationAuth = CLLocationManager.authorizationStatus()
    let locationAuthString: String
    switch locationAuth {
    case .notDetermined: locationAuthString = "Not Determined"
    case .restricted: locationAuthString = "Restricted"
    case .denied: locationAuthString = "Denied"
    case .authorizedAlways: locationAuthString = "Always"
    case .authorizedWhenInUse: locationAuthString = "When In Use"
    @unknown default: locationAuthString = "Unknown"
    }
    
    // Get calendar permissions
    let calendarAuth = EKEventStore.authorizationStatus(for: .event)
    let calendarAuthString: String
    switch calendarAuth {
    case .notDetermined: calendarAuthString = "Not Determined"
    case .restricted: calendarAuthString = "Restricted"
    case .denied: calendarAuthString = "Denied"
    case .fullAccess: calendarAuthString = "Full Access"
    case .writeOnly: calendarAuthString = "Write Only"
    @unknown default: calendarAuthString = "Unknown"
    }
    
    // Get settings
    let calendarEnabled = appData.settings.calendarSettings.isEnabled
    let notificationsEnabled = appData.settings.notificationsEnabled
    let officeLocationsCount = appData.settings.officeLocations.count
    
    let diagnostics = """
    InOfficeDaysTracker Diagnostics
    ================================
    
    App Information:
    - Version: \(appVersion) (Build \(buildNumber))
    - Generated: \(ISO8601DateFormatter().string(from: Date()))
    
    Device Information:
    - Device: \(deviceName)
    - Model: \(deviceModel)
    - iOS Version: \(iosVersion)
    
    Permissions:
    - Location: \(locationAuthString)
    - Calendar: \(calendarAuthString)
    
    Current State:
    - Currently In Office: \(isInOffice)
    - Has Active Visit: \(hasCurrentVisit)
    - Total Visits: \(visitsCount)
    - Valid Visits This Month: \(validVisitsThisMonth)
    
    Settings:
    - Calendar Integration: \(calendarEnabled ? "Enabled" : "Disabled")
    - Notifications: \(notificationsEnabled ? "Enabled" : "Disabled")
    - Office Locations: \(officeLocationsCount)
    
    ================================
    """
    
    return diagnostics
}
```

**Toast Notification:**

```swift
.overlay(alignment: .top) {
    if showingDiagnosticsCopiedToast {
        Text("Diagnostics copied to clipboard")
            .font(.subheadline)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.top, 50)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showingDiagnosticsCopiedToast = false
                    }
                }
            }
    }
}
```

### Feature 3: Reset Debug Logs

**Status:** ❌ New feature  
**Purpose:** Clear all diagnostic logs to start fresh

**Implementation:**

```swift
// Alert
.alert("Reset Debug Logs", isPresented: $showingResetLogsAlert) {
    Button("Reset", role: .destructive) {
        resetDebugLogs()
    }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("This will permanently delete all diagnostic logs. This action cannot be undone.")
}

// Reset function
private func resetDebugLogs() {
    PersistentLogger.shared.clearLogs()
    
    // Show confirmation
    showingLogsResetToast = true
}
```

**Add to PersistentLogger:**

```swift
// In PersistentLogger.swift
func clearLogs() {
    logQueue.async { [weak self] in
        guard let self = self, let logURL = self.logFileURL else { return }
        
        do {
            // Delete existing log file
            if fileManager.fileExists(atPath: logURL.path) {
                try fileManager.removeItem(at: logURL)
            }
            
            // Create new empty log file
            fileManager.createFile(atPath: logURL.path, contents: nil, attributes: nil)
            
            // Write new header
            self.writeHeader()
            
            self.log("Debug logs cleared by user", level: .info)
        } catch {
            print("❌ [PersistentLogger] Failed to clear logs: \(error)")
        }
    }
}
```

## 📝 Implementation Steps

### Step 1: Update PersistentLogger
**File:** [`PersistentLogger.swift`](InOfficeDaysTracker/Services/PersistentLogger.swift)

- [ ] Add `clearLogs()` function
- [ ] Make logging available in RELEASE builds (not just DEBUG)
- [ ] Add privacy considerations (don't log sensitive data)

### Step 2: Create DiagnosticsHelper
**File:** `InOfficeDaysTracker/Services/DiagnosticsHelper.swift` (NEW)

```swift
import Foundation
import UIKit
import CoreLocation
import EventKit

struct DiagnosticsHelper {
    static func generateAppDiagnostics(appData: AppData) -> String {
        // Implementation from above
    }
    
    static func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}
```

### Step 3: Update SettingsView
**File:** [`SettingsView.swift`](InOfficeDaysTracker/Views/SettingsView.swift)

- [ ] Add state variables for new features
- [ ] Create `helpAndSupportSection` view
- [ ] Add section to Form (after dataSection)
- [ ] Implement `copyAppDiagnostics()` function
- [ ] Implement `resetDebugLogs()` function
- [ ] Add toast notifications
- [ ] Add reset logs alert
- [ ] Remove `#if DEBUG` from Export Debug Logs

### Step 4: Update Data Management Section
**File:** [`SettingsView.swift`](InOfficeDaysTracker/Views/SettingsView.swift:312-358)

- [ ] Remove "Export Debug Logs" from dataSection
- [ ] Update footer text (remove debug logs mention)
- [ ] Keep only: Export Data (CSV) and Reset All Data

### Step 5: Testing
- [ ] Test Export Debug Logs in production build
- [ ] Test Copy App Diagnostics
- [ ] Verify clipboard contains correct info
- [ ] Test Reset Debug Logs
- [ ] Verify logs are cleared and new header written
- [ ] Test toast notifications
- [ ] Test on different iOS versions

## 🎨 Visual Design

### Section Header
```
Help & Support
```

### Items
```
🔍 Export Debug Logs
   Share detailed logs for troubleshooting

📋 Copy App Diagnostics  
   Copy system info to clipboard                    ✓ (when copied)

🗑️ Reset Debug Logs
   Clear all diagnostic logs
```

### Footer
```
Diagnostic tools for troubleshooting issues. Debug logs help 
identify problems with entry/exit detection.
```

## 🔒 Privacy & Security Considerations

### What to Log
✅ **Safe to log:**
- Timestamps
- Event types (entry/exit)
- State changes (in office/not in office)
- Error messages
- System events
- Permission states
- App lifecycle events

❌ **Never log:**
- Exact coordinates (use "Office A", "Office B" instead)
- Full addresses
- User's name
- Calendar event titles/details
- Any personally identifiable information

### Production Logging
- Enable PersistentLogger in RELEASE builds
- Add privacy filters to prevent sensitive data logging
- Limit log retention to 7 days
- Limit log file size to 5MB
- Auto-rotate logs when size exceeded

## 📊 Success Metrics

### User Experience
- Users can export logs in < 3 taps
- Diagnostics copy in < 2 taps
- Clear feedback when actions complete
- No confusion about what each feature does

### Technical
- Logs contain enough detail for troubleshooting
- No sensitive data in logs
- Log file size stays under 5MB
- Export works reliably on all iOS versions

## 🚀 Future Enhancements

### Phase 2 (Future)
- **Contact Support:** Direct link to email support with diagnostics attached
- **FAQ Section:** Common questions and answers
- **Report Issue:** In-app issue reporting with auto-attached diagnostics
- **View Logs:** In-app log viewer (read-only)
- **Filter Logs:** Filter by date, level, or component

### Phase 3 (Future)
- **Remote Logging:** Optional opt-in to send logs to developer
- **Crash Reports:** Automatic crash reporting (with user consent)
- **Analytics:** Anonymous usage analytics (with user consent)

## 📋 Checklist

- [ ] Review and approve plan
- [ ] Create DiagnosticsHelper.swift
- [ ] Update PersistentLogger.swift
- [ ] Update SettingsView.swift
- [ ] Test all features
- [ ] Update documentation
- [ ] Create release notes
- [ ] Deploy to TestFlight
