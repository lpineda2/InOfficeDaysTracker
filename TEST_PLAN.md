# Test Plan — In Office Days Tracker

This document defines the validation strategy for the In Office Days Tracker app. Its goal is to ensure that every release consistently verifies calculation logic, the weekly/monthly views, persistence, upgrade behavior, simulator coverage, TestFlight readiness, and physical-device behavior before shipping.

Keep this plan practical. Every release should be able to point at the relevant sections below as the evidence that validation actually happened.

---

## Validation goals

- **Correctness of office-day math.** Monthly and weekly goal calculations, PTO/sick adjustments, and holiday exclusions must produce the same results a user would compute by hand.
- **No data loss.** Settings, history, and goal configuration survive app restarts, OS upgrades, and app upgrades.
- **Stable geofencing.** Office detection and the stale grace-period state machine behave correctly across day boundaries and permission changes.
- **Consistent UI.** Weekly and monthly views render correctly in light/dark mode, with Dynamic Type, and on small screens.
- **Release confidence.** Every build promoted to TestFlight or the App Store has documented simulator and physical-device validation.

---

## Testing layers

| Layer | What it covers | Where it runs |
|-------|----------------|---------------|
| Unit | Calculation logic, policy math, date/holiday handling, persistence encode/decode | `./scripts/test.sh` (simulator) |
| UI / simulator | View rendering, navigation, accessibility, layout | Xcode simulator, multiple devices |
| Integration | AppData + services interaction (location, calendar, notifications) | Simulator + manual |
| Persistence / migration | Stored data survives restart and upgrade | Simulator + physical device |
| TestFlight | Real distribution build, fresh install + upgrade | TestFlight |
| Physical device | Geofencing, notifications, background behavior | Real iPhone |

Run lower layers first. A failure at the unit layer should stop promotion before any simulator or device work.

---

## Unit testing focus areas

These are the highest-value areas to cover with automated tests. The math is the core of the app, so it should be the most thoroughly tested.

- **Monthly goal calculation**
  - Required in-office days for the month given the configured policy.
  - Progress vs. goal at the start, middle, and end of a month.
  - Months with varying numbers of working days.
- **Weekly goal view / weekly policy support**
  - Weekly required days derived from the company policy.
  - Week boundaries (start-of-week handling, partial weeks at month edges).
  - Switching between monthly and weekly policy modes.
- **PTO and sick day adjustments**
  - PTO and sick days reduce the required/expected denominator correctly.
  - Overlap cases (PTO on a holiday, PTO on a weekend, PTO on a counted office day).
- **Holiday exclusions**
  - `HolidayCalendar` removes holidays from working-day counts.
  - Holidays falling on weekends do not double-count.
- **Office day counting**
  - A qualifying visit counts as exactly one office day.
  - Multiple visits on the same day count once.
  - Day-boundary attribution (a visit spanning midnight).
- **Multiple office locations**
  - Any configured `OfficeLocation` qualifies a day.
  - Adding/removing locations does not corrupt history.
- **Stale grace period behavior**
  - Grace-period state does not leak across a day boundary (see `bugfix/stale-grace-period-state`).
  - Expired grace period resets cleanly.

---

## UI / simulator validation

Validate on at least one small-screen and one large-screen device.

- Monthly view renders correct counts and progress indicators.
- Weekly view renders correct counts and respects weekly policy.
- Settings screens reflect persisted values.
- **Dark mode**: all screens legible, no hardcoded colors leaking (uses `DesignTokens` / `WidgetDesignTokens`).
- **Dynamic Type**: text scales without truncation or overlap at large sizes.
- **Small-screen layout** (e.g., iPhone SE): no clipped controls, cards, or labels.
- **VoiceOver**: key counts, goals, and actions have meaningful labels.
- Widget rendering matches app data for the same period.

---

## Data persistence and migration testing

- **Settings persistence**: policy, office locations, PTO/sick entries, and goal configuration survive app relaunch.
- **History persistence**: recorded office days survive relaunch and are unchanged.
- **Fresh install path**: first launch produces sane defaults, no crash, and correct empty states.
- **Existing user upgrade path**: data written by the previously shipped version loads correctly in the new build (no schema mismatch, no reset to defaults).
- **Decode resilience**: missing/optional fields in stored data decode without crashing.
- Verify the widget reads the same persisted store and shows consistent values after an upgrade.

---

## TestFlight validation

- Build installs from TestFlight on a clean device.
- Fresh install: complete onboarding, configure policy and at least one office location.
- Upgrade install: install the previously released build first, then update to the candidate; confirm settings and history are preserved.
- Confirm version and build number match the intended release.
- Confirm no debug-only behavior or test data is present.

---

## Physical device testing

Some behavior cannot be validated in the simulator.

- **Geofencing**: entering/leaving a real office location records an office day.
- **Stale grace period**: leave a location, cross a day boundary, confirm state resets correctly.
- **Notifications**: reminders fire and are correctly worded.
- **Background behavior**: detection works without the app foregrounded.
- **Permissions**: location (When in Use / Always) and calendar prompts behave correctly, including denial and later re-grant.
- Battery/behavior sanity check over at least one full day.

Per the release workflow, a build is not release-complete until physical-device validation is explicitly confirmed.

---

## Known high-risk areas

- **`Models/AppData.swift`** — large singleton with broad blast radius; changes here can affect every screen and the widget. Validate broadly.
- **`Services/LocationService.swift`** — geofencing state machine; validate lifecycle and permission edge cases on a real device.
- **Stale grace-period state** — recently fixed across day boundaries; regression-test on every release.
- **Widget-duplicated models** (`CompanyPolicy`, `HolidayCalendar`, `OfficeLocation`) — a change in one copy may need the same change in the other; validate both app and widget compilation paths.
- **Date/calendar math** — time zones, week boundaries, and month edges are common sources of off-by-one errors.

---

## Recommended future automation

- Expand unit coverage for monthly/weekly calculation edge cases (month/week boundaries, overlapping PTO/holidays).
- Add snapshot tests for monthly/weekly views in light/dark and large Dynamic Type.
- Add a persistence round-trip test that loads fixtures encoded by prior app versions to guard the upgrade path.
- Add a geofence state-machine test harness to simulate enter/exit/day-boundary sequences without a device.
- Wire `./scripts/test.sh` into CI so the unit layer runs on every push.
