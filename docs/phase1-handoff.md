# MedSync Phase 1 Handoff

## Purpose

This document is the short handoff spec and execution plan for Phase 1 of MedSync.

Hand this off together with:

- `AGENTS.md` as the implementation contract
- `docs/healthautoexport-spec.md` as competitor/reference context only
- `docs/policy-decisions.md` for decisions that were locked after implementation started
- `docs/future-features.md` for agreed long-term directions

The competitor/reference document is useful for orientation, but it is not the implementation contract. Phase 1 is defined by `AGENTS.md` plus the decisions captured in the repo docs.

## Current Branch Snapshot

- `main` already includes the merged automation-runtime work from PR `#1`
- Current working branch for the next increment: `codex/medication-trigger-two-phase`
- This branch adds the two-phase medication-trigger runtime and compatibility fixes for existing persisted runtime-state JSON
- Local status note: the app and tests are working on this machine; the simulator needed to be explicitly booted before the UI smoke test would run reliably

## Phase 1 Work Product Spec

### Product scope

Phase 1 is a local-only native iOS app for exporting Apple Health medication data.

- Platform: iOS 26+
- Data domain: medications only
- Live export destination: iCloud Drive only
- Export formats: CSV and JSON only
- App shell: `Manual Export | Automations | Activity Log | Settings`
- No backend, no local server, no extra destinations, no Phase 2 data domains

### User-facing behavior

#### Manual Export

- User can export medication data on demand.
- Destination must be visible in the UI as `Files > iCloud Drive > MedSync`.
- User can choose:
  - date preset or custom date range
  - CSV or JSON
  - time grouping scaffold value
- Time grouping exists in Phase 1 only as stored UI configuration. It must not be presented as medication aggregation output.
- Successful exports must not overwrite earlier successful exports.

#### Automations

- User can create, edit, delete, enable, disable, run now, and run all automations.
- An automation carries its own export settings.
- Automation trigger mode is either:
  - scheduled cadence
  - medication taken background trigger
- Only one active automation may use the medication-taken trigger mode at a time.
- Scheduled automation timing must be presented and implemented as best effort.

#### Medication-trigger automation

- Trigger source is qualifying newly logged `.taken` medication events only.
- Background-delivery frequency choices are:
  - immediate
  - hourly
  - daily
- The selected automation's export settings control what gets exported when the trigger fires.
- Locked policy decision:
  - never missing a medication-triggered export is more important than avoiding duplicates
  - the runtime uses a two-phase anchor flow so committed anchors only advance after successful export execution

#### Activity Log

- Logs must be structured, queryable records rather than free-form strings.
- Top-level Activity Log must include:
  - manual export successes and failures
  - automation run successes and failures
  - automation lifecycle events: create, edit, delete
- Per-automation history must stay scoped to the selected automation.
- Persisted fields include:
  - event type
  - automation identity
  - trigger reason
  - status
  - timestamp
  - format
  - date range
  - destination
  - filename
  - error details

#### Notifications and Shortcuts

- Local notifications are supported for automation runs when enabled on the automation.
- Shortcuts/App Intents support running a selected automation manually.

## Current Implementation Status

### Implemented

- Xcode project scaffolded as `MedSync.xcodeproj` with `MedSync`, `MedSyncTests`, and `MedSyncUITests`
- iOS 26 deployment target and SwiftUI + TCA 1.25.x setup
- Fixed 4-tab app shell
- Manual export flow with date presets, custom range, CSV/JSON, time-grouping scaffold, and export execution
- Export file layout under:
  - `MedSync/Manual Exports/<yyyy-MM>/...`
  - `MedSync/Automations/<slug>/<yyyy-MM>/...`
- Overwrite-safe filenames
- Medication export schema with enriched HealthKit medication metadata
- HealthKit medication read path
- Automation CRUD, enable/disable, run now, run all
- Structured activity log persistence and UI
- Best-effort scheduled automation runtime
- Foreground catch-up when the app becomes active
- Medication-trigger runtime using `HKObserverQuery` plus anchored fetch
- Two-phase medication-trigger runtime with pending-trigger persistence, committed-anchor-on-success behavior, and processed-event dedupe tracking
- Local notifications for automation run results
- App Intents / Shortcuts support for running an automation
- Automation detail view with scoped history and runtime timing
- Targeted unit tests and a UI smoke test

### Validated on this machine

- Unit tests passed: `19/19`
- UI smoke test passed after explicitly booting the simulator and rerunning:
  - `MedSyncUITests/testAppLaunchShowsShellTabs`
- Direct simulator app launch also succeeded with `simctl launch`

### Implemented but intentionally transitional

- Automations, activity logs, and runtime state currently use JSON file stores behind dependency clients.
- This is working and testable, and is acceptable for Phase 1.

## Locked Decisions Since The Initial Build

- Medication-trigger reliability should favor not missing exports over avoiding duplicates.
- The medication-trigger runtime now uses a two-phase anchor flow with pending trigger state plus processed-event dedupe.
- SwiftData remains an agreed long-term persistence direction, but it is explicitly deferred beyond Phase 1.

## Known Gaps / What Is Left

### Remaining work required for a strong Phase 1 completion

#### 1. Expand persistence and runtime tests

Highest-value additions:

- persistence tests for automations, activity logs, and runtime state
- runtime-store migration tests for existing JSON-backed data
- execution-client tests for success and failure logging paths
- tests around notification intent and runtime side effects where practical

#### 2. Device-only Phase 1 validation pass

Narrow device validation still needed for:

- HealthKit permission flow
- real medication data reads
- Files visibility in `iCloud Drive > MedSync`
- background-delivery wake behavior
- scheduled automation best-effort behavior
- local notifications
- Shortcuts/App Intents from the system UI

Use `docs/device-validation.md` as the explicit checklist for that pass.

#### 3. Final signing/iCloud wiring when ready

By design, Phase 1 did not block on real team IDs or production iCloud identifiers.

Before broader device validation or distribution, replace the placeholder values for:

- bundle identifiers
- BG task identifier namespace if needed
- iCloud container identifiers
- signing configuration

### Good follow-up work, but not the first next move

- clean up direct `.liveValue` usage in runtime entry points and service actors
- polish minor notification-copy/UI nits
- improve query efficiency for scoped history if JSON-backed persistence becomes limiting in real use
- decide whether pending medication triggers should always run their staged automation snapshot if the user later edits or disables that automation before retry

## Recommended Milestone Plan From Here

### Milestone 1: Foundation and manual export

Status: complete

- scaffold project and targets
- build shell
- implement manual export pipeline
- define export schema
- make file layout visible and overwrite-safe

### Milestone 2: Automation runtime

Status: complete on the current branch

- automation CRUD
- structured logs
- scheduled automation runtime
- medication-trigger runtime
- two-phase medication-trigger durability
- notifications
- Shortcuts/App Intents
- scoped automation history

### Milestone 3: Persistence convergence

Status: deferred beyond Phase 1

- keep JSON-backed dependency clients unless real usage proves them insufficient
- revisit SwiftData in a later phase if richer queries, retention controls, or migration needs justify the complexity

### Milestone 4: Device readiness

Status: next active milestone

- use real signing/iCloud identifiers when needed
- validate on physical device
- document what remains inherently device-only

## Immediate TODO List

1. Add persistence tests for the current JSON-backed storage layer and migration behavior.
2. Add execution-path tests around shared logging/notification side effects where practical.
3. Run the narrow real-device validation pass.
4. Update placeholder signing and iCloud values when ready for device/distribution work.
5. Decide whether pending medication triggers should always run their staged automation snapshot if the user later edits or disables that automation before retry.

## Suggested Handoff Guidance For A Fresh Agent Or Engineer

Tell the next person:

- start with `AGENTS.md`
- read this handoff document next
- use `docs/healthautoexport-spec.md` only as orientation/reference
- treat `docs/policy-decisions.md` as locked decisions
- do not broaden scope beyond medications + iCloud Drive
- prioritize device validation before persistence rewrites or polish
- keep all Apple framework and persistence access behind dependency clients

## Recommended First Task For The Next Session

Get the app onto a physical device, validate the real HealthKit/iCloud/background-delivery path, and fix the concrete issues that show up there before considering a persistence rewrite.
