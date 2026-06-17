# Diagnostic Logging Plan - Entry/Exit Issue
**Issue:** Identical timestamps for 6/16 and 6/17 (7:39 AM - 3:33 PM, 7.89h)  
**Goal:** Identify why exit detection and/or calendar updates are not working correctly

## 🎯 Logging Strategy

### Priority 1: Exit Detection Flow (CRITICAL)
**Location:** [`LocationService.swift`](InOfficeDaysTracker/Services/LocationService.swift)

Add logging to track the complete exit detection lifecycle:

```swift
// In didExitRegion (around line 800+)
func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    PersistentLogger.shared.log("🚪 EXIT", "Geofence exit detected for region: \(region.identifier)")
    PersistentLogger.shared.log("🚪 EXIT", "Current time: \(Date())")
    PersistentLogger.shared.log("🚪 EXIT", "isCurrentlyInOffice: \(appData?.isCurrentlyInOffice ?? false)")
    PersistentLogger.shared.log("🚪 EXIT", "currentVisit exists: \(appData?.currentVisit != nil)")
    
    // Log grace period decision
    PersistentLogger.shared.log("🚪 EXIT", "Starting exit grace period: \(exitGracePeriod)s")
    PersistentLogger.shared.log("🚪 EXIT", "Grace period will expire at: \(Date().addingTimeInterval(exitGracePeriod))")
    
    // ... existing code ...
}

// In handleExitGracePeriodExpired
private func handleExitGracePeriodExpired() {
    PersistentLogger.shared.log("⏰ GRACE", "Exit grace period expired")
    PersistentLogger.shared.log("⏰ GRACE", "Checking if user is still away...")
    PersistentLogger.shared.log("⏰ GRACE", "Exit time was: \(exitTime?.description ?? "nil")")
    
    // Log minimum away duration check
    if let exitTime = exitTime {
        let awayDuration = Date().timeIntervalSince(exitTime)
        PersistentLogger.shared.log("⏰ GRACE", "Away duration: \(awayDuration)s (minimum: \(minimumAwayDuration)s)")
        PersistentLogger.shared.log("⏰ GRACE", "Meets minimum? \(awayDuration >= minimumAwayDuration)")
    }
    
    // ... existing code ...
}

// In confirmExit
private func confirmExit(for region: CLRegion) async {
    PersistentLogger.shared.log("✅ EXIT", "Confirming exit for region: \(region.identifier)")
    PersistentLogger.shared.log("✅ EXIT", "Exit time: \(Date())")
    
    // ... existing code ...
    
    await appData?.endVisit(at: exitTime)
    PersistentLogger.shared.log("✅ EXIT", "endVisit() completed")
}

// In cancelExit
private func cancelExit() {
    PersistentLogger.shared.log("❌ EXIT", "Exit cancelled - user returned to office")
    PersistentLogger.shared.log("❌ EXIT", "Time: \(Date())")
    // ... existing code ...
}
```

### Priority 2: Calendar Event Updates (CRITICAL)
**Location:** [`CalendarEventManager.swift`](InOfficeDaysTracker/Services/CalendarEventManager.swift)

Track calendar event lifecycle:

```swift
// In handleVisitStart
func handleVisitStart(_ visit: OfficeVisit, settings: AppSettings) async {
    PersistentLogger.shared.log("📅 START", "handleVisitStart called")
    PersistentLogger.shared.log("📅 START", "Visit date: \(visit.date)")
    PersistentLogger.shared.log("📅 START", "Visit entry time: \(visit.entryTime)")
    PersistentLogger.shared.log("📅 START", "Calendar enabled: \(settings.calendarSettings.isEnabled)")
    
    // ... existing code ...
    
    let uid = CalendarEventUID.generate(for: visit.date)
    PersistentLogger.shared.log("📅 START", "Generated UID: \(uid)")
    PersistentLogger.shared.log("📅 START", "Event start date: \(eventData.startDate)")
    PersistentLogger.shared.log("📅 START", "Event end date: \(eventData.endDate)")
    
    do {
        try await calendarService.createOrUpdateEvent(data: eventData, in: calendar)
        PersistentLogger.shared.log("📅 START", "Calendar event created successfully")
    } catch {
        PersistentLogger.shared.log("📅 START", "ERROR: \(error.localizedDescription)")
    }
}

// In handleVisitEnd
func handleVisitEnd(_ visit: OfficeVisit, settings: AppSettings) async {
    PersistentLogger.shared.log("📅 END", "handleVisitEnd called")
    PersistentLogger.shared.log("📅 END", "Visit date: \(visit.date)")
    PersistentLogger.shared.log("📅 END", "Visit entry time: \(visit.entryTime)")
    PersistentLogger.shared.log("📅 END", "Visit exit time: \(visit.exitTime?.description ?? "nil")")
    PersistentLogger.shared.log("📅 END", "Visit duration: \(visit.duration?.description ?? "nil")")
    PersistentLogger.shared.log("📅 END", "Visit isValidVisit: \(visit.isValidVisit)")
    PersistentLogger.shared.log("📅 END", "Calendar enabled: \(settings.calendarSettings.isEnabled)")
    
    // ... existing code ...
    
    let uid = CalendarEventUID.generate(for: visit.date)
    PersistentLogger.shared.log("📅 END", "Generated UID: \(uid)")
    
    if visit.isValidVisit {
        PersistentLogger.shared.log("📅 END", "Finalizing event with exit time")
        let eventData = createEventData(for: visit, settings: settings, isOngoing: false)
        PersistentLogger.shared.log("📅 END", "Event notes: \(eventData.notes)")
        
        do {
            try await calendarService.createOrUpdateEvent(data: eventData, in: calendar)
            PersistentLogger.shared.log("📅 END", "Calendar event updated successfully")
        } catch {
            PersistentLogger.shared.log("📅 END", "ERROR: \(error.localizedDescription)")
        }
    } else {
        PersistentLogger.shared.log("📅 END", "Deleting event (visit too short)")
    }
}

// In createEventData
private func createEventData(...) -> CalendarEventData {
    let uid = CalendarEventUID.generate(for: visit.date)
    PersistentLogger.shared.log("📅 DATA", "Creating event data for date: \(visit.date)")
    PersistentLogger.shared.log("📅 DATA", "UID: \(uid)")
    PersistentLogger.shared.log("📅 DATA", "Start of day: \(startOfDay)")
    PersistentLogger.shared.log("📅 DATA", "Is ongoing: \(isOngoing)")
    
    // ... existing code ...
    
    return eventData
}
```

### Priority 3: Visit State Management (HIGH)
**Location:** [`AppData.swift`](InOfficeDaysTracker/Models/AppData.swift)

Track visit lifecycle and state changes:

```swift
// In startVisit (already has good logging, enhance with timestamps)
func startVisit(at location: CLLocationCoordinate2D) {
    let now = Date()
    PersistentLogger.shared.log("🏢 START", "===== START VISIT CALLED =====")
    PersistentLogger.shared.log("🏢 START", "Timestamp: \(now)")
    PersistentLogger.shared.log("🏢 START", "ISO8601: \(ISO8601DateFormatter().string(from: now))")
    
    // ... existing debug logs ...
}

// In endVisit (enhance existing logs)
func endVisit(at exitTime: Date? = nil) async {
    let actualExitTime = exitTime ?? Date()
    PersistentLogger.shared.log("🏢 END", "===== END VISIT CALLED =====")
    PersistentLogger.shared.log("🏢 END", "Timestamp: \(actualExitTime)")
    PersistentLogger.shared.log("🏢 END", "ISO8601: \(ISO8601DateFormatter().string(from: actualExitTime))")
    PersistentLogger.shared.log("🏢 END", "Exit time provided: \(exitTime != nil)")
    
    // ... existing debug logs ...
    
    // CRITICAL: Log before and after calendar update
    PersistentLogger.shared.log("🏢 END", "About to call calendar event manager...")
    await calendarEventManager.handleVisitEnd(visit, settings: settings)
    PersistentLogger.shared.log("🏢 END", "Calendar event manager completed")
}
```

### Priority 4: Calendar Service Operations (MEDIUM)
**Location:** [`CalendarService.swift`](InOfficeDaysTracker/Services/CalendarService.swift)

Track actual calendar API calls:

```swift
// In createOrUpdateEvent
func createOrUpdateEvent(data: CalendarEventData, in calendar: EKCalendar) async throws {
    PersistentLogger.shared.log("📅 API", "createOrUpdateEvent called")
    PersistentLogger.shared.log("📅 API", "UID: \(data.uid)")
    PersistentLogger.shared.log("📅 API", "Title: \(data.title)")
    PersistentLogger.shared.log("📅 API", "Start: \(data.startDate)")
    PersistentLogger.shared.log("📅 API", "End: \(data.endDate)")
    PersistentLogger.shared.log("📅 API", "All-day: \(data.isAllDay)")
    
    // Check if event exists
    let existingEvent = findEvent(withUID: data.uid, in: calendar)
    if let existing = existingEvent {
        PersistentLogger.shared.log("📅 API", "Found existing event, updating...")
        PersistentLogger.shared.log("📅 API", "Existing event ID: \(existing.eventIdentifier ?? "nil")")
    } else {
        PersistentLogger.shared.log("📅 API", "No existing event found, creating new...")
    }
    
    // ... existing code ...
    
    do {
        try eventStore.save(event, span: .thisEvent)
        PersistentLogger.shared.log("📅 API", "Event saved successfully")
        PersistentLogger.shared.log("📅 API", "Event ID: \(event.eventIdentifier ?? "nil")")
    } catch {
        PersistentLogger.shared.log("📅 API", "ERROR saving event: \(error.localizedDescription)")
        throw error
    }
}

// In findEvent
private func findEvent(withUID uid: String, in calendar: EKCalendar) -> EKEvent? {
    PersistentLogger.shared.log("📅 FIND", "Searching for event with UID: \(uid)")
    
    // ... existing search logic ...
    
    if let found = result {
        PersistentLogger.shared.log("📅 FIND", "Event found: \(found.eventIdentifier ?? "nil")")
        PersistentLogger.shared.log("📅 FIND", "Event title: \(found.title ?? "nil")")
        PersistentLogger.shared.log("📅 FIND", "Event start: \(found.startDate)")
    } else {
        PersistentLogger.shared.log("📅 FIND", "Event not found")
    }
    
    return result
}
```

## 🔍 What to Look For in Logs

### Exit Detection Issues:
1. **Missing exit events:** No "🚪 EXIT" logs when user leaves
2. **Grace period not expiring:** "⏰ GRACE" logs show period starting but not completing
3. **Exit cancelled incorrectly:** "❌ EXIT" logs when user didn't return
4. **Minimum away duration not met:** Away duration < 180s preventing exit confirmation

### Calendar Update Issues:
1. **handleVisitEnd not called:** No "📅 END" logs after exit detection
2. **Calendar disabled:** "Calendar enabled: false" in logs
3. **Event update failing:** "ERROR" in calendar API logs
4. **Wrong UID generated:** UID doesn't match expected format
5. **Event not found:** "Event not found" when trying to update
6. **Event saved but with wrong data:** Check event notes in logs

### State Management Issues:
1. **Visit not in array:** "CRITICAL: Visit not found in visits array"
2. **State persistence failing:** "WARNING: Persistence failed"
3. **Duplicate prevention triggering:** "DUPLICATE PREVENTED" when shouldn't
4. **currentVisit is nil:** "No current visit to end" when exit detected

### Timing Issues:
1. **Large time gaps:** Exit detected hours after actual exit
2. **Async operations not completing:** "About to call..." without "...completed"
3. **App suspension:** Logs stop mid-operation
4. **Date mismatches:** Event created for wrong day

## 📱 Testing Protocol

### Test 1: Manual Exit Detection
1. Open app and verify you're "in office"
2. Leave office geofence
3. Wait 8+ minutes (grace period + minimum away)
4. Check logs for complete exit flow
5. Verify calendar event updated

### Test 2: Calendar Event Verification
1. Open Calendar app
2. Find today's office event
3. Check event notes for entry/exit times
4. Compare with app's recorded times
5. Check if event shows "Currently in office"

### Test 3: State Recovery
1. Force quit app while "in office"
2. Reopen app
3. Check if state recovered correctly
4. Verify currentVisit and isCurrentlyInOffice

### Test 4: Background Exit
1. Enter office, verify entry logged
2. Put app in background
3. Leave office
4. Wait 10 minutes
5. Open app and check if exit was detected
6. Review logs for background operation

## 📊 Expected Log Sequence (Normal Exit)

```
🚪 EXIT: Geofence exit detected for region: Office
🚪 EXIT: Current time: 2026-06-17 15:33:00
🚪 EXIT: Starting exit grace period: 300s
⏰ GRACE: Exit grace period expired
⏰ GRACE: Away duration: 305s (minimum: 180s)
⏰ GRACE: Meets minimum? true
✅ EXIT: Confirming exit for region: Office
✅ EXIT: Exit time: 2026-06-17 15:33:00
🏢 END: ===== END VISIT CALLED =====
🏢 END: Timestamp: 2026-06-17 15:33:00
🏢 END: About to call calendar event manager...
📅 END: handleVisitEnd called
📅 END: Visit exit time: 2026-06-17 15:33:00
📅 END: Visit isValidVisit: true
📅 END: Generated UID: office-visit-2026-06-17
📅 API: createOrUpdateEvent called
📅 FIND: Searching for event with UID: office-visit-2026-06-17
📅 FIND: Event found: ABC123
📅 API: Found existing event, updating...
📅 API: Event saved successfully
📅 END: Calendar event updated successfully
🏢 END: Calendar event manager completed
✅ EXIT: endVisit() completed
```

## 🚨 Red Flags to Watch For

1. **No exit detection:** Missing "🚪 EXIT" logs entirely
2. **Grace period stuck:** "Starting exit grace period" without "expired"
3. **Calendar update skipped:** "handleVisitEnd called" but no "📅 API" logs
4. **Event not found:** Trying to update but event doesn't exist
5. **Async timeout:** "About to call..." without completion log
6. **State mismatch:** isCurrentlyInOffice=true hours after exit

## 🔧 Implementation Notes

- Use `PersistentLogger.shared.log()` for all new logs
- Include timestamps in ISO8601 format for precision
- Log both success and failure paths
- Include relevant state variables in each log
- Use emoji prefixes for easy filtering
- Keep logs concise but informative
