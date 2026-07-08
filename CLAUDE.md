# CLAUDE.md — In Office Days Tracker

## Project snapshot

iOS SwiftUI app using Swift 5.9+, iOS 17+, and WidgetKit.

Privacy-first app:

* No analytics
* No telemetry
* No cloud sync
* No remote persistence
* No unnecessary network calls
* Location and calendar data must stay on-device

## Commands

### Validation

Safe validation commands:

```bash
./scripts/test.sh

xcodebuild -project InOfficeDaysTracker.xcodeproj \
  -scheme InOfficeDaysTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

### Versioning

Explicit approval required before running:

```bash
./scripts/update_version.sh --increment-build
```

### Release

Explicit approval required before running:

```bash
fastlane ios deploy_testflight
fastlane ios submit_for_review
fastlane ios release_app_store
```

## Architecture

* MVVM architecture
* `InOfficeDaysTracker/Models/AppData.swift` is the main `ObservableObject` singleton
* `Services/` contains location, calendar, and notification services
* `Views/` contains SwiftUI screens
* `Components/` contains reusable UI cards/components
* `Theme/DesignTokens.swift` is the source of truth for app styling
* `WidgetDesignTokens` is the source of truth for widget styling

## Hard rules

* Plan first, then edit.
* Prefer the smallest safe change.
* Do not rewrite large files unless explicitly required.
* Never commit directly to `main`; use `feature/`, `bugfix/`, or `release/` branches.
* Never force push.
* Never add analytics, telemetry, cloud sync, remote persistence, or unnecessary network calls.
* Never read, echo, modify, log, summarize, or expose secrets or private keys.
* Never modify release signing, provisioning, Fastlane credentials, or App Store Connect keys unless explicitly asked.
* Use `DesignTokens` and `WidgetDesignTokens` for all colors, spacing, typography, and reusable styling.
* Do not hardcode hex colors, fonts, spacing, or visual constants.
* Respect accessibility on every UI change:

  * VoiceOver labels
  * Dynamic Type
  * Light/dark mode
  * Sufficient contrast
* Do not run TestFlight, App Store, or Fastlane release commands without explicit approval.
* Do not increment build numbers unless explicitly asked.

## Approval gates

Claude must ask for explicit approval before running:

* `git commit`
* `git push`
* `git merge`
* `git tag`
* `git clean`
* `./scripts/update_version.sh --increment-build`
* Any `fastlane` command
* Any release, signing, provisioning, or App Store Connect change

Claude must never run:

* `git push --force`
* `git reset --hard`
* `rm -rf`
* `sudo`
* Commands that pipe remote scripts into shell
* Commands that expose, print, inspect, or summarize secrets

Before each approval gate, Claude must summarize:

* Current branch
* Files changed
* Validation completed
* Exact command to run
* Risk level

## High-risk files

Use extra care with:

### `InOfficeDaysTracker/Models/AppData.swift`

* Large singleton with broad blast radius
* Avoid broad refactors
* Prefer targeted changes

### `InOfficeDaysTracker/Services/LocationService.swift`

* Geofencing state machine
* Validate lifecycle and permission edge cases

### `fastlane/AuthKey_ZWWB48GR96.p8`

* Private key
* Do not read, echo, modify, summarize, log, or expose

### Fastlane / App Store Connect files

* Treat as release-sensitive
* Ask before modifying or running release workflows
* Reading Fastlane configuration is allowed only to understand automation behavior
* Do not read private keys, certificates, provisioning profiles, or credentials

## Widget duplication rule

The following model files exist in both the app and widget targets:

* `CompanyPolicy.swift`
* `HolidayCalendar.swift`
* `OfficeLocation.swift`

If one copy changes:

* Check whether the widget copy also needs the same change
* Validate both app and widget compilation paths
* Mention whether the widget copy was reviewed in the final summary

## Branch naming

Use lowercase kebab-case branch names:

* `feature/<short-description>`
* `bugfix/<short-description>`
* `release/<version>`

Examples:

* `feature/smart-pto-goal-calculation`
* `bugfix/geofence-grace-period-reset`
* `release/1.9.0`

Do not create branches with:

* Spaces
* Uppercase letters
* Ticket placeholders
* Vague names such as `feature/update`, `bugfix/fix`, or `changes`

## Standard coding workflow

When the user starts a feature or bug task, use this workflow automatically unless told otherwise:

1. Confirm current branch and repo status.
2. If on `main`, create a new branch:

   * `feature/<short-description>` for features
   * `bugfix/<short-description>` for bugs
3. Inspect the relevant files and existing patterns.
4. Propose a short implementation plan before editing.
5. Implement the smallest safe change.
6. Run validation:

   * Always run `./scripts/test.sh`
   * Run `xcodebuild` for app, UI, widget, build, platform, or release-impacting changes
   * If validation fails, stop and report the failure before proceeding
7. If validation passes, summarize changes and ask before committing:

   * Current branch
   * Files changed
   * Commit message
   * Validation completed
   * Exact command to be run
8. Ask before pushing the branch.

For TestFlight, merging to `main`, and App Store release, follow `## Release workflow`.

## Release workflow

Use this release flow unless told otherwise:

1. Confirm working tree is clean.
2. Confirm current branch.
3. Confirm validation has passed.
4. Confirm build number/version strategy.
5. Ask before incrementing build number.
6. Ask before deploying to TestFlight.
7. Stop and wait for physical-device validation confirmation.

   After TestFlight deploy, stop. Do not continue to merge or release until the user explicitly says:

   `Physical device validation passed`

8. After physical-device validation is confirmed, ask before merging to `main`.
9. Ask before pushing `main`.
10. Ask before submitting or releasing to the App Store.

Rules:

* TestFlight can be deployed from feature/bugfix branches.
* App Store submission/release must only happen from `main`.
* Never submit to App Store directly from a feature or bugfix branch.
* Never mark a release complete until physical-device validation is confirmed.
* Never skip release checklist unless explicitly told to do so.

## Task shortcuts

Interpret these short commands automatically:

* `Task:` means start a feature branch using the standard coding workflow.
* `Bug:` means start a bugfix branch using the standard coding workflow.
* `Fix:` means treat as `Bug:` unless clearly a feature.
* `Release prep:` means run release readiness checks but do not deploy without approval.
* `Ship:` means validate, commit, push, and ask before TestFlight.
* `Continue release:` means continue only after physical-device validation has been confirmed.

## Definition of done

A task is not complete until Claude reports:

1. Plan followed
2. Files changed
3. Validation run
4. Widget duplication check, if relevant
5. Accessibility check, if UI changed
6. Privacy impact check, if data, location, calendar, persistence, or notification behavior changed
7. Release impact check, if build/version/Fastlane/App Store behavior changed
8. Risks or follow-ups

## Output format for implementation work

Use this structure:

1. Plan
2. Changes made
3. Files changed
4. Validation
5. Risks / follow-ups

## Output format before approval gates

Use this structure before asking for approval:

1. Action requested
2. Current branch
3. Files changed
4. Validation completed
5. Exact command to run
6. Risk level
7. Approval question

## Privacy and data handling

This app is privacy-first. Any change involving data, location, calendar, notifications, storage, or permissions must include a privacy impact check.

Claude must call out if a change:

* Adds network behavior
* Adds persistence
* Changes location handling
* Changes calendar access
* Changes notification behavior
* Changes user permissions
* Changes data retention
* Risks exposing private user data

Do not add analytics, telemetry, crash reporting, remote logging, remote configuration, or cloud sync unless explicitly requested.

## UI and accessibility standards

For every UI change:

* Use `DesignTokens` or `WidgetDesignTokens`
* Support light and dark mode
* Support Dynamic Type
* Add or preserve VoiceOver labels where appropriate
* Avoid hardcoded visual constants
* Check spacing, contrast, and readability
* Mention accessibility validation in the final summary

## Testing standards

Validation requirements:

* Run `./scripts/test.sh` before marking work complete.
* Run `xcodebuild` for app, UI, widget, build, platform, or release-impacting changes.
* For duplicated widget/app models, validate both app and widget compilation paths.
* If tests cannot be run, explain why and provide manual validation steps.
* Do not claim validation passed unless it actually ran and passed.

## Full guidelines

See `docs/claude.md` for complete operating principles, git workflow, and task templates.
