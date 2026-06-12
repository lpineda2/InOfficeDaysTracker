# Exit Detection Failure - Root Cause Analysis

## Problem Summary
Users report that the app fails to detect when they leave the office, defaulting to the 11:59 PM failsafe time instead of capturing the actual exit time.

**Reported Scenario**: User left office around 5-6 PM (within normal office hours), but app recorded exit at 11:59 PM.

---

## Root Cause Analysis

### **PRIMARY ISSUE: Exit Rejection Due to State Mismatch**

**Location**: [`LocationService.swift:904-909`](../InOfficeDaysTracker/Services/LocationService.swift:904)

```swift
guard appData.isCurrentlyInOffice else {
    debugLog("🚫", "[LocationService] Exit rejected - user was not marked as in office")
    debugLog("ℹ️", "[LocationService] This was likely a stale or duplicate exit event")
    NotificationService.shared.cancelPendingExitNotification()
    return  // ⚠️ EXIT DETECTION SILENTLY FAILS HERE
}
```

**The Problem**: When `didExitRegion` fires, the code checks if `isCurrentlyInOffice == true`. If it's `false`, the exit is **silently rejected** and never processed. The session remains open until the 11:59 PM failsafe closes it.

---

## Possible Scenarios Leading to State Mismatch

### **Scenario 1: Entry Never Detected (Most Likely)**
**Potential Causes**:

1. **iOS Geofence Didn't Fire on Entry**
   - iOS region monitoring is not 100% reliable
   - Can be delayed by minutes or fail entirely
   - Battery optimization may delay geofence events
   - Location accuracy issues in urban areas

2. **Entry Rejected by Time/Day Checks**
   - Entry requires: tracking day + office hours (±1 hour)
   - If user arrived outside this window, entry is rejected
   - Exit has NO such restriction, creating asymmetry

3. **App Was Killed/Suspended During Entry**
   - If app was not running when user entered geofence
   - iOS may not wake app for entry event
   - State never gets set to `isCurrentlyInOffice = true`

### **Scenario 2: State Lost After Entry**
**Potential Causes**:

1. **App Crash or Force Quit**
   - If app crashes after entry but before state is persisted
   - State is stored in UserDefaults but may not sync immediately

2. **UserDefaults Synchronization Failure**
   - `isCurrentlyInOffice` is persisted to shared UserDefaults
   - If sync fails, widget and app can have different states
   - App restart would load `false` from UserDefaults

3. **Race Condition on App Launch**
   - `loadCurrentStatus()` runs on app launch
   - Loads `isCurrentlyInOffice` from UserDefaults
   - If UserDefaults wasn't synced properly, loads `false`

### **Scenario 3: Exit Grace Period Interrupted**
**Potential Causes**:

1. **App Suspended During 5-Minute Grace Period**
   - Exit detected → grace period starts → app suspended
   - Timer doesn't fire while app is suspended
   - On next launch, `restoreExitGracePeriodIfNeeded()` should handle this
   - But if restoration fails, session stays open

2. **Grace Period Restoration Failure**
   - [`restoreExitGracePeriodIfNeeded()`](../InOfficeDaysTracker/Services/LocationService.swift:1020) checks for persisted exit
   - If persistence failed or was cleared, restoration won't happen
   - Session remains open indefinitely

---

## Why 11:59 PM Failsafe Triggers

**Location**: [`AppData.swift:216-238`](../InOfficeDaysTracker/Models/AppData.swift:216)

```swift
private func autoCloseStaleVisit(_ staleVisit: OfficeVisit) {
    // Set exit time to 11:59 PM on the visit's date (end of that day)
    if let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: visit.date) {
        visit.endCurrentSession(at: endOfDay)
        // ...
    }
}
```

This failsafe is triggered when:
1. App launches and finds a `currentVisit` from a previous day
2. Visit has no exit time (session still active)
3. Auto-closes it at 11:59 PM of that day

**This is working as designed** - it's a safety mechanism to prevent sessions from staying open forever. The real problem is that the actual exit wasn't detected.

---

## Diagnostic Logging Needed

To confirm which scenario is occurring, we need to add logging at these critical points:

### **1. Entry Detection Logging**
- Log when `didEnterRegion` fires
- Log if entry is rejected (tracking day, office hours, already in office)
- Log when `isCurrentlyInOffice` is set to `true`
- Log UserDefaults persistence confirmation

### **2. Exit Detection Logging**
- Log when `didExitRegion` fires
- Log the value of `isCurrentlyInOffice` when exit is detected
- Log if exit is rejected due to state mismatch
- Log distance verification results
- Log grace period start/completion

### **3. State Persistence Logging**
- Log when `isCurrentlyInOffice` is written to UserDefaults
- Log when it's read from UserDefaults on app launch
- Log UserDefaults synchronization calls
- Log any discrepancies between in-memory and persisted state

### **4. Grace Period Restoration Logging**
- Log when `restoreExitGracePeriodIfNeeded()` is called
- Log if a pending exit is found and restored
- Log if grace period expired during app termination

---

## Recommended Fix Strategy

### **Phase 1: Enhanced Logging (Immediate)**
Add comprehensive logging to identify which scenario is occurring in production.

### **Phase 2: State Validation (Short-term)**
1. Add state validation on exit detection
2. If `isCurrentlyInOffice == false` but `currentVisit != nil`, log warning
3. Consider processing exit anyway if there's an active visit

### **Phase 3: Entry Detection Improvements (Medium-term)**
1. Add background location verification to detect missed entries
2. Implement periodic location checks when near office
3. Add user notification if entry might have been missed

### **Phase 4: Failsafe Improvements (Long-term)**
1. Instead of 11:59 PM, use last known location timestamp
2. Add user prompt: "We noticed you were at the office yesterday. What time did you leave?"
3. Allow manual correction of exit times

---

## Next Steps

1. **Add diagnostic logging** to confirm root cause
2. **Test with logging enabled** to capture real-world scenarios
3. **Analyze logs** from affected users
4. **Implement targeted fix** based on confirmed root cause

---

## Questions for User

To help narrow down the issue:

1. **Do you see entry notifications when you arrive at the office?**
   - If no → Entry detection is failing
   - If yes → State is being lost after entry

2. **Does the app show you as "In Office" on the home screen when you're there?**
   - If no → Entry never processed
   - If yes → Exit detection is the problem

3. **Do you force-quit the app or does it crash?**
   - Could explain state loss

4. **What are your configured office hours?**
   - Verify time restrictions aren't blocking entry

5. **What days are configured as tracking days?**
   - Verify day-of-week isn't blocking entry
