# Release Checklist — In Office Days Tracker

Use this checklist for every release. It mirrors the release workflow in `CLAUDE.md`: validate locally, validate on simulator and device, deploy to TestFlight, confirm physical-device validation, then release to the App Store. See `TEST_PLAN.md` for the detailed validation strategy behind each step.

Do not skip steps unless explicitly instructed. A build is never "released" until physical-device validation is confirmed.

---

## Pre-merge validation

- [ ] Working tree is clean and on a `feature/`, `bugfix/`, or `release/` branch (never directly on `main`).
- [ ] `./scripts/test.sh` passes.
- [ ] `xcodebuild` succeeds for app and widget targets.
- [ ] Widget-duplicated models (`CompanyPolicy`, `HolidayCalendar`, `OfficeLocation`) reviewed if any copy changed.
- [ ] No analytics, telemetry, remote logging, or network behavior added.
- [ ] No hardcoded colors/fonts/spacing; `DesignTokens` / `WidgetDesignTokens` used.

---

## Simulator validation

- [ ] Monthly goal calculation shows correct required and completed days.
- [ ] Weekly goal view shows correct counts and respects weekly policy.
- [ ] PTO and sick day adjustments reflected in goal math.
- [ ] Holiday exclusions applied (no counting on holidays).
- [ ] Office day counting correct (one qualifying day = one count).
- [ ] Multiple office locations all qualify a day.
- [ ] Dark mode legible on all screens.
- [ ] Dynamic Type scales without truncation/overlap.
- [ ] Small-screen layout (e.g., iPhone SE) has no clipping.
- [ ] VoiceOver labels present on key counts and actions.
- [ ] Widget data matches app data for the same period.

---

## Data / persistence validation

- [ ] Settings persist across app relaunch (policy, locations, PTO/sick, goals).
- [ ] History persists and is unchanged after relaunch.
- [ ] Fresh install produces correct defaults and empty states.
- [ ] Stored data decodes without crashing when optional fields are absent.

---

## Upgrade validation

- [ ] Install the previously released build, configure data, then update to the candidate.
- [ ] Existing user data (settings + history) loads correctly with no reset to defaults.
- [ ] No schema mismatch or migration crash.
- [ ] Widget reads the same store and shows consistent values after upgrade.

---

## TestFlight validation

- [ ] Build number/version confirmed and approved before incrementing (`./scripts/update_version.sh --increment-build`).
- [ ] TestFlight deploy approved before running `fastlane ios deploy_testflight`.
- [ ] Build installs cleanly from TestFlight.
- [ ] Fresh-install flow completes (onboarding, policy, office location).
- [ ] Upgrade-install flow preserves settings and history.
- [ ] No debug-only behavior or test data present.

---

## Physical device validation

- [ ] Geofencing records an office day when entering a real location.
- [ ] Stale grace period resets correctly across a day boundary.
- [ ] Notifications fire and are correctly worded.
- [ ] Background detection works without the app foregrounded.
- [ ] Location and calendar permission prompts behave correctly (grant, deny, re-grant).
- [ ] Full-day behavior/battery sanity check completed.
- [ ] **Physical device validation explicitly confirmed** ("Physical device validation passed").

---

## App Store release readiness

- [ ] All sections above complete.
- [ ] Physical-device validation confirmed.
- [ ] Merge to `main` approved (App Store release only from `main`).
- [ ] `main` push approved.
- [ ] Version and build number correct for the release.
- [ ] App Store submission/release approved before running `fastlane ios submit_for_review` / `fastlane ios release_app_store`.
- [ ] No release signing, provisioning, or App Store Connect changes made without explicit approval.

---

## Final go / no-go

| Gate | Status |
|------|--------|
| Unit tests pass | ☐ |
| App + widget build | ☐ |
| Simulator validation | ☐ |
| Persistence + upgrade validation | ☐ |
| TestFlight validation | ☐ |
| Physical device validation confirmed | ☐ |
| Version/build correct | ☐ |
| Approvals obtained for merge/push/release | ☐ |

**Go only if every gate above is checked.** Any unchecked gate is a no-go.
