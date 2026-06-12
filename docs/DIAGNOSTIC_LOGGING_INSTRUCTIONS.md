# Diagnostic Logging Instructions

## Overview
I've added comprehensive diagnostic logging to help identify why exit detection is failing. The logs will show exactly what's happening at each critical point in the entry/exit detection flow.

---

## What Was Added

### **1. Entry Detection Logging**
**Location**: [`LocationService.swift`](../InOfficeDaysTracker/Services/LocationService.swift)

Added logs for:
- ✅ When entry event is detected
- ✅ Current state before entry processing
- ✅ Tracking day validation (pass/fail)
- ✅ Office hours validation (pass/fail)
- ✅ Duplicate entry check
- ✅ State after `startVisit()` is called
- ✅ State persistence verification

### **2. Exit Detection Logging**
**Location**: [`LocationService.swift`](../InOfficeDaysTracker/Services/LocationService.swift)

Added logs for:
- ✅ When exit event is detected
- ✅ Current state before exit processing
- ✅ State mismatch detection (in-memory vs persisted)
- ✅ Exit rejection reason with detailed diagnostics
- ✅ Distance verification results

### **3. State Management Logging**
**Location**: [`AppData.swift`](../InOfficeDaysTracker/Models/AppData.swift)

Added logs for:
- ✅ When `startVisit()` is called
- ✅ State changes during visit start
- ✅ UserDefaults persistence verification
- ✅ When `endVisit()` is called
- ✅ State changes during visit end
- ✅ State loading on app launch

---

## How to Use These Logs

### **Step 1: Build and Deploy**
The diagnostic logging is already in the code. Deploy the updated build to TestFlight:

```bash
cd /Users/lpineda/Desktop/InOfficeDaysTracker
bundle exec fastlane deploy_testflight
```

### **Step 2: Reproduce the Issue**
1. Install the TestFlight build on your device
2. Connect your device to your Mac
3. Open **Console.app** on your Mac
4. Filter for your device and app name: `InOfficeDays`
5. Go to the office and watch for entry logs
6. Leave the office and watch for exit logs

### **Step 3: Capture the Logs**
Look for these key log markers:

#### **Entry Event:**
```
🚪 [LocationService] ===== ENTRY EVENT DETECTED =====
🚪 [LocationService] Region: [region-id]
🚪 [LocationService] Current isCurrentlyInOffice state: [true/false]
✅ [LocationService] Tracking day check passed
✅ [LocationService] Office hours check passed
✅ [LocationService] Not currently in office, proceeding with entry
🎯 [LocationService] Calling appData.startVisit()...
[AppData] ===== START VISIT CALLED =====
[AppData] isCurrentlyInOffice set to: true
[AppData] State persisted to UserDefaults: true
```

#### **Exit Event:**
```
🚪 [LocationService] ===== EXIT EVENT DETECTED =====
🚪 [LocationService] Region: [region-id]
🚪 [LocationService] Current isCurrentlyInOffice state: [true/false]
🚪 [LocationService] Persisted status in UserDefaults: [true/false]
✅ [LocationService] Exit validation passed - user is marked as in office
```

#### **Exit Rejection (THE PROBLEM):**
```
🚪 [LocationService] ===== EXIT EVENT DETECTED =====
🚪 [LocationService] Current isCurrentlyInOffice state: false
🚫 [LocationService] EXIT REJECTED - user was not marked as in office
🚫 [LocationService] Current visit: [visit-id or "none"]
🚫 [LocationService] This exit will NOT be processed - session will remain open until failsafe
```

---

## What to Look For

### **Scenario 1: Entry Never Detected**
**Symptoms:**
- No entry logs when you arrive at office
- Exit logs show `isCurrentlyInOffice: false`

**Indicates:**
- iOS geofence didn't fire
- App was not running/suspended
- Location services issue

### **Scenario 2: Entry Rejected**
**Symptoms:**
- Entry logs appear but show rejection
- `❌ ENTRY REJECTED: Not a tracking day` or
- `❌ ENTRY REJECTED: Outside office hours`

**Indicates:**
- Configuration issue with tracking days or office hours
- Timezone problem

### **Scenario 3: State Lost After Entry**
**Symptoms:**
- Entry logs show successful entry
- `isCurrentlyInOffice set to: true`
- Later, exit logs show `isCurrentlyInOffice: false`

**Indicates:**
- App crash or force quit
- UserDefaults synchronization failure
- State corruption

### **Scenario 4: State Mismatch**
**Symptoms:**
- Logs show: `⚠️ WARNING: State mismatch!`
- In-memory state differs from persisted state

**Indicates:**
- UserDefaults synchronization issue
- Race condition
- App group configuration problem

---

## Sharing Logs

### **Option 1: Console.app Export**
1. Open Console.app
2. Filter for `InOfficeDays`
3. Select relevant log entries
4. Right-click → Export Selected Events
5. Save as text file

### **Option 2: Device Logs via Xcode**
1. Connect device to Mac
2. Open Xcode → Window → Devices and Simulators
3. Select your device
4. Click "Open Console"
5. Filter for `InOfficeDays`
6. Copy relevant logs

### **Option 3: On-Device Logs**
The app uses `DebugLogger` which may write to a file. Check:
```swift
// Location: InOfficeDaysTracker/Supporting Files/DebugLogger.swift
```

---

## Next Steps After Capturing Logs

1. **Identify the Pattern**: Which scenario matches your logs?
2. **Confirm Root Cause**: The logs will show exactly where the flow breaks
3. **Implement Targeted Fix**: Based on confirmed root cause

### **Possible Fixes Based on Diagnosis:**

#### **If Entry Never Detected:**
- Add background location verification
- Implement periodic location checks
- Add user notification for missed entries

#### **If Entry Rejected:**
- Review tracking days configuration
- Review office hours configuration
- Consider removing or relaxing time restrictions

#### **If State Lost:**
- Add state recovery mechanism
- Improve UserDefaults synchronization
- Add redundant state storage

#### **If State Mismatch:**
- Fix UserDefaults synchronization
- Add state validation on app launch
- Implement state reconciliation logic

---

## Questions to Answer

Based on the logs, we'll be able to answer:

1. ✅ **Is the entry event firing?**
2. ✅ **Is the entry being processed or rejected?**
3. ✅ **Is the state being set correctly?**
4. ✅ **Is the state being persisted correctly?**
5. ✅ **Is the exit event firing?**
6. ✅ **Why is the exit being rejected?**
7. ✅ **Is there a state mismatch?**

---

## Testing Checklist

- [ ] Deploy updated build to TestFlight
- [ ] Install on device
- [ ] Connect device to Mac with Console.app open
- [ ] Go to office and verify entry logs appear
- [ ] Verify `isCurrentlyInOffice` is set to `true`
- [ ] Leave office and verify exit logs appear
- [ ] Check if exit is processed or rejected
- [ ] If rejected, note the reason in logs
- [ ] Share logs for analysis

---

## Contact

Once you have the logs, we can:
1. Identify the exact root cause
2. Implement a targeted fix
3. Verify the fix resolves the issue

The diagnostic logging will give us 100% visibility into what's happening.
