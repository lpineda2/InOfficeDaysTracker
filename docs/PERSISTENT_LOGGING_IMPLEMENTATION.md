# Persistent Logging Implementation Summary

## Overview

Added persistent file-based logging to the InOfficeDaysTracker app to enable troubleshooting without requiring immediate access to Console.app.

## Implementation Date
June 17, 2026

## Files Created

### 1. PersistentLogger.swift
**Location**: `InOfficeDaysTracker/Services/PersistentLogger.swift`

**Purpose**: Core logging service that writes debug logs to persistent files

**Key Features**:
- Singleton pattern for app-wide access
- Thread-safe logging using dedicated serial queue
- Automatic log rotation when file reaches 5MB
- Automatic cleanup of logs older than 7 days
- Support for multiple log levels (debug, info, warning, error, critical)
- Emoji prefixes for visual scanning
- ISO 8601 timestamps
- File and line number tracking

**Public API**:
```swift
// Log with level
PersistentLogger.shared.log("Message", level: .info)

// Log with emoji
PersistentLogger.shared.log("🚪", "Entry detected")

// Get current log file
PersistentLogger.shared.getCurrentLogFileURL()

// Get all log files
PersistentLogger.shared.getAllLogFiles()

// Create combined log
PersistentLogger.shared.createCombinedLogFile()

// Get log file size
PersistentLogger.shared.getLogFileSize()

// Clear all logs
PersistentLogger.shared.clearAllLogs()
```

### 2. LogExportView.swift
**Location**: `InOfficeDaysTracker/Views/LogExportView.swift`

**Purpose**: SwiftUI view for exporting and managing debug logs

**Features**:
- Display log file information (size, count, retention)
- Export current log file
- Export all logs combined into single file
- Clear all logs with confirmation
- Privacy information display
- Share sheet integration for easy export

**UI Sections**:
- Log Information (size, count, retention period)
- Export Options (current log, all logs combined)
- Management (clear all logs)
- What's Included (feature list)
- Privacy (what's NOT included)

### 3. Documentation

**PERSISTENT_LOGGING_GUIDE.md**
- Comprehensive user guide
- How to access and export logs
- What's included in logs
- Privacy and security information
- Use cases and examples
- FAQ section

**PERSISTENT_LOGGING_IMPLEMENTATION.md** (this file)
- Technical implementation details
- Files created and modified
- Integration points
- Testing checklist

## Files Modified

### 1. DebugLogger.swift
**Location**: `InOfficeDaysTracker/Supporting Files/DebugLogger.swift`

**Changes**:
- Updated `debugLog()` functions to call `PersistentLogger.shared.log()`
- Maintains backward compatibility with existing code
- Logs now go to both console AND persistent file
- No changes required to existing log calls throughout the app

**Before**:
```swift
func debugLog(_ message: String) {
    #if DEBUG
    print("[\(timestamp)] - \(message)")
    #endif
}
```

**After**:
```swift
func debugLog(_ message: String) {
    #if DEBUG
    print("[\(timestamp)] - \(message)")
    PersistentLogger.shared.log(message, level: .info)
    #endif
}
```

### 2. SettingsView.swift
**Location**: `InOfficeDaysTracker/Views/SettingsView.swift`

**Changes**:
- Added "Export Debug Logs" navigation link in Data Management section
- Only visible in DEBUG builds (wrapped in `#if DEBUG`)
- Updated footer text to mention debug logs

**Code Added**:
```swift
#if DEBUG
NavigationLink {
    LogExportView()
} label: {
    HStack {
        Image(systemName: "doc.text.magnifyingglass")
            .foregroundColor(.orange)
        Text("Export Debug Logs")
            .font(.body)
    }
}
#endif
```

### 3. HOW_TO_ACCESS_LOGS.md
**Location**: `docs/HOW_TO_ACCESS_LOGS.md`

**Changes**:
- Added new Method 1: Export Debug Logs (No Mac Required)
- Renumbered existing methods (Console.app is now Method 2)
- Added link to PERSISTENT_LOGGING_GUIDE.md
- Highlighted advantages of persistent logging

## Integration Points

### Automatic Integration
The persistent logging system automatically integrates with all existing `debugLog()` calls throughout the app:

**Affected Files** (no changes needed):
- `InOfficeDaysTracker/Services/LocationService.swift` - Entry/exit detection logs
- `InOfficeDaysTracker/Models/AppData.swift` - Visit management logs
- `InOfficeDaysTracker/Services/CalendarEventManager.swift` - Calendar integration logs
- All other files using `debugLog()`

### How It Works
1. Existing code calls `debugLog("message")` or `debugLog("🚪", "message")`
2. DebugLogger receives the call
3. DebugLogger prints to console (existing behavior)
4. DebugLogger forwards to PersistentLogger
5. PersistentLogger writes to file asynchronously
6. User can export logs anytime via Settings

## Build Configuration

### DEBUG Builds (TestFlight, Development)
- ✅ Persistent logging enabled
- ✅ Export Debug Logs visible in Settings
- ✅ Logs written to Documents directory
- ✅ Automatic rotation and cleanup

### RELEASE Builds (App Store)
- ❌ Persistent logging disabled
- ❌ Export Debug Logs hidden
- ❌ No log files created
- ✅ Privacy protected

## Storage Details

### File Locations
- **Directory**: App's Documents directory
- **Current log**: `InOfficeDaysTracker.log`
- **Archived logs**: `InOfficeDaysTracker_YYYY-MM-DD_HH-MM-SS.log`
- **Combined exports**: `InOfficeDaysTracker_Combined_YYYY-MM-DD_HH-MM-SS.log`

### Size Limits
- **Max file size**: 5MB per log file
- **Rotation**: Automatic when limit reached
- **Retention**: 7 days
- **Total storage**: Typically < 20MB

### Cleanup
- **Automatic**: On app launch
- **Manual**: Via "Clear All Logs" button
- **Criteria**: Files older than 7 days

## Testing Checklist

### Unit Tests Needed
- [ ] PersistentLogger initialization
- [ ] Log file creation
- [ ] Log writing (various levels)
- [ ] Log rotation at 5MB
- [ ] Cleanup of old logs
- [ ] Combined log file creation
- [ ] Thread safety (concurrent logging)

### Integration Tests Needed
- [ ] DebugLogger forwards to PersistentLogger
- [ ] Logs appear in both console and file
- [ ] Export current log via UI
- [ ] Export combined logs via UI
- [ ] Share sheet functionality
- [ ] Clear all logs functionality

### Manual Testing Checklist
- [ ] Install TestFlight build
- [ ] Verify "Export Debug Logs" appears in Settings
- [ ] Trigger entry detection (check logs)
- [ ] Trigger exit detection (check logs)
- [ ] Export current log
- [ ] Verify log file contains expected entries
- [ ] Export combined logs
- [ ] Verify combined file includes all logs
- [ ] Share log via email
- [ ] Share log via AirDrop
- [ ] Clear all logs
- [ ] Verify logs are deleted
- [ ] Verify new log file is created
- [ ] Test log rotation (generate >5MB of logs)
- [ ] Verify old logs are cleaned up after 7 days

### Privacy Testing
- [ ] Verify no exact GPS coordinates in logs
- [ ] Verify no personal information in logs
- [ ] Verify logging disabled in App Store build
- [ ] Verify Export Debug Logs hidden in App Store build

## Performance Considerations

### Impact
- **Minimal**: Logging happens on background queue
- **Non-blocking**: Main thread not affected
- **Async**: File I/O doesn't block app
- **Efficient**: Only writes when needed

### Optimization
- Serial queue prevents race conditions
- Buffered writes for efficiency
- Automatic rotation prevents large files
- Automatic cleanup prevents storage bloat

## Privacy & Security

### What's Logged
- ✅ Technical debugging information
- ✅ Relative distances (e.g., "250m from office")
- ✅ Timestamps
- ✅ Error messages
- ✅ State changes

### What's NOT Logged
- ❌ Exact GPS coordinates
- ❌ Personal information
- ❌ Calendar event content
- ❌ Sensitive user data

### Build Protection
- Only enabled in DEBUG builds
- Completely disabled in App Store builds
- No logs created in production
- Privacy protected by default

## User Benefits

### Before Persistent Logging
- ❌ Required Mac with Console.app
- ❌ Had to be connected during issue
- ❌ Logs didn't persist
- ❌ Difficult to share with developer

### After Persistent Logging
- ✅ No Mac required
- ✅ Can export anytime, even days later
- ✅ Logs persist for 7 days
- ✅ Easy to share via email/AirDrop

## Developer Benefits

### Troubleshooting
- Get logs from users without Mac
- Diagnose issues that happened days ago
- Complete history of events
- Easy to analyze in text editor

### Support
- Users can easily share logs
- Faster issue resolution
- Better understanding of edge cases
- Improved app quality

## Future Enhancements

### Potential Improvements
1. **In-app log viewer**: View logs directly in the app
2. **Log filtering**: Filter by level, component, or time range
3. **Log search**: Search for specific events or errors
4. **Automatic upload**: Option to automatically send logs to developer
5. **Log compression**: Compress old logs to save space
6. **Custom retention**: User-configurable retention period
7. **Log categories**: Separate logs by component (location, calendar, etc.)
8. **Performance metrics**: Track app performance in logs

### Not Planned
- Production logging (privacy concerns)
- Cloud storage (privacy concerns)
- Real-time streaming (battery concerns)

## Maintenance

### Regular Tasks
- Monitor log file sizes in TestFlight
- Review user-submitted logs for issues
- Update log messages as needed
- Adjust retention period if needed

### Known Limitations
- Only available in DEBUG builds
- 7-day retention (not configurable)
- No in-app log viewer
- No automatic upload to developer

## Conclusion

The persistent logging system provides a powerful troubleshooting tool that:
- Requires no Mac or special tools
- Allows export anytime, even days later
- Protects user privacy (DEBUG builds only)
- Helps diagnose geofence and calendar issues
- Improves support and app quality

This implementation solves the user's original problem: being able to troubleshoot issues without immediate access to Console.app.
