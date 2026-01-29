PR: feature/setup-style — Setup/onboarding style tokenization

Summary
- Replaced literal colors and icon font sizes in setup/onboarding screens with `DesignTokens` and `Typography` tokens.
- Added icon size tokens (`iconXL`, `iconL`, `iconM`, `icon`) to `Typography`.
- Stabilized widget tests by injecting `UserDefaults` into `AppData` and isolating test suites.
- Wrapped onboarding panels with `.cardStyle()` / `.elevatedCardStyle()`.

Tests
- Full test suite run: **TEST SUCCEEDED** (xcresult in DerivedData Logs/Test). All unit/UI/widget tests pass.

Files changed (high level)
- InOfficeDaysTracker/Theme/Typography.swift
- InOfficeDaysTracker/Views/SetupView.swift
- InOfficeDaysTracker/Theme/CardStyle.swift
- InOfficeDaysTracker/Components/TrendChartCard.swift
- InOfficeDaysTracker/Views/HistoryView.swift
- InOfficeDaysTracker/Models/AppData.swift
- InOfficeDaysTrackerTests/WidgetRefreshTests.swift
- OfficeTrackerWidget/* (font/size updates)

Pre-merge checklist
- [ ] Run full test suite locally (xcodebuild or Xcode) — confirm **TEST SUCCEEDED**.
- [ ] Verify onboarding screens in Xcode Previews and on simulator (light + dark).
- [ ] Capture screenshots of key onboarding/setup screens in both appearances.
- [ ] Manual spot-check of tokenized colors for contrast & accessibility.
- [ ] Confirm `AppData` UserDefaults injection doesn't affect production behavior (only tests use custom suites).
- [ ] Update CHANGELOG/What’s New if applicable.
- [ ] Squash or rebase commits as desired for history cleanliness.
- [ ] Open PR on GitHub from `feature/setup-style` to `main` and include this checklist.

How to run tests locally
```bash
cd /Users/lpineda/Desktop/InOfficeDaysTracker
xcodebuild -project InOfficeDaysTracker.xcodeproj -scheme InOfficeDaysTracker -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test
```

Notes
- Visual QA is left for the reviewer (you). I can run automated simulator screenshots if you want — say so and I'll run them and add to this PR.
- Widget tests were previously flaky; the fix injects `UserDefaults` and uses unique suites per test to avoid cross-test interference.

Branch: feature/setup-style

Contact me if you want me to open the PR or take screenshots now.
