# Enhanced Logging Implementation Summary
**Date:** June 17, 2026  
**Purpose:** Add diagnostic logging to troubleshoot stale grace period issue

## 🎯 Changes Made

### 1. Entry Detection Logging Enhancement
**File:** [`InOfficeDaysTracker/Services/LocationService.swift`](InOfficeDaysTracker/Services/LocationService.swift:703-720)

**Added after line 702:**
```swift
// DIAGNOSTIC: Log grace period state to detect stale state from previous day
debugLog("🔍", "[LocationService] Grace period state check:")
debugLog("🔍", "  pendingExitRegion: \(pendingExitRegion?.identifier ?? "nil")")
debugLog("🔍", "  exitTime: \(exitTime?.description ?? "nil")")
if let exitTime = exitTime {
    let calendar = Calendar.current
    let isToday = calendar.isDateInToday(exitTime)
    let exitDate = calendar.startOfDay(for: exitTime)
    let todayDate = calendar.startOfDay(for: Date())
    debugLog("🔍", "  exitTime is from today: \(isToday)")
    debugLog("🔍", "  exitTime date: \(exitDate)")
    debugLog("🔍", "  today's date: \(todayDate)")
    if !isToday {
        debugLog("⚠️", "[LocationService] WARNING: Grace period is from a PREVIOUS DAY - potential stale state bug")
    }
}
```

**Purpose:** Detect when grace period state is from a previous day, which would cause the stale grace period bug.

### 2. Grace Period Re-Entry Logging Enhancement
**File:** [`InOfficeDaysTracker/Services/LocationService.swift`](InOfficeDaysTracker/Services/LocationService.swift:715-717)

**Enhanced existing log at line 715:**
```swift
if let exitTime = exitTime {
    let awayDuration = Date().timeIntervalSince(exitTime)
    debugLog("✅", "[LocationService] Re-entry detected during grace period (away for \(Int(awayDuration))s), canceling exit")
    debugLog("✅", "[LocationService] Exit time was: \(exitTime)")  // ← ADDED
}
```

**Purpose:** Log the actual exit timestamp, not just duration.

### 3. Early Return Logging
**File:** [`InOfficeDaysTracker/Services/LocationService.swift`](InOfficeDaysTracker/Services/LocationService.swift:737-740)

**Added before return at line 738:**
```swift
// DIAGNOSTIC: Log early return to track when startVisit() is skipped
debugLog("⚠️", "[LocationService] EARLY RETURN: Skipping startVisit() due to grace period re-entry")
debugLog("⚠️", "[LocationService] Visit will NOT be created/resumed for this entry")
```

**Purpose:** Explicitly log when visit creation is skipped, making it obvious in logs.

### 4. Grace Period Restoration Logging Enhancement
**File:** [`InOfficeDaysTracker/Services/LocationService.swift`](InOfficeDaysTracker/Services/LocationService.swift:1083-1095)

**Enhanced restoration logging at line 1083:**
```swift
// DIAGNOSTIC: Log restoration details with date validation
let calendar = Calendar.current
let isToday = calendar.isDateInToday(persistedExitTime)
debugLog("🔄", "[LocationService] Found persisted exit grace period")
debugLog("🔄", "  Exit time: \(persistedExitTime)")
debugLog("🔄", "  Is from today: \(isToday)")
debugLog("🔄", "  Region: \(regionId)")

if !isToday {
    debugLog("⚠️", "[LocationService] WARNING: Grace period is from PREVIOUS DAY - should be cleared")
}

let elapsed = Date().timeIntervalSince(persistedExitTime)
debugLog("🔄", "[LocationService] Elapsed time: \(Int(elapsed))s")
```

**Purpose:** Detect when grace period restoration is restoring stale state from previous day.

### 5. Event Duration Validation
**File:** [`InOfficeDaysTracker/Models/OfficeVisit.swift`](InOfficeDaysTracker/Models/OfficeVisit.swift:16-28)

**Enhanced OfficeEvent.duration at line 16:**
```swift
var duration: TimeInterval? {
    guard let exitTime = exitTime else { return nil }
    let duration = exitTime.timeIntervalSince(entryTime)
    
    // DEFENSIVE: Validate duration is positive
    guard duration >= 0 else {
        debugLog("🚨", "[OfficeEvent] INVALID EVENT: Exit time before entry time")
        debugLog("🚨", "  Entry: \(entryTime)")
        debugLog("🚨", "  Exit: \(exitTime)")
        debugLog("🚨", "  Duration: \(duration) seconds")
        return nil
    }
    
    return duration
}
```

**Purpose:** Detect and log invalid events where exit time is before entry time, preventing negative durations.

### 6. Visit Duration Validation
**File:** [`InOfficeDaysTracker/Models/OfficeVisit.swift`](InOfficeDaysTracker/Models/OfficeVisit.swift:40-63)

**Enhanced OfficeVisit.duration at line 40:**
```swift
var duration: TimeInterval? {
    guard !events.isEmpty else { return nil }
    
    // If session is still active (last event has no exit time), return nil
    guard events.allSatisfy({ $0.exitTime != nil }) else { return nil }
    
    // Calculate total duration across all events
    let totalDuration = events.compactMap { $0.duration }.reduce(0, +)
    
    // DEFENSIVE: Validate total duration is positive and finite
    guard totalDuration >= 0 && totalDuration.isFinite else {
        debugLog("🚨", "[OfficeVisit] INVALID TOTAL DURATION: \(totalDuration) seconds")
        debugLog("🚨", "  Visit date: \(date)")
        debugLog("🚨", "  Events count: \(events.count)")
        for (i, event) in events.enumerated() {
            debugLog("🚨", "  Event \(i): \(event.entryTime) -> \(event.exitTime?.description ?? "nil")")
            if let eventDuration = event.duration {
                debugLog("🚨", "    Duration: \(eventDuration) seconds")
            }
        }
        return nil
    }
    
    return totalDuration
}
```

**Purpose:** Detect and log invalid total durations, providing detailed event information for debugging.

## 📊 Expected Log Output

### Normal Entry (No Grace Period)
```
🚪: [LocationService] ===== ENTRY EVENT DETECTED =====
🚪: [LocationService] Time: 2026-06-18 07:50:00
🔍: [LocationService] Grace period state check:
🔍:   pendingExitRegion: nil
🔍:   exitTime: nil
🏢: [AppData] ===== START VISIT CALLED =====
```

### Same-Day Re-Entry (Valid Grace Period)
```
🚪: [LocationService] ===== ENTRY EVENT DETECTED =====
🚪: [LocationService] Time: 2026-06-17 15:45:00
🔍: [LocationService] Grace period state check:
🔍:   pendingExitRegion: office_location
🔍:   exitTime: 2026-06-17 15:40:00
🔍:   exitTime is from today: true
🔍:   exitTime date: 2026-06-17 00:00:00
🔍:   today's date: 2026-06-17 00:00:00
✅: [LocationService] Re-entry detected during grace period (away for 300s)
✅: [LocationService] Exit time was: 2026-06-17 15:40:00
⚠️: [LocationService] EARLY RETURN: Skipping startVisit() due to grace period re-entry
⚠️: [LocationService] Visit will NOT be created/resumed for this entry
```

### Next-Day Entry (STALE Grace Period - BUG)
```
🚪: [LocationService] ===== ENTRY EVENT DETECTED =====
🚪: [LocationService] Time: 2026-06-18 07:50:00
🔍: [LocationService] Grace period state check:
🔍:   pendingExitRegion: office_location
🔍:   exitTime: 2026-06-17 16:12:00
🔍:   exitTime is from today: false  ← DETECTS STALE STATE
🔍:   exitTime date: 2026-06-17 00:00:00
🔍:   today's date: 2026-06-18 00:00:00
⚠️: [LocationService] WARNING: Grace period is from a PREVIOUS DAY - potential stale state bug
✅: [LocationService] Re-entry detected during grace period (away for 56280s)
✅: [LocationService] Exit time was: 2026-06-17 16:12:00
⚠️: [LocationService] EARLY RETURN: Skipping startVisit() due to grace period re-entry
⚠️: [LocationService] Visit will NOT be created/resumed for this entry
```

### Invalid Event Detection
```
🚨: [OfficeEvent] INVALID EVENT: Exit time before entry time
🚨:   Entry: 2026-06-17 07:52:00
🚨:   Exit: 2026-06-17 04:12:00
🚨:   Duration: -13080.0 seconds
```

### Invalid Total Duration Detection
```
🚨: [OfficeVisit] INVALID TOTAL DURATION: -21672.0 seconds
🚨:   Visit date: 2026-06-17 00:00:00
🚨:   Events count: 2
🚨:   Event 0: 2026-06-17 07:52:00 -> 2026-06-17 04:12:00
🚨:     Duration: nil
🚨:   Event 1: 2026-06-17 12:00:00 -> 2026-06-17 16:12:00
🚨:     Duration: 15120.0 seconds
```

## 🎯 Benefits

### 1. Immediate Detection
- Stale grace period state is detected and logged with WARNING
- Clear indication when visit creation is skipped
- Exact timestamps for debugging

### 2. Data Corruption Prevention
- Invalid events return nil duration instead of negative values
- Invalid total durations return nil with detailed logging
- CSV exports will show "N/A" instead of negative numbers

### 3. Root Cause Identification
- Logs clearly show if grace period is from previous day
- Logs show exact exit time and date comparison
- Logs show when early return prevents visit creation

### 4. Troubleshooting Efficiency
- All critical decision points are logged
- Date validation is explicit
- Event-level details available when corruption occurs

## 📋 Next Steps

### Tomorrow Morning Test
1. Enter office as normal
2. Check persistent logs
3. Look for these key indicators:
   - `🔍: exitTime is from today: false` ← Confirms stale state
   - `⚠️: WARNING: Grace period is from a PREVIOUS DAY` ← Confirms bug
   - `⚠️: EARLY RETURN: Skipping startVisit()` ← Confirms visit not created

### If Bug is Confirmed
1. Implement the fix from [`docs/ACTUAL_ROOT_CAUSE_REENTRY.md`](docs/ACTUAL_ROOT_CAUSE_REENTRY.md)
2. Add date validation to grace period re-entry check
3. Clear stale grace period state instead of treating as re-entry

### If Bug is NOT Confirmed
1. Review logs for other patterns
2. Check for invalid event timestamps
3. Investigate other potential causes

## 🔧 Files Modified

1. **InOfficeDaysTracker/Services/LocationService.swift**
   - Added grace period state logging (3 locations)
   - Added early return logging
   - Enhanced grace period restoration logging

2. **InOfficeDaysTracker/Models/OfficeVisit.swift**
   - Added event duration validation
   - Added visit duration validation
   - Added detailed error logging for invalid data

## ✅ Validation

All logging uses existing `debugLog()` function, which:
- Automatically routes to PersistentLogger if configured
- Works in both DEBUG and RELEASE builds
- Provides consistent formatting
- Can be exported via LogExportView

No new dependencies or infrastructure required.
