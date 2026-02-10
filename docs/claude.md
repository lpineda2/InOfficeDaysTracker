# Assistant Instructions (neutral)

## Purpose
This document provides guidance and conventions for AI assistants (Copilot, Copilot Chat, Claude, etc.) when working with this repository. It’s workspace-level context to improve suggestions, code generation, and reviews.

## Quick summary
- Project: In Office Days Tracker (iOS SwiftUI app).
- Language: Swift 5.9+, SwiftUI.
- Architecture: MVVM, main app + widget extension.
- Style: Prefer clarity over cleverness; follow Apple Human Interface Guidelines; reuse `DesignTokens` and `WidgetDesignTokens` for colors/themes.
- Tests: Unit tests live in `InOfficeDaysTrackerTests/`. Run `./scripts/test.sh` for automation.

## Guidelines for code suggestions
- Use existing tokens: reference `DesignTokens` and `WidgetDesignTokens` for colors, spacing, and typography.
- Preserve privacy: do not add analytics or remote persistence for sensitive location data.
- Prefer system adaptive colors for labels and backgrounds (`.label`, `.systemBackground`, `.secondarySystemBackground`) unless a fixed hex is required.
- Avoid changing project settings or CI scripts without an explanation and tests.
- Include Accessibility (VoiceOver labels, Dynamic Type) and light/dark mode considerations when proposing UI changes.

## How to run common tasks
- Run tests:
  ```bash
  ./scripts/test.sh
  ```
- Build:
  ```bash
  xcodebuild -project InOfficeDaysTracker.xcodeproj -scheme InOfficeDaysTracker -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
  ```
- Increment build:
  ```bash
  ./scripts/update_version.sh --increment-build
  ```

## Examples / conventions
- Prefer small refactors and keep public APIs stable.
- If adding colors, put them in `InOfficeDaysTracker/Theme/DesignTokens.swift` and `OfficeTrackerWidget/WidgetDesignTokens.swift` and use the `Color(hex:)` helper when needed.
- For new features, add unit tests under `InOfficeDaysTrackerTests/` and update README/changelog.

---

# Claude-specific section

> Note: this section contains suggestions formatted as a Claude-style system prompt. Other assistants may ignore or adapt these instructions.

### Example system instructions (illustrative)
- You are an assistant helping a developer on an iOS app repository.
- Prefer minimal, secure changes. Do not add telemetry or external network dependencies.
- When asked to edit files, present a short plan, the exact code diff, and test commands.
- Use the repository’s `DesignTokens` for color/spacing decisions.
- When proposing UI changes, include accessibility checks and one-line manual QA steps.

### Example prompt to use when responding
"Use the repository context (files under the workspace). Provide a 3-step plan, the modified files as unified diffs, and shell commands to run tests locally. Explain any risks briefly."

End of file.
