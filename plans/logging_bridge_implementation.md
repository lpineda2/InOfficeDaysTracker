# Logging Bridge Implementation Plan

## Problem Statement

Build 38 has `PersistentLogger` working, but no log entries appear because:
- All 267 `debugLog()` calls are wrapped in `#if DEBUG`
- `PersistentLogger` is never called anywhere in the codebase
- Two disconnected logging systems exist

## Solution: Bridge the Two Systems

### File to Modify
`InOfficeDaysTracker/Supporting Files/DebugLogger.swift`

### Current Code (Lines 13-28)
```swift
func debugLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("[\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
    #endif
}

func debugLog(_ emoji: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("\(emoji) [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
    #endif
}
```

### New Code (Replace lines 13-28)
```swift
func debugLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    // Console logging in debug builds for immediate feedback
    let fileName = (file as NSString).lastPathComponent
    print("[\(fileName):\(line)] \(function) - \(message)")
    #endif
    
    // File logging in all builds (for TestFlight export)
    PersistentLogger.shared.log(message, level: .info, file: file, function: function, line: line)
}

func debugLog(_ emoji: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    // Console logging in debug builds
    let fileName = (file as NSString).lastPathComponent
    print("\(emoji) [\(fileName):\(line)] \(function) - \(message)")
    #endif
    
    // File logging in all builds
    PersistentLogger.shared.log(emoji, message, file: file, function: function, line: line)
}
```

### Also Update File Header Comment (Lines 5-7)
```swift
//  Debug logging utilities that work in both DEBUG and TestFlight builds
//  - Console output in DEBUG builds for immediate feedback
//  - File logging in all builds for TestFlight troubleshooting
```

## Implementation Steps

1. **Modify DebugLogger.swift**
   - Update header comment
   - Add PersistentLogger calls to both debugLog() functions
   - Keep existing #if DEBUG console output

2. **Commit Changes**
   ```bash
   git add InOfficeDaysTracker/Supporting\ Files/DebugLogger.swift
   git commit -m "fix: bridge debugLog() to PersistentLogger for TestFlight logging"
   ```

3. **Deploy Build 39**
   ```bash
   ./scripts/release.sh --increment
   ```

## Expected Results

After deploying build 39:
- ✅ All 267 existing `debugLog()` calls will write to log files
- ✅ Console output still works in DEBUG builds
- ✅ File logging works in TestFlight builds
- ✅ Export logs will contain actual entries
- ✅ No code changes needed to 267 call sites

## Testing Checklist

1. **Local Testing (Debug Build)**
   - Run app in Xcode
   - Trigger location event
   - Verify console shows debugLog() output
   - Check Documents directory for log file with entries

2. **TestFlight Testing (Build 39)**
   - Install build 39 on physical device
   - Use app (enter/exit office)
   - Export logs via Settings
   - Verify log file contains entries like:
     ```
     ℹ️ [2026-06-18T...] [LocationService.swift:788] handleRegionEntry() - Entered office: Main Office
     ```

## Commit Message

```
fix: bridge debugLog() to PersistentLogger for TestFlight logging

Root cause: debugLog() was wrapped in #if DEBUG, disabling all 267 log 
calls in TestFlight. PersistentLogger existed but was never called.

Solution: Modified debugLog() to:
1. Print to console in DEBUG builds (existing behavior)
2. Write to PersistentLogger file in ALL builds (new behavior)

This bridges the two logging systems without requiring code changes to 
267 call sites.

Result: All existing debugLog() calls now write to exportable log files 
in TestFlight.
```
