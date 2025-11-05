# 📅 Calendar Integration Feature Requirements Document

## **Feature: Calendar Event Integration v1.8.1**

**Branch:** `feature/calendar-event-integration`  
**Base Version:** v1.7.0 (WhatsNewKit + Lock Screen Widgets)  
**Target Version:** v1.8.1  
**Date:** November 5, 2025  
**Status:** ✅ Updated — Post Review Decisions Applied

---

## 🎯 **Feature Overview**

Integrate calendar event creation to automatically log office visits and remote work days, providing users with a comprehensive calendar view of their work patterns while maintaining the app's privacy-first approach.

### **Key Benefits:**
- 📊 Visual calendar representation of work patterns  
- 🔄 Automatic event creation and updates  
- 🏠 Track both office and remote work days  
- ⚙️ User-configurable (titles, calendar, timing, availability)  
- 🔒 Privacy-first implementation (local, EventKit-only)

---

## 🧩 **Review Updates & Decisions (v1.8.1)**

| # | Topic | Decision | Summary |
|---|------|----------|---------|
| 1 | Conflict & Overlap Behavior | **User control** with default **Free** | Add settings toggle “Show status events as Busy.” Default: Free to avoid blocking meetings. |
| 2 | Deterministic IDs | **Deterministic UID** | Use `iod-YYYY-MM-DD-<status>-<hoursHash>` (stored in notes) + local mapping to `eventIdentifier` to prevent duplicates and enable idempotent upserts. |
| 3 | Time Zone Behavior | **Setting** (default Device TZ) | Default follows device time zone. Advanced option to lock to Home Office TZ. DST handled by EventKit. |
| 4 | Error Handling UX | **Non-blocking banner/toast** | On permission revoke/calendar missing, show toast with CTA (e.g., “Fix”). |
| 5 | Metrics & Success | **Track all core KPIs** | Activation, 30-day retention, success/error rates, avg. days correctly synced per month (anonymous). |
| 6 | Accessibility | **Defer full audit** | Use system defaults now; VoiceOver/contrast audit scheduled for v1.9 (known limitation). |
| 7 | Timing Controls | **Use tracking prefs** | Single global start/end time from existing tracking preferences; users select days only. |
| 8 | Data Retention | **Leave events on disable** | When user disables integration, existing events remain; note this in UI. Cleanup tool deferred. |
| 9 | Multi-Device Consistency | **Deferred** | Risk of duplicates if multiple devices write. Backlog for v2 with iCloud-pref sync/coordination. |

---

## 📋 **Detailed Requirements**

### 1) Event Subject Configuration

**Default Subjects:**  
- **Office Visit:** `"Office Day"`  
- **Remote Work:** `"Remote Work"`

**User Customization:**  
- Configurable in Settings (text fields for both)  
- Real-time preview of event titles  
- Reset to defaults option  
- Character limit: 50 (non-empty validation)

**Implementation Notes:**
```swift
struct CalendarSettings {
    var officeEventTitle: String = "Office Day"
    var remoteEventTitle: String = "Remote Work"
    // Availability: .free (default) or .busy
    var availabilityMode: AvailabilityMode = .free
    // Time zone mode: device (default) or homeOffice
    var timeZoneMode: TimeZoneMode = .device
    var homeOfficeTimeZoneId: String? = nil
}
```

---

### 2) Calendar Selection

**Setup Integration:**  
- Add new step to setup → now **7-step** setup (Calendar selection after Permissions)  
- Present writable calendars with names and colors  
- Allow **Skip** (optional feature)  
- Default selection: first writable calendar (or create “In Office Days” if none selected later in Settings)

**Settings Management:**  
- Calendar picker, enable/disable master toggle  
- Change calendar any time (without re-setup)  
- Display selected calendar name and color

**Technical Considerations:**  
- Validate write access before enabling  
- Handle calendars that become unavailable (deleted/restricted) with graceful fallback and banner

---

### 3) Event Timing & Duration

**Timing Source (v1.8.1):** Use **existing tracking preference** hours (`AppSettings.officeHours`) for all status events. Users select **which days** are tracked; a **single global start/end** time applies to those days.

**Options:**  
- **All-day events** (simplified visual) — optional toggle  
- **Timed events** — use `AppSettings.officeHours` (default 9:00–17:00)

**(Future v1.9+)** Per-weekday hours

**Event Duration Logic:**
```
Timed Events:
- Start: AppSettings.officeHours.startTime on event date
- End:   AppSettings.officeHours.endTime on event date

All-day Events:
- AllDay: true for the date
```

---

### 4) Remote Work Events

**Creation Logic:**  
- Create "Remote Work" events **only** on configured tracking days  
- Only when **no valid office visit** occurred (≥ 1 hour total)  
- Use `AppSettings.officeHours` for duration (or all-day if selected)  
- Skip weekends/non-tracking days and system holidays

**Validation Rules:**  
- End-of-day (11:59 PM) check to decide remote creation  
- If an office visit (≥ 1h) appears later (edit/backfill), remove remote and create/update office event

---

### 5) Event Management

**Update Strategy:**  
- **Idempotent upserts** based on deterministic UID (`iod-YYYY-MM-DD-<status>-<hoursHash>`) stored in notes + local mapping to `eventIdentifier`  
- Update on status/hours changes; delete when status cleared

**Lifecycle (Timed example):**  
1. **Visit ends ≥ 1 hour:** Create/Upsert **Office Day** event for that date (or update)  
2. **Visit < 1 hour:** No office event; end-of-day may create **Remote Work** event  
3. **User edits settings (title/availability/all-day):** Upsert future events within window

**Batching:**  
- Batch writes to reduce notifications

**User Edits to Events:**  
- If user manually edits a managed event, mark that instance as **unmanaged** (do not overwrite) in v1.8.1

---

### 6) Event Details & Notes

**Office Day (Timed):**
```
Title: "Office Day" (customizable)
Location: [Office Address from AppSettings.officeAddress]
All Day: false
Start/End: AppSettings.officeHours
Availability: Free (default) or Busy (user setting)
Notes:
- Status: In Office
- Office Hours: 9:00 AM – 5:00 PM
- Total Office Days This Month: 12/15
- UID: iod-2025-11-05-inOffice-<hash>
```

**Remote Work (Timed):**
```
Title: "Remote Work" (customizable)
All Day: false
Start/End: AppSettings.officeHours
Availability: Free (default) or Busy (user setting)
Notes:
- Status: Remote
- Work Hours: 9:00 AM – 5:00 PM
- Total Office Days This Month: 12/15
- UID: iod-2025-11-05-remote-<hash>
```

**All-Day Variants:**  
- `allDay = true`, omit explicit times, retain UID and basic notes

**Privacy Notes:**  
- No precise coordinates stored; office **address only**  
- No reading of personal calendar contents

---

### 7) Settings & User Controls

```
📅 Calendar Integration
├── ✅ Enable Calendar Integration (Master toggle)
├── 📋 Selected Calendar: "Work Calendar" (Picker)
├── 📝 Event Titles
│   ├── Office Event: [Text Field] "Office Day"
│   └── Remote Event: [Text Field] "Remote Work"
├── ⏰ Event Type
│   ├── ○ All-day
│   └── ● Timed (uses AppSettings.officeHours)
├── 👁️ Availability
│   └── [ ] Show status events as Busy  (default OFF → Free)
├── 🌐 Time Zone Mode
│   ├── ● Follow device time zone (default)
│   └── ○ Use home office time zone
├── 🏠 Remote Work Events
│   └── ✅ Create remote work events
└── [ Reset to Defaults ]
```

**Validation:** Non-empty titles; 50-char limit; calendar availability; permission monitoring

---

### 8) Privacy & Permissions

**Info.plist:**
```xml
<key>NSCalendarsUsageDescription</key>
<string>This app creates calendar events to track your office visits and remote work days, helping you visualize your work patterns. All events are stored locally in your chosen calendar.</string>
```

**Permission Flow:**  
- Request in setup Permissions step  
- If denied → allow skip; show **non-blocking banner** when needed with CTA to fix  
- Re-request path from Settings

**Compliance:**  
- Local-only writes via EventKit  
- No external services; no reading private events  
- Clear disable behavior (events remain)

---

## 🏗 **Technical Implementation Plan**

**Phase 1: Core EventKit Integration (Week 1)**  
1) Import EventKit; add `CalendarService` (CRUD)  
2) Permission handling + error states  
3) Deterministic UID helper + local mapping

**Deliverables:** CalendarService CRUD, permission flow, UID utilities

**Phase 2: Settings & Configuration (Week 1–2)**  
- Extend `AppSettings` with calendar prefs (titles, availability, TZ mode)  
- Calendar Integration settings UI & calendar picker  
- Validation and error handling

**Phase 3: Event Creation Logic (Week 2–3)**  
- Integrate with visit tracking & tracking preferences  
- End-of-day remote logic; office ≥1h logic  
- All-day/timed upserts; unmanaged-instance detection

**Phase 4: UI/UX Integration (Week 3)**  
- Setup flow step (now 7-step)  
- Non-blocking error banners/toasts  
- Optional preview (defer if needed)

**Phase 5: Testing & Validation (Week 4)**  
- Unit + integration + device matrix  
- Performance/battery checks  
- Accessibility (system defaults), mark limitations

---

## 🔄 **Data Flow Integration**

**Current App Flow:**
```
LocationService → AppData.visits → WidgetKit Updates
                     ↓
              Visit Validation (≥1 hour)
                     ↓
               UI Updates & Notifications
```

**Enhanced with Calendar:**
```
LocationService → AppData.visits → WidgetKit Updates
                     ↓              ↓
              Visit Validation → CalendarService
                     ↓              ↓
            Status Resolution → Event Upsert/Delete
                     ↓              ↓
               UI Updates    → User's Calendar (EventKit)
                     ↓              ↓
            Notifications    → Local eventIdentifier store
```

**Event ID Management (deterministic):**
```swift
func makeUID(date: Date, status: Status, hours: Hours) -> String {
    let dateStr = DateFormatter.yyyyMMdd.string(from: date)
    let hoursHash = hours.hashValue // stable representation
    return "iod-\(dateStr)-\(status.rawValue)-\(hoursHash)"
}
```

---

## 📱 **User Experience Flow**

**Setup Flow:**
```
Step 1: Welcome
Step 2: Office Location
Step 3: Tracking Days
Step 4: Office Hours (single global start/end)
Step 5: Monthly Goal
Step 6: Permissions (Location + Notifications + Calendar)
Step 7: 📅 Calendar Setup (Optional)
Step 8: Complete
```

**Calendar Setup Step UI (Example):**
```
📅 Calendar Integration (Optional)
Choose Your Calendar:
○ 🔵 Personal    ● 🟢 Work    ○ 🟡 Events    ○ 🔴 Family

Preview: “Office Day” (Timed 9–5) will be created in Work Calendar.
[ Skip ]   [ Continue ]
```

**Error Banner Example:**  
> “Calendar sync paused — permission revoked. **Fix**”

Tap **Fix** → go to Settings or in-app repair flow.

---

## ✅ **Acceptance Criteria**

**Must Have (v1.8.1):**
- Calendar permission request integrated into setup (skippable)  
- Calendar selection in setup & Settings  
- Office visit events created automatically when day qualifies per tracking prefs (≥1h for office; else remote on tracking days)  
- Event titles configurable with validation  
- Master toggle to enable/disable integration  
- Events update when settings change (titles, all-day/timed, availability, TZ mode) for future window  
- Deterministic UID scheme with idempotent upserts  
- Non-blocking error banners for permission/calendar issues  
- Data persistence for calendar preferences and event IDs

**Should Have (v1.8.2):**
- All-day event option (may land in 1.8.1 if low risk)  
- Change calendar without data loss (re-upsert future window)  
- Bulk cleanup tool (remove managed events)  
- Event preview (next 2 weeks)  
- Sync status indicator

**Could Have (Future):**
- Per-weekday hours (tracking + calendar)  
- Multiple calendars (separate office vs remote)  
- Calendar analytics & reporting  
- Import/export & team sharing

**Won’t Have (v1.8.x):**
- External calendar service APIs (Google/Outlook SDKs)  
- Meeting conflict detection/resolution  
- Event reminders/alerts (we default to none)

---

## 🧪 **Testing Strategy**

**Unit:**  
- CalendarService CRUD & UID generation  
- Upsert logic for office/remote/all-day  
- Settings persistence & validation  
- Permission edge cases

**Integration:**  
- Full setup with/without skip  
- Settings changes impacting future events  
- End-of-day remote creation; office ≥1h scenarios  
- Error banners on permission revoke/calendar deletion

**Device Matrix:**  
- iOS 17+; iCloud/Exchange/Google calendars  
- Background refresh scenarios; low storage; offline

**Performance:**  
- Upsert throughput for 90-day window  
- Battery impact of batches  
- Memory during large histories

**Accessibility:**  
- System defaults only (v1.8.1); track known limitation

---

## 🔒 **Security & Privacy Considerations**

- Write-only usage of EventKit; no reading personal events  
- No external services; data stays on device/iCloud via Calendar app  
- No precise GPS or sensitive content in event bodies  
- Error logs contain no sensitive user data  
- Clear copy: disabling leaves existing events in place

---

## 📋 **Version & Compatibility**

**Target Version:** v1.8.1  
**iOS Requirement:** iOS 17.0+  
**Xcode Requirement:** Xcode 15.0+

**Dependencies:**  
- Existing: WhatsNewKit, CoreLocation, UserNotifications, WidgetKit  
- New: **EventKit**

---

## 🚀 **Release & Deployment Plan**

**Pre-Release:**  
- TestFlight beta with calendar integration  
- UAT across calendar setups  
- Performance validation  
- Accessibility note (known limitation)

**Announcement:**  
- WhatsNewKit card for v1.8.1  
- App Store notes & help docs update

**Rollback:**  
- Feature flag gate  
- Preserve user data; no destructive migrations

---

## 📊 **Metrics & Success Criteria**

- **Activation rate:** % of tracked users enabling calendar integration  
- **Retention:** % still enabled after 30 days  
- **Event write success:** success rate & **errors per 1k writes**  
- **Engagement:** avg. **days with correctly synced status** per user/month

*(All metrics are anonymous counters; no event titles or personal calendar content recorded.)*

---

## 🔄 **Review & Approval Process**

**Stakeholders:** Product Owner, Tech Lead, Privacy Officer, QA Lead  
**Checklist:**  
- Requirements approved  
- Technical approach validated (UID/idempotency, TZ, error UX)  
- Privacy reviewed  
- Test plan comprehensive  
- Timeline realistic

---

## 📅 **Timeline**

**Total Duration:** 4 weeks (unchanged)  
**Start:** Nov 5, 2025 → **Target Complete:** Dec 3, 2025  
**TestFlight:** Dec 10, 2025  
**App Store:** Dec 17, 2025

---

## 📝 **Change Log**

| Date | Version | Changes | Reviewer |
|------|---------|---------|----------|
| 2025-11-05 | v1.8.0 | Initial draft | — |
| 2025-11-05 | v1.8.1 | Applied review decisions (availability control, deterministic UID, TZ mode, error banners, metrics, defer accessibility, timing tied to tracking prefs, disable leaves events) | — |

---

**📋 Document Status:** 🟢 **Ready for Stakeholder Review**  
**Next Action:** Sign-off & implementation kickoff  
**Contact:** Development Team
