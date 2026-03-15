# Device Validation Guide

## Purpose

This document is the narrow Phase 1 checklist for getting MedSync onto a physical iPhone and validating the device-only behavior that simulator tests cannot prove.

## Current Baseline

As of 2026-03-14:

- `xcodebuild` succeeds for `generic/platform=iOS` when code signing is disabled.
- The signed `generic/platform=iOS` build fails only because the project still needs a real development team and non-placeholder identifiers.
- Unit tests pass on simulator, including persistence, automation execution, and App Intent coverage.
- The existing UI smoke test passes on simulator.

## Required One-Time Project Setup

Before device install, set these values in the project:

1. `MEDSYNC_BASE_BUNDLE_IDENTIFIER`
2. `MEDSYNC_ICLOUD_CONTAINER_IDENTIFIER`
3. `DEVELOPMENT_TEAM`

Defaults are intentionally placeholder-friendly:

- app bundle ID derives from `MEDSYNC_BASE_BUNDLE_IDENTIFIER`
- test bundle IDs derive from the same base bundle ID
- background refresh task ID derives from the app bundle ID
- iCloud entitlements derive from `MEDSYNC_ICLOUD_CONTAINER_IDENTIFIER`

## Device Preconditions

- physical iPhone running iOS 26 or later
- Apple Health contains medication data, including at least one logged `taken` event
- iCloud Drive enabled on the device
- Health sharing/update permissions available for the signed app identifier
- app installed from Xcode with HealthKit and iCloud capabilities active

## Validation Checklist

### 1. Install and launch

- Build and run MedSync on device from Xcode.
- Confirm the app launches to the 4-tab shell.
- Confirm there are no entitlement or container startup crashes.

### 2. HealthKit permissions

- Open Settings tab and request Health access.
- Confirm HealthKit authorization succeeds.
- Confirm medication-trigger automation background delivery can be armed after permission grant.

### 3. Manual export

- Run a JSON export for a recent preset range.
- Run a CSV export for the same range.
- Confirm both runs appear in Activity Log with structured success entries.
- Confirm files appear in `Files > iCloud Drive > MedSync`.
- Confirm repeated exports do not overwrite prior successful files.

### 4. Automation CRUD and run controls

- Create a scheduled automation.
- Edit it and confirm an automation lifecycle log entry is recorded.
- Use Run Now and confirm a success/failure log entry is recorded with trigger reason `Run Now`.
- Use Run All and confirm enabled automations run with trigger reason `Run All`.

### 5. Scheduled automation behavior

- Create an automation with a near-future cadence.
- Background the app and wait past the eligible time.
- Re-open the app and confirm due automation catch-up runs are logged as `Scheduled/Background`.
- Treat exact timing as best effort, not cron-like.

### 6. Medication-trigger automation

- Mark exactly one automation as the medication-trigger automation.
- Choose a background-delivery frequency: immediate, hourly, or daily.
- Log a new medication `taken` event in Health.
- Confirm the app eventually receives the trigger and runs the selected automation.
- Confirm Activity Log shows trigger reason `Medication Trigger / Background Delivery`.
- Confirm the resulting export lands in `iCloud Drive > MedSync`.
- Confirm duplicate wakeups do not create duplicate runs for the same processed event IDs.

### 7. Failure and retry behavior

- Put the app into a temporary export failure condition if practical, such as disabling iCloud Drive access.
- Log a qualifying medication `taken` event.
- Confirm the trigger does not disappear permanently after the failed run.
- Restore the failure condition and confirm the pending medication trigger can retry and eventually commit.

### 8. Notifications and Shortcuts

- Grant local notification permission and verify export success/failure notifications appear when expected.
- Run the App Intent from Shortcuts and confirm trigger reason `Shortcuts` is logged.

## Expected Gaps

These gaps are acceptable until proven otherwise on device:

- exact background wake timing
- long-term HealthKit observer behavior across reboot/lock state
- iCloud propagation timing to other devices

## Exit Criteria For Phase 1 Device Readiness

Phase 1 is device-ready when all of the following are true:

- app installs and launches on a real device
- HealthKit medication export works with real data
- exports are visible in iCloud Drive
- scheduled catch-up behavior works as best effort
- medication-trigger automation works end-to-end with retry-safe anchor behavior
- notifications and Shortcuts work in their basic supported flows
