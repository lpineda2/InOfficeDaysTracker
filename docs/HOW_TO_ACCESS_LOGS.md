# How to Access Logs from TestFlight Build

## Method 1: Export Debug Logs (No Mac Required) - NEW! ⭐

**This is the easiest way to get logs after an issue has occurred.**

### **Steps:**
1. **Open the app** on your iPhone
2. **Go to Settings tab**
3. **Scroll to "Data Management"** section
4. **Tap "Export Debug Logs"** (only visible in TestFlight builds)
5. **Choose export option**:
   - **Export Current Log** - For recent issues (today)
   - **Export All Logs (Combined)** - For issues over multiple days
6. **Share the log file** via Email, Messages, AirDrop, or Files app

### **What to Look For:**
Same log patterns as Console.app (see below), but you can search the exported file anytime.

### **Advantages:**
- ✅ No Mac required
- ✅ Logs persist for 7 days
- ✅ Can export anytime, even days after the issue
- ✅ Easy to share with developer
- ✅ Automatic log rotation and cleanup

### **When to Use:**
- You can't connect to Console.app immediately
- Issue happened yesterday or earlier
- You want to share logs with developer
- You need a complete history of events

**See [PERSISTENT_LOGGING_GUIDE.md](PERSISTENT_LOGGING_GUIDE.md) for detailed information.**

---

## Method 2: Console.app (Mac Required) - REAL-TIME

This is the best way to see real-time logs while using the app.

### **Steps:**
1. **Connect your iPhone to your Mac** via USB cable
2. **Open Console.app** on your Mac
   - Location: `/Applications/Utilities/Console.app`
   - Or: Spotlight search → "Console"
3. **Select your device** in the left sidebar
4. **Filter the logs**:
   - In the search box (top right), type: `InOfficeDays`
   - Or for more specific: `LocationService` or `AppData`
5. **Use the app** on your iPhone
6. **Watch logs appear in real-time** in Console.app

### **What to Look For:**
```
🚪 [LocationService] ===== ENTRY EVENT DETECTED =====
✅ [LocationService] Tracking day check passed
✅ [LocationService] Office hours check passed
🔄 [LocationService] Starting periodic location checks

🚪 [LocationService] ===== EXIT EVENT DETECTED =====
✅ [LocationService] Exit validation passed

🔍 [LocationService] Performing periodic location check...
🚨 [LocationService] MISSED EXIT DETECTED via periodic check!
```

### **Exporting Logs:**
1. Select the log entries you want
2. Right-click → "Export Selected Events"
3. Save as text file
4. Share with developer if needed

---

## Method 3: Xcode Console (Mac Required)

Similar to Console.app but through Xcode.

### **Steps:**
1. **Connect your iPhone to your Mac**
2. **Open Xcode**
3. **Window → Devices and Simulators** (or `Cmd+Shift+2`)
4. **Select your device** in the left sidebar
5. **Click "Open Console"** button at the bottom
6. **Filter for** `InOfficeDays` in the search box
7. **Use the app** and watch logs appear

---

## Method 4: On-Device Logs (No Mac Required)

iOS saves system logs that you can access directly on your device.

### **Steps:**
1. **Open Settings** on your iPhone
2. **Privacy & Security → Analytics & Improvements**
3. **Analytics Data**
4. **Look for logs** starting with your app name
5. **Tap to view** and share

**Note**: These logs may be delayed and less detailed than Console.app

---

## Method 5: Crash Logs (Automatic)

If the app crashes, logs are automatically collected.

### **Access via TestFlight:**
1. Open **TestFlight** app
2. Tap on **InOfficeDays**
3. Scroll down to **"Previous Builds"**
4. Tap on a build
5. View crash reports if any exist

### **Access via Settings:**
1. **Settings → Privacy & Security**
2. **Analytics & Improvements → Analytics Data**
3. Look for files starting with `InOfficeDays`
4. Tap to view crash logs

---

## Method 6: Share Diagnostics with Developer

If you want to share logs with me for analysis:

### **Via Console.app:**
1. Follow Method 1 above
2. Reproduce the issue
3. Select relevant log entries
4. Right-click → "Export Selected Events"
5. Save as `.txt` file
6. Share the file

### **Via iPhone:**
1. **Settings → Privacy & Security**
2. **Analytics & Improvements → Analytics Data**
3. Find relevant log file
4. Tap the **Share button** (top right)
5. Send via email or message

---

## What Logs to Capture for Exit Detection Issue

### **Scenario 1: Testing Entry Detection**
**When to capture**: When you arrive at the office

**Look for these logs:**
```
🚪 [LocationService] ===== ENTRY EVENT DETECTED =====
🚪 [LocationService] Region: [office-id]
🚪 [LocationService] Current isCurrentlyInOffice state: false
✅ [LocationService] Tracking day check passed
✅ [LocationService] Office hours check passed
🎯 [LocationService] Calling appData.startVisit()...
[AppData] ===== START VISIT CALLED =====
[AppData] isCurrentlyInOffice set to: true
🔄 [LocationService] Starting periodic location checks
```

### **Scenario 2: Testing Exit Detection**
**When to capture**: When you leave the office

**Look for these logs:**
```
🚪 [LocationService] ===== EXIT EVENT DETECTED =====
🚪 [LocationService] Current isCurrentlyInOffice state: true
✅ [LocationService] Exit validation passed
🔍 [LocationService] Starting exit grace period
```

**OR (if geofence fails):**
```
🔍 [LocationService] Performing periodic location check...
📍 [LocationService] Periodic check - distance from Office: 2500m
🚨 [LocationService] MISSED EXIT DETECTED via periodic check!
🚨 [LocationService] Geofence exit event was missed - processing exit now
```

### **Scenario 3: Exit Rejection (The Problem)**
**When to capture**: If exit is NOT detected

**Look for these logs:**
```
🚪 [LocationService] ===== EXIT EVENT DETECTED =====
🚪 [LocationService] Current isCurrentlyInOffice state: false
🚫 [LocationService] EXIT REJECTED - user was not marked as in office
🚫 [LocationService] This exit will NOT be processed
```

---

## Quick Reference: Log Emoji Guide

- 🚪 = Entry/Exit event detected
- ✅ = Check passed
- ❌ = Check failed / Rejected
- 🔍 = Verification/Diagnostic check
- 🔄 = Timer/Periodic action
- 🚨 = Alert/Important event
- ⚠️ = Warning
- 📍 = Location information
- 🛑 = Stopped/Cancelled
- ⏰ = Timer expired

---

## Troubleshooting

### **"I don't see any logs in Console.app"**
- Make sure your device is selected in the left sidebar
- Try disconnecting and reconnecting the USB cable
- Make sure the app is running on your device
- Check that the search filter is correct: `InOfficeDays`

### **"Logs are too noisy"**
- Use more specific filters:
  - `LocationService` - Only location-related logs
  - `AppData` - Only data management logs
  - `ENTRY EVENT` - Only entry events
  - `EXIT EVENT` - Only exit events
  - `MISSED EXIT` - Only missed exit detections

### **"I can't connect my device to Mac"**
- Use Method 3 (On-Device Logs) instead
- Or wait for the issue to occur and check history in the app
- The app will still work correctly even without log monitoring

---

## Privacy Note

The logs contain:
- ✅ Timestamps of entry/exit events
- ✅ Distance calculations
- ✅ State changes
- ❌ NO personal information
- ❌ NO exact GPS coordinates (only distances)
- ❌ NO sensitive data

It's safe to share logs for debugging purposes.

---

## Summary

**Best for real-time monitoring**: Method 1 (Console.app)
**Best for quick checks**: Method 2 (Xcode Console)
**Best without Mac**: Method 3 (On-Device Logs)
**Best for crashes**: Method 4 (Crash Logs)

For debugging the exit detection issue, **Method 1 (Console.app)** is highly recommended as it shows real-time logs as events happen.
