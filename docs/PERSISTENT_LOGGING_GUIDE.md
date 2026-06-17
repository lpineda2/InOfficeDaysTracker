# Persistent Logging Guide

## Overview

The app now includes persistent file-based logging that allows you to export debug logs for troubleshooting, even when you can't connect to Console.app immediately.

## Features

### Automatic Logging
- **All debug logs are automatically written to a file** in the app's Documents directory
- Logs include timestamps, file names, line numbers, and function names
- Both console output and file logging happen simultaneously
- Only active in DEBUG builds (TestFlight and development)

### Log Management
- **Automatic rotation**: When log file reaches 5MB, it's archived with a timestamp
- **Automatic cleanup**: Logs older than 7 days are automatically deleted
- **Multiple log files**: Keeps current log plus archived logs for the past week

### Export Options
- **Export Current Log**: Share the active log file
- **Export All Logs (Combined)**: Combines all log files into a single file for easy sharing
- **Share via**: Email, Messages, AirDrop, Files app, or any sharing method

## How to Access

### In the App

1. Open the app
2. Go to **Settings** tab
3. Scroll to **Data Management** section
4. Tap **Export Debug Logs** (only visible in TestFlight/debug builds)

### Export Options

**Export Current Log**
- Exports the active log file
- Best for recent issues (today's events)
- Smaller file size

**Export All Logs (Combined)**
- Combines all log files from the past 7 days
- Best for issues that happened over multiple days
- Larger file size but complete history

## What's Included in Logs

### Location Events
- Entry detection: When you arrive at office
- Exit detection: When you leave office
- Geofence state changes
- Distance calculations
- GPS accuracy information

### Calendar Integration
- Event creation attempts
- Event updates
- Calendar permission status
- Errors and failures

### Timing Information
- Precise timestamps for all events
- Grace period tracking
- Timer events
- Background/foreground transitions

### Errors & Warnings
- Permission issues
- Geofence failures
- State mismatches
- Validation failures

### System Information
- Device model
- iOS version
- App version and build number
- Location authorization status

## Privacy & Security

### What's NOT Included
- ❌ No exact GPS coordinates (only distances)
- ❌ No personal information
- ❌ No calendar event content
- ❌ No sensitive user data

### What IS Included
- ✅ Technical debugging information
- ✅ Relative distances (e.g., "250m from office")
- ✅ Timestamps
- ✅ Error messages
- ✅ State changes

### Production Builds
- Logging is **completely disabled** in App Store builds
- Only active in TestFlight and development builds
- Protects user privacy in production

## Use Cases

### Troubleshooting Entry Detection Issues

**Scenario**: App didn't detect when you arrived at office

**Steps**:
1. After the issue occurs, open the app
2. Go to Settings → Export Debug Logs
3. Tap "Export Current Log"
4. Share the log file
5. Search the log for:
   - `ENTRY EVENT` - Should show entry detection
   - `Tracking day check` - Verifies it's a tracking day
   - `Office hours check` - Verifies you're within office hours
   - `startVisit()` - Confirms visit was started

**What to look for**:
- If you see "ENTRY EVENT DETECTED" → Entry was detected, check calendar integration
- If you see "ENTRY REJECTED" → Check why (tracking day, office hours, etc.)
- If you see nothing → Geofence didn't fire (iOS issue)

### Troubleshooting Exit Detection Issues

**Scenario**: App didn't detect when you left office, or shows 11:59pm exit time

**Steps**:
1. After the issue occurs (or next day), open the app
2. Go to Settings → Export Debug Logs
3. Tap "Export All Logs (Combined)" to get yesterday's logs
4. Share the log file
5. Search the log for:
   - `EXIT EVENT` - Should show exit detection
   - `grace period` - Shows if exit started but didn't complete
   - `autoCloseStaleVisit` - Shows if failsafe triggered
   - `endVisit()` - Confirms visit was ended

**What to look for**:
- If you see "EXIT EVENT DETECTED" → Exit was detected, check if grace period completed
- If you see "EXIT REJECTED" → Check why (not marked as in office, still within radius)
- If you see "autoCloseStaleVisit" → Exit was missed, visit auto-closed at 11:59pm
- If you see nothing → Geofence exit didn't fire (iOS issue)

### Troubleshooting Calendar Integration

**Scenario**: Calendar events not being created or updated

**Steps**:
1. After the issue occurs, open the app
2. Go to Settings → Export Debug Logs
3. Tap "Export Current Log"
4. Share the log file
5. Search the log for:
   - `Calendar` - All calendar-related operations
   - `Creating office event` - Event creation attempts
   - `Finalizing office event` - Event completion
   - `Calendar integration disabled` - Integration status

**What to look for**:
- If you see "Calendar integration disabled" → Enable in settings
- If you see "No calendar selected" → Select a calendar in settings
- If you see "Failed to create" → Check calendar permissions
- If you see nothing → Entry/exit wasn't detected

## Log File Format

### File Naming
- Current log: `InOfficeDaysTracker.log`
- Archived logs: `InOfficeDaysTracker_YYYY-MM-DD_HH-MM-SS.log`
- Combined export: `InOfficeDaysTracker_Combined_YYYY-MM-DD_HH-MM-SS.log`

### Log Entry Format
```
🚪 [2026-06-17T14:30:45Z] [LocationService.swift:694] handleRegionEntry(_:) - ===== ENTRY EVENT DETECTED =====
```

**Components**:
- `🚪` - Emoji for visual scanning (varies by log type)
- `[2026-06-17T14:30:45Z]` - ISO 8601 timestamp (UTC)
- `[LocationService.swift:694]` - Source file and line number
- `handleRegionEntry(_:)` - Function name
- `===== ENTRY EVENT DETECTED =====` - Log message

### Common Emojis
- 🚪 - Entry/Exit events
- 📅 - Calendar operations
- 🔍 - Verification/Diagnostic checks
- ✅ - Success/Check passed
- ❌ - Error/Check failed
- ⚠️ - Warning
- 🔄 - Timer/Periodic action
- 📍 - Location information
- 🚨 - Alert/Critical event

## Sharing Logs with Developer

### Via Email
1. Export logs (current or combined)
2. Choose "Mail" from share sheet
3. Send to developer email
4. Include description of the issue

### Via GitHub Issue
1. Export logs (current or combined)
2. Save to Files app
3. Create GitHub issue
4. Attach log file
5. Describe the issue and when it occurred

### Via Messages/AirDrop
1. Export logs
2. Choose sharing method
3. Send to developer
4. Include context about the issue

## Managing Logs

### View Log Information
- **Current Log Size**: Shows size of active log file
- **Total Log Files**: Number of log files (current + archived)
- **Retention Period**: 7 days (automatic cleanup)

### Clear All Logs
1. Go to Settings → Export Debug Logs
2. Scroll to "Management" section
3. Tap "Clear All Logs"
4. Confirm deletion

**Note**: This permanently deletes all log files. Use this if:
- You want to start fresh
- Logs are taking up too much space
- You've already exported what you need

### Automatic Cleanup
- Logs older than 7 days are automatically deleted
- Happens when app launches
- No user action required

## Technical Details

### Storage Location
- **Directory**: App's Documents directory
- **Path**: `~/Documents/InOfficeDaysTracker.log`
- **Accessible**: Via Files app (if file sharing enabled)

### File Size Limits
- **Max file size**: 5MB per log file
- **Rotation**: Automatic when limit reached
- **Archives**: Kept for 7 days

### Performance Impact
- **Minimal**: Logging happens on background queue
- **Async**: Doesn't block main thread
- **Efficient**: Only writes when needed

### Thread Safety
- **Queue**: Dedicated serial queue for logging
- **Safe**: Multiple threads can log simultaneously
- **Ordered**: Log entries maintain chronological order

## Comparison with Console.app

### Persistent Logging (This Feature)
**Pros**:
- ✅ Logs persist even after app restart
- ✅ Can export anytime, even days later
- ✅ No Mac required
- ✅ Easy to share
- ✅ Automatic retention

**Cons**:
- ❌ Only available in TestFlight/debug builds
- ❌ Requires manual export
- ❌ Limited to 7 days history

### Console.app
**Pros**:
- ✅ Real-time monitoring
- ✅ Works with any build
- ✅ System-level logs included
- ✅ Advanced filtering

**Cons**:
- ❌ Requires Mac
- ❌ Must be connected during event
- ❌ Logs don't persist long
- ❌ More complex to use

### Recommendation
- **Use persistent logging** for issues you can't reproduce immediately
- **Use Console.app** for real-time debugging and testing
- **Use both** for comprehensive troubleshooting

## FAQ

### Q: Why don't I see "Export Debug Logs" in Settings?
**A**: This feature is only available in DEBUG builds (TestFlight and development). App Store builds don't include logging for privacy reasons.

### Q: How long are logs kept?
**A**: Logs are automatically deleted after 7 days. You can also manually clear them anytime.

### Q: Will logs fill up my phone storage?
**A**: No. Logs are limited to 5MB per file and automatically cleaned up after 7 days. Total storage is typically under 20MB.

### Q: Can I view logs directly in the app?
**A**: Not currently. You need to export and view them in a text editor or share them with the developer.

### Q: Do logs contain my location?
**A**: No exact GPS coordinates are logged. Only relative distances (e.g., "250m from office") are included.

### Q: What if I force-quit the app?
**A**: Logs are written immediately, so they're preserved even if the app is force-quit. However, force-quitting can prevent geofence events from being detected.

### Q: Can I disable logging?
**A**: Logging is automatically disabled in App Store builds. In TestFlight builds, it's always enabled to help with troubleshooting.

### Q: How do I know if logging is working?
**A**: Go to Settings → Export Debug Logs. If you see a file size greater than 0 bytes, logging is working.

## Examples

### Example 1: Successful Entry Detection
```
🚪 [2026-06-17T14:30:45Z] [LocationService.swift:694] handleRegionEntry(_:) - ===== ENTRY EVENT DETECTED =====
🚪 [2026-06-17T14:30:45Z] [LocationService.swift:696] handleRegionEntry(_:) - Region: office-id
🚪 [2026-06-17T14:30:45Z] [LocationService.swift:698] handleRegionEntry(_:) - Current isCurrentlyInOffice state: false
✅ [2026-06-17T14:30:45Z] [LocationService.swift:783] handleRegionEntry(_:) - Tracking day check passed
✅ [2026-06-17T14:30:45Z] [LocationService.swift:805] handleRegionEntry(_:) - Office hours check passed
🎯 [2026-06-17T14:30:45Z] [LocationService.swift:819] handleRegionEntry(_:) - Calling appData.startVisit()...
[AppData] ===== START VISIT CALLED =====
[AppData] isCurrentlyInOffice set to: true
📅 [Calendar] Creating office event for 2026-06-17
```

### Example 2: Entry Rejected (Not a Tracking Day)
```
🚪 [2026-06-17T14:30:45Z] [LocationService.swift:694] handleRegionEntry(_:) - ===== ENTRY EVENT DETECTED =====
🚪 [2026-06-17T14:30:45Z] [LocationService.swift:696] handleRegionEntry(_:) - Region: office-id
❌ [2026-06-17T14:30:45Z] [LocationService.swift:780] handleRegionEntry(_:) - ENTRY REJECTED: Not a tracking day (weekday=1, tracking days=[2, 3, 4, 5, 6])
```

### Example 3: Exit with Grace Period
```
🚪 [2026-06-17T18:30:45Z] [LocationService.swift:859] didExitRegion(_:) - ===== EXIT EVENT DETECTED =====
✅ [2026-06-17T18:30:45Z] [LocationService.swift:961] didExitRegion(_:) - Exit validation passed
📍 [2026-06-17T18:30:45Z] [LocationService.swift:946] didExitRegion(_:) - Distance from Office: 250m (radius: 150m)
✅ [2026-06-17T18:30:45Z] [LocationService.swift:974] didExitRegion(_:) - Exit confirmed - user is outside detection radius
🔍 [2026-06-17T18:30:45Z] [LocationService.swift:988] processConfirmedExit(office:region:appData:) - Starting exit grace period (300s)
📅 [2026-06-17T18:30:45Z] [AppData.swift:1191] writeOptimisticCalendarExit(at:) - Writing optimistic calendar exit at 2026-06-17T18:30:45Z
⏰ [2026-06-17T18:35:45Z] [LocationService.swift:1024] processConfirmedExit(office:region:appData:) - Grace period expired, confirming exit
[AppData] ===== END VISIT CALLED =====
[AppData] isCurrentlyInOffice set to: false
📅 [CalendarManager] Finalizing office event for 2026-06-17
```

### Example 4: Auto-Close Stale Visit
```
[AppData] ===== LOADING STATE ON APP LAUNCH =====
[AppData] Loaded isCurrentlyInOffice from UserDefaults: true
[AppData] Restored current visit from: 2026-06-16T09:15:30Z
[AppData] Auto-closed and cleared stale visit from previous day
[AppData] Auto-closed stale visit with exit time: 2026-06-16T23:59:59Z
📅 [AppData] Updated calendar event for auto-closed stale visit
```

## Summary

Persistent logging provides a powerful troubleshooting tool that:
- Captures all debug information automatically
- Allows export anytime, even days later
- Requires no Mac or special tools
- Protects privacy (only in TestFlight builds)
- Helps diagnose geofence and calendar issues

Use it whenever you experience issues with office tracking, calendar integration, or exit detection that you can't immediately debug with Console.app.
