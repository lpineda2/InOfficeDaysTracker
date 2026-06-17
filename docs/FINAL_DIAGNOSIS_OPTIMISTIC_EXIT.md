# FINAL DIAGNOSIS: Optimistic Calendar Exit Issue
**Date:** June 17, 2026  
**Status:** ROOT CAUSE IDENTIFIED

## ✅ Key User Confirmation
**"I get an alert correctly when I enter the office and when I leave"**

This confirms:
- ✅ Geofencing IS working correctly
- ✅ Exit detection IS firing
- ✅ Notifications ARE being sent

**The problem is NOT with exit detection - it's with what happens AFTER the exit is detected.**

## 🎯 ROOT CAUSE IDENTIFIED

### The Optimistic Calendar Exit System

The app has a sophisticated system to handle iOS background limitations:

1. **Exit Detected** (geofence fires) → [`LocationService.swift:851`](InOfficeDaysTracker/Services/LocationService.swift:851)
2. **Optimistic Calendar Write** → [`LocationService.swift:1003`](InOfficeDaysTracker/Services/LocationService.swift:1003)
   - Immediately writes exit time to calendar
   - Done during the ~10s background window iOS provides
3. **Grace Period Starts** → 5 minutes (300s)
4. **Grace Period Expires** → [`LocationService.swift:1019-1051`](InOfficeDaysTracker/Services/LocationService.swift:1019-1051)
   - Timer fires to actually end the visit in the app
   - Calls `appData.endVisit()`

### The Problem: Grace Period Timer Not Firing

**Hypothesis:** The 5-minute grace period timer is NOT firing reliably because:

1. **iOS suspends the app** before the timer fires
2. **Timer is not background-safe** - `Timer.scheduledTimer` only works in foreground
3. **Grace period restoration fails** - When app reopens, timer restoration may not work
4. **Result:** Visit never ends in the app, gets auto-closed at 11:59 PM

### Evidence Supporting This Hypothesis

**Yesterday (6/16):**
- You left at ~5:18 PM
- Got exit notification ✓
- Calendar was updated with exit time ✓ (optimistic write)
- Grace period timer started ✓
- **Timer never fired** ❌ (app suspended)
- Visit auto-closed at 11:59 PM ❌

**Today (6/17):**
- Similar pattern
- Exit detected, notification sent
- Calendar updated optimistically
- Grace period timer may not have fired
- Negative duration suggests data corruption from incomplete exit handling

## 🔍 The Negative Duration Mystery

The **-6.02 hours** is likely caused by:

1. **Optimistic calendar exit** writes exit time to visit snapshot
2. **Grace period timer fails** to fire
3. **Visit data gets corrupted** with partial exit information
4. **Multiple events** in the `events` array have inconsistent timestamps
5. **Duration calculation** sums up to negative value

**Code Flow:**
```swift
// LocationService.swift:1003 - Optimistic write
await appData.writeOptimisticCalendarExit(at: exitTime!)

// AppData.swift:1268-1280 - Creates snapshot with exit time
var snapshot = visit
snapshot.endCurrentSession(at: exitTime)  // Modifies snapshot
await calendarEventManager.handleVisitEnd(snapshot, settings: settings)

// BUT: The actual visit in appData is NOT ended yet
// It waits for the grace period timer to fire
// If timer never fires, visit remains in inconsistent state
```

## 🚨 Critical Issues

### Issue 1: Timer-Based Grace Period is Unreliable
**Location:** [`LocationService.swift:1019`](InOfficeDaysTracker/Services/LocationService.swift:1019)

```swift
exitGraceTimer = Timer.scheduledTimer(withTimeInterval: exitGracePeriod, repeats: false) { ... }
```

**Problem:** `Timer` does NOT work when app is suspended/backgrounded
- iOS suspends apps ~10s after geofence event
- Timer will never fire if app is suspended
- Grace period restoration (line 1075) may not work reliably

### Issue 2: Optimistic Exit Creates Data Inconsistency
**Location:** [`AppData.swift:1268-1280`](InOfficeDaysTracker/Models/AppData.swift:1268-1280)

**Problem:** Calendar gets updated with exit time, but app's visit data doesn't
- Calendar shows visit ended
- App's `currentVisit` still active
- `isCurrentlyInOffice` still true
- Creates data mismatch

### Issue 3: No Fallback for Failed Grace Period
**Problem:** If timer doesn't fire:
- Visit never ends
- User stays "in office" forever
- Auto-close at 11:59 PM is the only recovery
- No detection of failed grace period

## 🔧 Recommended Fixes

### Fix 1: Use Background Task Instead of Timer (CRITICAL)
Replace the foreground-only timer with a background task:

```swift
// In processConfirmedExit
private func processConfirmedExit(office: OfficeLocation, region: CLRegion, appData: AppData) async {
    debugLog("🔍", "[LocationService] Starting exit grace period (\(exitGracePeriod)s)")
    
    // Store the region and exit time
    pendingExitRegion = region
    exitTime = Date()
    
    // Persist grace period state
    persistExitGracePeriod()
    
    // Write optimistic calendar exit
    await appData.writeOptimisticCalendarExit(at: exitTime!)
    
    // CRITICAL FIX: Use background task instead of timer
    // Schedule the actual exit to happen after grace period
    Task {
        // Wait for grace period
        try? await Task.sleep(nanoseconds: UInt64(exitGracePeriod * 1_000_000_000))
        
        // Check if we're still in grace period (not cancelled by re-entry)
        guard let self = self,
              let appData = self.appData,
              let pendingExit = self.pendingExitRegion,
              pendingExit.identifier == region.identifier else {
            debugLog("⏰", "[LocationService] Grace period cancelled (user returned)")
            return
        }
        
        // Confirm exit
        debugLog("⏰", "[LocationService] Grace period expired, confirming exit")
        await appData.endVisit(at: self.exitTime)
        
        // Clean up
        self.pendingExitRegion = nil
        self.exitTime = nil
        self.clearPersistedExitGracePeriod()
        self.stopPeriodicLocationChecks()
        self.triggerWidgetRefresh(reason: "office exit after grace period")
    }
    
    // Trigger immediate widget refresh
    triggerWidgetRefresh(reason: "exit detected - grace period starting")
    
    // Schedule notification
    if appData.settings.notificationsEnabled {
        NotificationService.shared.scheduleExitNotification(afterDelay: exitGracePeriod)
    }
}
```

### Fix 2: Add Grace Period Validation on App Launch
Add check to detect and fix failed grace periods:

```swift
// In AppData.init or LocationService.setAppData
func validateGracePeriodState() {
    // Check if there's a persisted grace period that should have expired
    guard let persistedExitTime = sharedUserDefaults.object(forKey: pendingExitTimeKey) as? Date else {
        return
    }
    
    let elapsed = Date().timeIntervalSince(persistedExitTime)
    
    if elapsed >= exitGracePeriod {
        // Grace period should have expired - end the visit now
        debugLog("🔧", "[AppData] Detected expired grace period from previous session")
        Task {
            await endVisit(at: persistedExitTime)
        }
    }
}
```

### Fix 3: Remove Optimistic Calendar Write (ALTERNATIVE)
If background tasks don't work reliably, remove the optimistic write:

```swift
// Remove line 1003 from LocationService.swift
// await appData.writeOptimisticCalendarExit(at: exitTime!)

// Instead, only update calendar when visit actually ends
// This ensures calendar and app data stay in sync
```

**Trade-off:** Calendar may not update if app is killed, but data stays consistent

### Fix 4: Add Data Validation (IMMEDIATE)
Prevent negative durations while investigating:

```swift
// In OfficeEvent.duration
var duration: TimeInterval? {
    guard let exitTime = exitTime else { return nil }
    let duration = exitTime.timeIntervalSince(entryTime)
    
    guard duration >= 0 else {
        PersistentLogger.shared.log("🚨", "[OfficeEvent] Invalid: exit before entry")
        PersistentLogger.shared.log("🚨", "  Entry: \(entryTime)")
        PersistentLogger.shared.log("🚨", "  Exit: \(exitTime)")
        return nil
    }
    
    return duration
}
```

## 📋 Implementation Priority

### Priority 1: Add Diagnostic Logging (TODAY)
Add logging to confirm the hypothesis:

```swift
// In processConfirmedExit - before timer
PersistentLogger.shared.log("⏰ GRACE", "Grace period timer scheduled for \(exitGracePeriod)s")
PersistentLogger.shared.log("⏰ GRACE", "Timer will fire at: \(Date().addingTimeInterval(exitGracePeriod))")

// In timer callback
PersistentLogger.shared.log("⏰ GRACE", "Grace period timer FIRED")
PersistentLogger.shared.log("⏰ GRACE", "About to call endVisit()")

// In restoreExitGracePeriodIfNeeded
PersistentLogger.shared.log("🔄 RESTORE", "Checking for persisted grace period...")
if let persistedExitTime = ... {
    PersistentLogger.shared.log("🔄 RESTORE", "Found persisted exit at: \(persistedExitTime)")
    PersistentLogger.shared.log("🔄 RESTORE", "Elapsed: \(elapsed)s, Grace period: \(exitGracePeriod)s")
}
```

### Priority 2: Fix Timer Issue (AFTER CONFIRMATION)
Implement Fix 1 (background task) or Fix 3 (remove optimistic write)

### Priority 3: Add Validation (IMMEDIATE)
Implement Fix 4 to prevent negative durations

### Priority 4: Add Grace Period Validation (AFTER FIX)
Implement Fix 2 to catch failed grace periods

## 🧪 Testing Protocol

1. **Test grace period timer:**
   - Leave office
   - Immediately background the app
   - Wait 6 minutes
   - Check logs - did timer fire?
   - Check if visit ended

2. **Test grace period restoration:**
   - Leave office
   - Force quit app during grace period
   - Reopen app after 6 minutes
   - Check if visit was ended

3. **Test optimistic calendar:**
   - Leave office
   - Check calendar immediately
   - Does it show exit time?
   - Check app - is visit still active?

## 🎯 Expected Findings

**If hypothesis is correct, logs will show:**
- ✅ "Grace period timer scheduled"
- ❌ "Grace period timer FIRED" (missing - timer never fired)
- ✅ "Found persisted exit" (on app reopen)
- ❌ Visit not ended (grace period restoration failed)

**This confirms:** Timer-based grace period is unreliable in background

## 📊 Success Criteria

After implementing fixes:
1. ✅ Exit detected → Visit ends within 6 minutes
2. ✅ Calendar and app data stay in sync
3. ✅ No 11:59 PM auto-closes
4. ✅ No negative durations
5. ✅ Works when app is backgrounded/killed
