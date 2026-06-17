# Troubleshooting Guide: Calendar Entry & Exit Time Issues

## Your Reported Issues

1. **Today the app did not create a calendar entry**
2. **The app is updating the previous day calendar with an 11:59pm exit time**

---

## Issue 1: Missing Calendar Entry Today

### Root Cause Analysis

Based on code analysis, here are the **5 most likely sources** ranked by probability:

#### 1. **Entry Event Was Never Detected** (Most Likely)
- **Symptom**: No geofence entry event fired when you arrived at office
- **Why**: iOS geofencing can be unreliable, especially if:
  - Phone was in low power mode
  - Location services were restricted
  - You arrived outside the detection radius
  - GPS accuracy was poor

#### 2. **Calendar Integration Disabled**
- **Symptom**: Entry was detected but calendar event wasn't created
- **Why**: Calendar integration toggle is off in settings

#### 3. **Entry Was Rejected by Validation**
- **Symptom**: Entry detected but rejected by business logic
- **Why**: 
  - Outside office hours (with 1-hour flexibility)
  - Not a configured tracking day (e.g., weekend)
  - Already marked as in office

#### 4. **Calendar Permissions Revoked**
- **Symptom**: App tried to create event but iOS blocked it
- **Why**: Calendar access was denied in iOS Settings

#### 5. **App Was Not Running**
- **Symptom**: Geofence event queued but not processed
- **Why**: App was force-quit or iOS didn't wake it

### Diagnostic Steps

**Step 1: Check Console.app Logs**
```
Filter for: "ENTRY EVENT"
Look for:
- "===== ENTRY EVENT DETECTED ====="
- "Tracking day check passed"
- "Office hours check passed"
- "Calling appData.startVisit()"
- "[Calendar] Creating office event"
```

**Step 2: Check App Settings**
1. Open the app
2. Go to Settings → Calendar Integration
3. Verify:
   - ✅ Calendar integration is **enabled**
   - ✅ A calendar is **selected**
   - ✅ Event title is configured

**Step 3: Check iOS Calendar Permissions**
1. iOS Settings → Privacy & Security → Calendars
2. Find "InOfficeDays"
3. Verify permission is **Full Access** (not "Add Events Only")

**Step 4: Check Office Configuration**
1. Settings → Office Locations
2. Verify:
   - ✅ Office location is configured
   - ✅ Detection radius is reasonable (100-200m)
   - ✅ Address is correct

**Step 5: Check Tracking Days & Hours**
1. Settings → Policy Settings
2. Verify:
   - ✅ Today's weekday is in tracking days
   - ✅ Your arrival time is within office hours (±1 hour flexibility)

### What the Logs Should Show (Normal Entry)

```
🚪 [LocationService] ===== ENTRY EVENT DETECTED =====
🚪 [LocationService] Region: [office-id]
🚪 [LocationService] Current isCurrentlyInOffice state: false
✅ [LocationService] Tracking day check passed
✅ [LocationService] Office hours check passed
🎯 [LocationService] Calling appData.startVisit()...
[AppData] ===== START VISIT CALLED =====
[AppData] isCurrentlyInOffice set to: true
📅 [Calendar] Creating office event for [date]
✅ Settings updated and saved
```

### What to Look For If Entry Failed

**If you see:**
```
❌ [LocationService] ENTRY REJECTED: Not a tracking day
```
→ Today is not configured as a tracking day

**If you see:**
```
❌ [LocationService] ENTRY REJECTED: Outside office hours
```
→ You arrived too early or too late (outside flexible window)

**If you see:**
```
ℹ️ [LocationService] ENTRY SKIPPED: Already marked as in office
```
→ App thinks you're already in office (stale state)

**If you see nothing:**
→ Geofence entry event never fired (iOS issue)

---

## Issue 2: Previous Day Calendar Shows 11:59pm Exit Time

### Root Cause Analysis

This is **working as designed** but indicates an underlying problem. Here's what happened:

#### The 11:59pm Auto-Close Logic (By Design)

**Location in code**: [`AppData.swift:218-240`](InOfficeDaysTracker/Models/AppData.swift:218)

```swift
/// Auto-close a stale visit from a previous day by setting exit time to end of that day
private func autoCloseStaleVisit(_ staleVisit: OfficeVisit) {
    // Set exit time to 11:59 PM on the visit's date (end of that day)
    if let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: visit.date) {
        visit.endCurrentSession(at: endOfDay)
        // ... updates calendar event ...
    }
}
```

**When this triggers:**
- You open the app today
- App detects you have an active visit from yesterday
- App realizes the visit was never properly closed
- App auto-closes it at 11:59pm as a failsafe

**This is a symptom of**: **Exit detection failed yesterday**

### Why Exit Detection Failed Yesterday

Ranked by probability:

#### 1. **Geofence Exit Event Never Fired** (Most Likely)
- **Why**: iOS didn't detect you leaving the geofence
- **Common causes**:
  - Low power mode enabled
  - Poor GPS signal
  - You left very slowly (walking)
  - iOS region monitoring bug
  - App was force-quit

#### 2. **Exit Grace Period Expired in Background**
- **Why**: Exit was detected, but 5-minute grace period timer was suspended
- **What happened**: App detected exit, started grace period, then iOS suspended the app before timer completed
- **Result**: Exit processed when you opened app today

#### 3. **Exit Was Rejected by Validation**
- **Why**: Exit event fired but was rejected
- **Reason**: `isCurrentlyInOffice` was already `false` (state mismatch)

#### 4. **App Was Terminated During Exit**
- **Why**: App crashed or was killed during exit processing
- **Result**: Exit never completed, visit remained open

#### 5. **Periodic Check Missed the Exit**
- **Why**: Backup periodic check (every 5 minutes) also failed to detect exit
- **Reason**: App wasn't running in background

### Diagnostic Steps

**Step 1: Check Yesterday's Logs**
```
Filter for: "EXIT EVENT" and yesterday's date
Look for:
- "===== EXIT EVENT DETECTED ====="
- "Exit validation passed"
- "Starting exit grace period"
- "Grace period expired, confirming exit"
- "END VISIT CALLED"
```

**Step 2: Check for Auto-Close Logs**
```
Filter for: "autoCloseStaleVisit"
Look for:
- "Auto-closed stale visit from previous day"
- "Auto-closed and cleared stale visit"
- "Updated calendar event for auto-closed stale visit"
```

**Step 3: Check for Missed Exit Detection**
```
Filter for: "MISSED EXIT"
Look for:
- "🚨 MISSED EXIT DETECTED via periodic check!"
- "Geofence exit event was missed"
```

**Step 4: Check for Grace Period Issues**
```
Filter for: "grace period"
Look for:
- "Starting exit grace period"
- "Grace period expired in background"
- "Checking persisted exit grace period"
```

### What the Logs Should Show (Normal Exit)

```
🚪 [LocationService] ===== EXIT EVENT DETECTED =====
🚪 [LocationService] Current isCurrentlyInOffice state: true
✅ [LocationService] Exit validation passed
📍 [LocationService] Distance from Office: 250m (radius: 150m)
✅ [LocationService] Exit confirmed - user is outside detection radius
🔍 [LocationService] Starting exit grace period (300s)
📅 [AppData] Writing optimistic calendar exit at [time]
⏰ [LocationService] Grace period expired, confirming exit
[AppData] ===== END VISIT CALLED =====
[AppData] isCurrentlyInOffice set to: false
📅 [CalendarManager] Finalizing office event for [date]
```

### What to Look For If Exit Failed

**If you see:**
```
🚫 [LocationService] EXIT REJECTED - user was not marked as in office
```
→ State mismatch: app didn't think you were in office

**If you see:**
```
🚫 [LocationService] Exit rejected - user is still within [X]m of office
```
→ GPS showed you were still inside geofence (false exit)

**If you see nothing:**
→ Geofence exit event never fired (iOS issue)

**If you see grace period start but no completion:**
→ App was suspended/terminated before grace period completed

---

## Immediate Actions to Take

### 1. Collect Diagnostic Logs (Priority 1)

**Connect to Console.app NOW and reproduce the issue:**

1. **Connect iPhone to Mac**
2. **Open Console.app**
3. **Filter for**: `InOfficeDays`
4. **Clear existing logs** (Edit → Clear Display)
5. **Test entry detection**:
   - Leave office area (>200m away)
   - Wait 2 minutes
   - Return to office
   - Watch for "ENTRY EVENT DETECTED"
6. **Test exit detection**:
   - Leave office area (>200m away)
   - Watch for "EXIT EVENT DETECTED"
   - Wait 5+ minutes for grace period
   - Watch for "Grace period expired"
7. **Export logs**: Right-click → Export Selected Events

### 2. Verify Settings (Priority 2)

**In the app:**
- [ ] Settings → Calendar Integration → **Enabled**
- [ ] Settings → Calendar Integration → **Calendar selected**
- [ ] Settings → Office Locations → **Location configured**
- [ ] Settings → Policy Settings → **Today is a tracking day**
- [ ] Settings → Policy Settings → **Office hours include your arrival time**

**In iOS Settings:**
- [ ] Settings → Privacy & Security → Location Services → **Always**
- [ ] Settings → Privacy & Security → Location Services → **Precise Location ON**
- [ ] Settings → Privacy & Security → Calendars → **Full Access**
- [ ] Settings → Battery → **Low Power Mode OFF** (during testing)

### 3. Check Current State (Priority 3)

**Open the app and check:**
- [ ] Main screen shows correct "In Office" / "Not in Office" status
- [ ] History shows today's visit (if you're in office)
- [ ] Calendar app shows today's event (if you're in office)
- [ ] Yesterday's calendar event shows correct exit time (or 11:59pm if auto-closed)

---

## Understanding the 11:59pm Behavior

### Why 11:59pm Specifically?

The app uses 11:59pm as a **conservative estimate** when it can't determine the actual exit time:

**Pros:**
- ✅ Ensures visit is counted for the day
- ✅ Gives maximum credit for time in office
- ✅ Prevents data loss from missed exits

**Cons:**
- ❌ Inaccurate exit time in calendar
- ❌ Inflated duration calculation
- ❌ Indicates underlying geofence issue

### Is This a Bug?

**No, it's a failsafe**, but it reveals that:
1. Exit detection failed yesterday
2. You need to investigate why geofencing isn't working reliably

### How to Prevent 11:59pm Auto-Closes

**Fix the root cause:**
1. Ensure "Always" location permission
2. Keep precise location enabled
3. Don't force-quit the app
4. Disable low power mode during office hours
5. Keep app updated
6. Test geofence reliability with Console.app

---

## Advanced Diagnostics

### Check Geofence State

**In Console.app, filter for:**
```
"monitoredRegions"
"didDetermineState"
"Region state"
```

**You should see:**
- App monitoring your office region
- State changes when you enter/exit
- "inside" when at office, "outside" when away

### Check Background Execution

**In Console.app, filter for:**
```
"background"
"suspended"
"terminated"
```

**Look for:**
- App being suspended during exit grace period
- Background location updates being denied
- App termination during critical operations

### Check Widget Refresh

**In Console.app, filter for:**
```
"Widget"
"WidgetKit"
"timeline"
```

**Verify:**
- Widget refreshes when office status changes
- Timeline updates are not being throttled
- Widget shows correct status

---

## Common Scenarios & Solutions

### Scenario 1: "I arrived but no entry was detected"

**Diagnosis:**
```
Filter logs for: "ENTRY EVENT"
Expected: "===== ENTRY EVENT DETECTED ====="
Actual: Nothing
```

**Solution:**
1. Check you're within detection radius (Settings → Office Locations)
2. Verify "Always" location permission
3. Ensure precise location is enabled
4. Try increasing detection radius to 200m
5. Restart iPhone to reset location services

### Scenario 2: "Entry detected but no calendar event"

**Diagnosis:**
```
Filter logs for: "Calendar"
Expected: "Creating office event"
Actual: "Calendar integration disabled" or "No calendar selected"
```

**Solution:**
1. Enable calendar integration in app settings
2. Select a calendar
3. Grant calendar permissions in iOS Settings
4. Restart app

### Scenario 3: "I left but exit wasn't detected"

**Diagnosis:**
```
Filter logs for: "EXIT EVENT"
Expected: "===== EXIT EVENT DETECTED ====="
Actual: Nothing
```

**Solution:**
1. Ensure you're >200m from office (use Maps to check)
2. Wait 5-10 minutes for iOS to detect exit
3. Open app to trigger foreground verification
4. Check periodic location checks are running
5. Verify app isn't force-quit

### Scenario 4: "Exit detected but grace period never completed"

**Diagnosis:**
```
Filter logs for: "grace period"
Expected: "Grace period expired, confirming exit"
Actual: "Starting exit grace period" but no completion
```

**Solution:**
1. Keep app in background (don't force-quit)
2. Wait full 5 minutes for grace period
3. Open app to trigger foreground check
4. Check for "Grace period expired in background" on next launch

### Scenario 5: "Every day shows 11:59pm exit time"

**Diagnosis:**
```
Filter logs for: "autoCloseStaleVisit"
Expected: Should be rare
Actual: Happens every day
```

**Solution:**
1. **Critical**: Your geofence exit detection is completely broken
2. Check location permissions are "Always" (not "While Using")
3. Verify precise location is enabled
4. Check iOS Settings → Location Services → System Services → **Significant Locations** is ON
5. Consider resetting location & privacy settings
6. Contact developer with logs

---

## Next Steps

### If Entry Detection Is Failing:

1. **Collect logs** showing entry attempt
2. **Verify** you're within detection radius
3. **Check** all permissions are granted
4. **Test** by walking away and returning
5. **Share logs** with developer if issue persists

### If Exit Detection Is Failing:

1. **Collect logs** showing exit attempt
2. **Verify** you're outside detection radius
3. **Wait** 5+ minutes for grace period
4. **Check** app isn't force-quit
5. **Share logs** with developer if issue persists

### If Calendar Events Are Wrong:

1. **Check** calendar integration is enabled
2. **Verify** correct calendar is selected
3. **Review** calendar permissions
4. **Test** by manually adding a visit
5. **Share logs** with developer if issue persists

---

## Contact Developer

If issues persist after following this guide:

1. **Export logs** from Console.app covering:
   - Entry attempt
   - Exit attempt
   - Auto-close event
2. **Note** your settings:
   - Detection radius
   - Office hours
   - Tracking days
3. **Describe** the pattern:
   - Does it happen every day?
   - Only certain times?
   - After iOS updates?
4. **Share** via GitHub issue or email

---

## Technical Details

### Code References

- **Entry detection**: [`LocationService.swift:684-849`](InOfficeDaysTracker/Services/LocationService.swift:684)
- **Exit detection**: [`LocationService.swift:851-984`](InOfficeDaysTracker/Services/LocationService.swift:851)
- **Auto-close logic**: [`AppData.swift:218-240`](InOfficeDaysTracker/Models/AppData.swift:218)
- **Calendar integration**: [`CalendarEventManager.swift:19-100`](InOfficeDaysTracker/Services/CalendarEventManager.swift:19)
- **Grace period**: [`LocationService.swift:987-1052`](InOfficeDaysTracker/Services/LocationService.swift:987)

### Key Behaviors

1. **Entry requires**:
   - Inside geofence
   - Tracking day (weekday)
   - Office hours (±1 hour flexibility)
   - Not already in office

2. **Exit requires**:
   - Outside geofence (>radius + 10m buffer)
   - Currently marked as in office
   - 5-minute grace period completion

3. **Auto-close triggers**:
   - App launch with stale visit from previous day
   - Sets exit time to 11:59:59pm of visit date
   - Updates calendar event with exit time

4. **Calendar events**:
   - Created on entry (if enabled)
   - Updated during visit (duration changes)
   - Finalized on exit (with actual times)
   - Deleted if visit <1 hour

---

## Summary

**Issue 1 (No calendar entry today)**: Most likely entry event wasn't detected. Check logs for "ENTRY EVENT" and verify settings.

**Issue 2 (11:59pm exit time)**: This is a failsafe for missed exits. The real issue is exit detection failed yesterday. Check logs for "EXIT EVENT" and "autoCloseStaleVisit".

**Action**: Connect to Console.app, reproduce the issues, and collect logs showing what's happening (or not happening) during entry/exit.
