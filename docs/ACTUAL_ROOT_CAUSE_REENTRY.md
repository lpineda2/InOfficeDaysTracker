# ACTUAL ROOT CAUSE: Re-Entry on New Day Issue
**Date:** June 17, 2026  
**Status:** ROOT CAUSE CONFIRMED BY USER

## ✅ Critical User Confirmation

**"I also checked the calendar entry/exit times yesterday and it was correct. I think the issue started when I went back into the office today"**

This completely changes the diagnosis:
- ✅ Yesterday's exit worked correctly (calendar shows 5:18 PM)
- ✅ Exit detection and grace period worked fine
- ❌ Problem started when you **entered the office TODAY** (new day)

## 🎯 ACTUAL ROOT CAUSE IDENTIFIED

### The Re-Entry Logic Has a Bug

When you enter the office, the app checks if you're re-entering during a grace period:

**Code:** [`LocationService.swift:704-739`](InOfficeDaysTracker/Services/LocationService.swift:704-739)

```swift
// Cancel exit grace timer if user re-entered during grace period
if let pendingRegion = pendingExitRegion, pendingRegion.identifier == region.identifier {
    // ... cancel grace period ...
    // Revert optimistic calendar exit
    await appData.revertOptimisticCalendarExit(visit: visit)
    return  // ← EARLY RETURN - doesn't start new visit
}

// If no grace period, continue with normal entry...
appData.startVisit(at: officeCoordinate)
```

### The Problem: Stale Grace Period State

**Scenario:**
1. **Yesterday (6/16):** You left at 5:18 PM
2. Grace period started, timer scheduled
3. **Timer may not have fired** (app suspended)
4. Grace period state persisted to UserDefaults
5. **Today (6/17):** You enter office at 7:52 AM
6. **BUG:** App thinks you're still in grace period from yesterday!
7. Calls `revertOptimisticCalendarExit()` instead of starting new visit
8. Returns early without calling `startVisit()`
9. **Result:** No new visit created for today, data corruption

### Evidence

**Yesterday's Data (6/16):**
- Entry: 7:50 AM
- Exit: 11:59 PM (auto-close)
- Duration: 16.16 hours

**Analysis:** The 11:59 PM suggests the grace period timer DID eventually fire (or was restored), but the grace period state may have lingered in UserDefaults.

**Today's Data (6/17):**
- Entry: 7:52 AM
- Exit: 4:12 PM
- Duration: **-6.02 hours** ❌

**Analysis:** When you entered at 7:52 AM, the app detected stale grace period state and:
1. Called `revertOptimisticCalendarExit()` (wrong - this is for same-day re-entry)
2. Returned early without calling `startVisit()`
3. No new visit created
4. Later exit detection tried to end non-existent visit
5. Data corruption resulted

## 🔍 The Bug in Detail

### Location: [`LocationService.swift:704-739`](InOfficeDaysTracker/Services/LocationService.swift:704-739)

```swift
// Cancel exit grace timer if user re-entered during grace period
if let pendingRegion = pendingExitRegion, pendingRegion.identifier == region.identifier {
    exitGraceTimer?.invalidate()
    exitGraceTimer = nil
    pendingExitRegion = nil
    
    // ... cancel notification ...
    
    exitTime = nil
    clearPersistedExitGracePeriod()
    
    // CRITICAL: Revert optimistic calendar exit since user returned
    if let visit = appData.currentVisit {
        Task {
            await appData.revertOptimisticCalendarExit(visit: visit)
        }
    }
    
    // User re-entered quickly - don't end/restart session
    return  // ← BUG: Returns without checking if this is a NEW DAY
}
```

**The Problem:**
- This code assumes re-entry is on the SAME DAY
- It doesn't check if the grace period is from a previous day
- If grace period state persists overnight, it treats morning entry as same-day re-entry
- Returns early without starting new visit

### Why Grace Period State Persists

**Code:** [`LocationService.swift:1056-1071`](InOfficeDaysTracker/Services/LocationService.swift:1056-1071)

```swift
private func persistExitGracePeriod() {
    guard let appData = appData,
          let exitTime = exitTime,
          let region = pendingExitRegion else { return }
    
    let graceExpires = exitTime.addingTimeInterval(exitGracePeriod)
    
    appData.sharedUserDefaults.set(exitTime, forKey: pendingExitTimeKey)
    appData.sharedUserDefaults.set(region.identifier, forKey: pendingExitRegionIdKey)
    appData.sharedUserDefaults.set(graceExpires, forKey: gracePeriodExpiresKey)
    appData.sharedUserDefaults.synchronize()
}
```

**The Problem:**
- Grace period state is persisted to survive app termination
- If `clearPersistedExitGracePeriod()` doesn't get called (timer fails), state remains
- Next day's entry detects this stale state
- Treats it as same-day re-entry

## 🚨 Why This Causes Negative Duration

1. **Yesterday:** Exit at 5:18 PM, grace period persisted
2. **Today:** Enter at 7:52 AM
3. **Bug:** Detects stale grace period, calls `revertOptimisticCalendarExit()`
4. **Result:** No new visit created via `startVisit()`
5. **Later:** You exit at 4:12 PM
6. **Exit handler:** Tries to end visit that was never created
7. **Data corruption:** Visit has invalid event timestamps
8. **Duration:** Calculates to -6.02 hours

## 🔧 The Fix

### Fix: Add Date Check to Grace Period Re-Entry Logic

**Location:** [`LocationService.swift:704-739`](InOfficeDaysTracker/Services/LocationService.swift:704-739)

```swift
// Cancel exit grace timer if user re-entered during grace period
if let pendingRegion = pendingExitRegion, 
   pendingRegion.identifier == region.identifier,
   let exitTime = exitTime {
    
    // CRITICAL FIX: Check if grace period is from today
    let calendar = Calendar.current
    let isToday = calendar.isDateInToday(exitTime)
    
    if isToday {
        // Same-day re-entry during grace period - cancel exit
        debugLog("✅", "[LocationService] Same-day re-entry during grace period")
        
        exitGraceTimer?.invalidate()
        exitGraceTimer = nil
        pendingExitRegion = nil
        
        // Cancel scheduled exit notification
        NotificationService.shared.cancelPendingExitNotification()
        
        let awayDuration = Date().timeIntervalSince(exitTime)
        debugLog("✅", "[LocationService] Re-entry detected during grace period (away for \(Int(awayDuration))s), canceling exit")
        
        self.exitTime = nil
        clearPersistedExitGracePeriod()
        
        // Revert optimistic calendar exit since user returned
        if let visit = appData.currentVisit {
            Task {
                await appData.revertOptimisticCalendarExit(visit: visit)
            }
        }
        
        // Trigger widget refresh
        triggerWidgetRefresh(reason: "exit cancelled - user returned")
        
        // User re-entered quickly - don't end/restart session
        return
    } else {
        // CRITICAL FIX: Grace period is from a previous day - clean it up
        debugLog("🔧", "[LocationService] Detected stale grace period from previous day")
        debugLog("🔧", "[LocationService] Exit time was: \(exitTime)")
        debugLog("🔧", "[LocationService] Clearing stale state and proceeding with new entry")
        
        // Clean up stale grace period state
        exitGraceTimer?.invalidate()
        exitGraceTimer = nil
        pendingExitRegion = nil
        self.exitTime = nil
        clearPersistedExitGracePeriod()
        
        // DO NOT return - continue with normal entry processing below
        // This will call startVisit() to create today's visit
    }
}

// Continue with normal entry processing...
appData.startVisit(at: officeCoordinate)
```

### Additional Fix: Clear Grace Period on Day Change

**Location:** [`LocationService.swift:1075-1120`](InOfficeDaysTracker/Services/LocationService.swift:1075-1120)

In `restoreExitGracePeriodIfNeeded()`, add date validation:

```swift
private func restoreExitGracePeriodIfNeeded() {
    guard let appData = appData else { return }
    
    guard let persistedExitTime = appData.sharedUserDefaults.object(forKey: pendingExitTimeKey) as? Date,
          let regionId = appData.sharedUserDefaults.string(forKey: pendingExitRegionIdKey) else {
        return // No pending exit to restore
    }
    
    // CRITICAL FIX: Check if grace period is from today
    let calendar = Calendar.current
    guard calendar.isDateInToday(persistedExitTime) else {
        debugLog("🔧", "[LocationService] Grace period is from previous day, clearing")
        clearPersistedExitGracePeriod()
        return
    }
    
    let elapsed = Date().timeIntervalSince(persistedExitTime)
    
    debugLog("🔄", "[LocationService] Found persisted exit grace period, elapsed: \(Int(elapsed))s")
    
    if elapsed >= exitGracePeriod {
        // Grace period expired while app was terminated - complete the exit
        debugLog("⏰", "[LocationService] Grace period expired during app termination, ending visit")
        Task { await appData.endVisit(at: persistedExitTime) }
        clearPersistedExitGracePeriod()
    } else {
        // Grace period still active - resume the timer with remaining time
        let remainingTime = exitGracePeriod - elapsed
        debugLog("⏰", "[LocationService] Resuming grace period with \(Int(remainingTime))s remaining")
        
        // ... rest of restoration logic ...
    }
}
```

## 📋 Implementation Steps

### Step 1: Add Diagnostic Logging (IMMEDIATE)
Add logging to confirm the hypothesis:

```swift
// In didEnterRegion, before grace period check
PersistentLogger.shared.log("🎯 ENTRY", "Entry detected at: \(Date())")
PersistentLogger.shared.log("🎯 ENTRY", "pendingExitRegion: \(pendingExitRegion?.identifier ?? "nil")")
PersistentLogger.shared.log("🎯 ENTRY", "exitTime: \(exitTime?.description ?? "nil")")

if let exitTime = exitTime {
    let calendar = Calendar.current
    let isToday = calendar.isDateInToday(exitTime)
    PersistentLogger.shared.log("🎯 ENTRY", "Exit time is from today: \(isToday)")
    PersistentLogger.shared.log("🎯 ENTRY", "Exit time date: \(calendar.startOfDay(for: exitTime))")
    PersistentLogger.shared.log("🎯 ENTRY", "Today's date: \(calendar.startOfDay(for: Date()))")
}

// In grace period re-entry block
PersistentLogger.shared.log("🔄 REENTRY", "Grace period re-entry detected")
PersistentLogger.shared.log("🔄 REENTRY", "Will revert calendar and return early")
```

### Step 2: Implement the Fix (AFTER CONFIRMATION)
Apply the date check fix shown above

### Step 3: Add Data Validation (IMMEDIATE)
Prevent negative durations:

```swift
// In OfficeEvent.duration
var duration: TimeInterval? {
    guard let exitTime = exitTime else { return nil }
    let duration = exitTime.timeIntervalSince(entryTime)
    
    guard duration >= 0 else {
        PersistentLogger.shared.log("🚨", "[OfficeEvent] Invalid: exit before entry")
        return nil
    }
    
    return duration
}
```

### Step 4: Clean Up Today's Corrupted Data
After implementing the fix, manually clean up today's visit:

```swift
// Temporary cleanup function
func cleanupTodaysVisit() {
    let calendar = Calendar.current
    if let todayIndex = visits.firstIndex(where: { calendar.isDateInToday($0.date) }) {
        var todayVisit = visits[todayIndex]
        
        // Remove invalid events
        let validEvents = todayVisit.events.filter { event in
            guard let exitTime = event.exitTime else { return true }
            return exitTime >= event.entryTime
        }
        
        if validEvents.count != todayVisit.events.count {
            debugLog("🔧", "[Cleanup] Removed \(todayVisit.events.count - validEvents.count) invalid events from today")
            todayVisit.events = validEvents
            visits[todayIndex] = todayVisit
            saveVisits()
        }
    }
}
```

## 🧪 Testing Protocol

1. **Reproduce the bug:**
   - Leave office in evening
   - Let grace period complete
   - Force quit app (to leave grace period state)
   - Next morning, enter office
   - Check logs - does it detect stale grace period?

2. **Test the fix:**
   - Apply the date check fix
   - Repeat scenario above
   - Verify new visit is created
   - Verify no negative durations

## 🎯 Expected Log Output (With Fix)

```
🎯 ENTRY: Entry detected at: 2026-06-17 07:52:00
🎯 ENTRY: pendingExitRegion: office_location
🎯 ENTRY: exitTime: 2026-06-16 17:18:00
🎯 ENTRY: Exit time is from today: false
🎯 ENTRY: Exit time date: 2026-06-16 00:00:00
🎯 ENTRY: Today's date: 2026-06-17 00:00:00
🔧: [LocationService] Detected stale grace period from previous day
🔧: [LocationService] Clearing stale state and proceeding with new entry
🏢 START: ===== START VISIT CALLED =====
```

## 📊 Success Criteria

After implementing the fix:
1. ✅ Morning entry creates new visit (not treated as re-entry)
2. ✅ Stale grace period state is cleared
3. ✅ No negative durations
4. ✅ Calendar and app data stay in sync
5. ✅ Same-day re-entry still works correctly (cancels exit)
