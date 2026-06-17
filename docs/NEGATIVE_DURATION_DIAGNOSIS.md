# CRITICAL: Negative Duration Bug - June 17, 2026
**Issue:** Today's visit shows **-6.02 hours** duration  
**Current Time:** ~6:18 PM EDT (22:18 UTC)

## 📊 Current Data Analysis

### Today's Visit (6/17/26 Wednesday)
- **First Entry:** 7:52 AM
- **Last Exit:** 4:12 PM
- **Calculated Duration:** **-6.02 hours** ❌ INVALID
- **Expected Duration:** ~8.33 hours (8h 20m)

### Yesterday's Visit (6/16/26 Tuesday)  
- **First Entry:** 7:50 AM
- **Last Exit:** 11:59 PM
- **Duration:** 16.16 hours
- **Note:** 11:59 PM exit suggests auto-close of stale visit

## 🚨 Critical Issues Identified

### Issue 1: Negative Duration Calculation
**Severity:** CRITICAL  
**Impact:** Data corruption, invalid metrics, broken progress tracking

**Possible Causes:**
1. **Exit time before entry time** - Time zone or date boundary issue
2. **Multiple sessions with overlapping times** - Session management bug
3. **Duration calculation error** - Math error in duration computation
4. **Data corruption** - Invalid event data in visit.events array
5. **Calendar event interference** - Calendar data overwriting visit data

### Issue 2: Yesterday's Late Exit (11:59 PM)
**Severity:** HIGH  
**Impact:** Inflated duration, suggests exit detection failure

**Analysis:**
- 11:59 PM is the auto-close time for stale visits
- Indicates exit was never detected yesterday
- Visit was auto-closed at end of day
- This explains the 16.16 hour duration (unrealistic)

## 🔍 Root Cause Analysis

### Most Likely Cause: Session Management Bug
**Confidence:** 90%

The negative duration strongly suggests an issue with the **session/event management** in [`OfficeVisit.swift`](InOfficeDaysTracker/Models/OfficeVisit.swift):

```swift
// OfficeVisit has an events array
var events: [OfficeEvent]

// Duration is calculated by summing all events
var duration: TimeInterval? {
    guard !events.isEmpty else { return nil }
    guard events.allSatisfy({ $0.exitTime != nil }) else { return nil }
    return events.compactMap { $0.duration }.reduce(0, +)
}
```

**Hypothesis:** 
1. Today's visit has multiple events in the `events` array
2. One or more events have invalid entry/exit times
3. An event might have exit time BEFORE entry time
4. The sum of durations results in negative value

### Secondary Cause: Exit Detection Failure
**Confidence:** 85%

Yesterday's 11:59 PM exit confirms:
- Exit detection is NOT working reliably
- Visits are being auto-closed at end of day
- This is a recurring pattern (not just today)

## 🔬 Diagnostic Steps Needed

### Step 1: Inspect Today's Visit Events Array
We need to see the raw `events` array for today's visit:

```swift
// In AppData or export logic, log:
if let todayVisit = visits.first(where: { Calendar.current.isDateInToday($0.date) }) {
    PersistentLogger.shared.log("🔍 DEBUG", "Today's visit has \(todayVisit.events.count) events")
    for (index, event) in todayVisit.events.enumerated() {
        PersistentLogger.shared.log("🔍 DEBUG", "Event \(index): entry=\(event.entryTime), exit=\(event.exitTime?.description ?? "nil")")
        if let duration = event.duration {
            PersistentLogger.shared.log("🔍 DEBUG", "Event \(index) duration: \(duration) seconds")
        }
    }
}
```

### Step 2: Check for Time Zone Issues
```swift
// Log time zone information
PersistentLogger.shared.log("🔍 TZ", "System time zone: \(TimeZone.current.identifier)")
PersistentLogger.shared.log("🔍 TZ", "Entry time: \(visit.entryTime)")
PersistentLogger.shared.log("🔍 TZ", "Exit time: \(visit.exitTime?.description ?? "nil")")
```

### Step 3: Validate Duration Calculation
```swift
// In OfficeVisit.duration computed property, add validation:
var duration: TimeInterval? {
    guard !events.isEmpty else { return nil }
    guard events.allSatisfy({ $0.exitTime != nil }) else { return nil }
    
    let totalDuration = events.compactMap { $0.duration }.reduce(0, +)
    
    // DEFENSIVE: Log negative durations
    if totalDuration < 0 {
        PersistentLogger.shared.log("🚨 ERROR", "NEGATIVE DURATION DETECTED: \(totalDuration)")
        PersistentLogger.shared.log("🚨 ERROR", "Events count: \(events.count)")
        for (i, event) in events.enumerated() {
            PersistentLogger.shared.log("🚨 ERROR", "Event \(i): \(event.entryTime) -> \(event.exitTime?.description ?? "nil")")
        }
    }
    
    return totalDuration
}
```

## 🎯 Immediate Questions for User

1. **Current Status:** Are you currently in the office or have you left for the day?

2. **Today's Activity:** 
   - Did you enter around 7:52 AM? ✓
   - Did you leave around 4:12 PM? ✓
   - Did you leave and return multiple times today (lunch break, etc.)?

3. **Calendar Integration:**
   - Is calendar integration enabled?
   - What does today's calendar event show?
   - Does it show "Currently in office" or completed with times?

4. **Yesterday's Pattern:**
   - Did you actually stay until 11:59 PM yesterday? (Unlikely)
   - Or did the app fail to detect your exit?

5. **Recent Changes:**
   - You mentioned diagnostic logging was recently added
   - Can you share the actual persistent logs from today?
   - Look for logs with "🏢 START", "🏢 END", "🚪 EXIT" prefixes

## 🔧 Potential Fixes

### Fix 1: Add Duration Validation (Immediate)
```swift
// In OfficeVisit.duration
var duration: TimeInterval? {
    guard !events.isEmpty else { return nil }
    guard events.allSatisfy({ $0.exitTime != nil }) else { return nil }
    
    let totalDuration = events.compactMap { $0.duration }.reduce(0, +)
    
    // DEFENSIVE: Return nil for invalid durations
    guard totalDuration >= 0 && totalDuration.isFinite else {
        debugLog("⚠️", "[OfficeVisit] Invalid duration calculated: \(totalDuration)")
        return nil
    }
    
    return totalDuration
}
```

### Fix 2: Validate Event Times (Immediate)
```swift
// In OfficeEvent
var duration: TimeInterval? {
    guard let exitTime = exitTime else { return nil }
    let duration = exitTime.timeIntervalSince(entryTime)
    
    // DEFENSIVE: Validate duration is positive
    guard duration >= 0 else {
        debugLog("⚠️", "[OfficeEvent] Invalid event: exit before entry")
        debugLog("⚠️", "  Entry: \(entryTime)")
        debugLog("⚠️", "  Exit: \(exitTime)")
        return nil
    }
    
    return duration
}
```

### Fix 3: Clean Up Invalid Events (Data Repair)
```swift
// In AppData.init or data integrity check
func cleanupInvalidEvents() {
    for (index, visit) in visits.enumerated() {
        var cleanedVisit = visit
        let validEvents = visit.events.filter { event in
            guard let exitTime = event.exitTime else { return true } // Keep ongoing events
            return exitTime >= event.entryTime // Remove invalid events
        }
        
        if validEvents.count != visit.events.count {
            debugLog("🔧", "[Cleanup] Removed \(visit.events.count - validEvents.count) invalid events from \(visit.formattedDate)")
            cleanedVisit.events = validEvents
            visits[index] = cleanedVisit
        }
    }
    saveVisits()
}
```

### Fix 4: Fix Exit Detection (Root Cause)
Based on yesterday's 11:59 PM auto-close, we need to:
1. Verify geofence monitoring is active
2. Check exit grace period logic
3. Ensure background location updates work
4. Add fallback periodic location checks

## 📋 Next Steps

1. **User provides answers** to the 5 questions above
2. **User shares persistent logs** from today (if available)
3. **Implement diagnostic logging** from Step 1-3 above
4. **Apply immediate fixes** (Fix 1 & 2) to prevent data corruption
5. **Investigate exit detection** based on log findings
6. **Apply data repair** (Fix 3) to clean up existing invalid data

## 🚨 Critical Priority

The negative duration is a **data corruption bug** that needs immediate attention. Even if exit detection is fixed, we need to:
1. Prevent negative durations from being calculated
2. Clean up existing corrupted data
3. Add validation to prevent future corruption
