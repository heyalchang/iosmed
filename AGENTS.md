# AGENTS.md

## Mission Boundaries (NEVER VIOLATE)

- Phase 1 is a **local-only native iOS app**. Do **not** introduce a backend, web service, local TCP server, or any custom port binding.
- Do not use or disturb existing local ports already occupied on this machine, including `3000`, `3200`, `5000`, `7000`, `8787`, and `9400`.
- Keep the deployment target at **iOS 26+**. Do not lower it; the HealthKit Medications API requires iOS 26.
- Keep iCloud configuration placeholder-friendly for now. Do not block the mission on real team IDs, production signing, or final container IDs.
- Do not add Phase 2 destinations or data domains in this mission. Phase 1 is medications only, with **iCloud Drive** as the only live destination.
- Background scheduling must always be presented and implemented as **best effort**, never as exact-time cron behavior.
- The special medication-trigger automation must react only to qualifying newly logged **taken** medication events.

Workers: if you cannot complete your work within these boundaries, return to the orchestrator. Never violate them.

## Project Conventions

- Project naming should converge on:
  - `MedSync.xcodeproj`
  - app scheme `MedSync`
  - test targets `MedSyncTests` and `MedSyncUITests`
- Use **SwiftUI + TCA 1.25.x** with current APIs only:
  - `@Reducer`
  - `@ObservableState`
  - direct store access in views
  - dependency clients for HealthKit, iCloud, notifications, App Intents, and scheduling

- Do not use deprecated TCA APIs such as `ViewStore`, `WithViewStore`, or deprecated binding reducers.
- Keep SwiftData and framework access behind dependency clients so reducers remain testable.
- Maintain a clean layered core:
  1. domain/export configuration
  2. reducer orchestration
  3. live Apple-framework clients
- Export formats are exactly **CSV** and **JSON**.
- Time grouping exists in Phase 1 as UI scaffolding with options **minutes / hours / days / weeks / months / years** and must not be misrepresented as aggregated health-metric output.
- Export artifacts must not silently overwrite previous successful exports.
- App shell contract is fixed: **Manual Export | Automations | Activity Log | Settings**.
- Activity logs must be **structured and queryable**, not ad-hoc strings. Persist fields for event type, automation identity, trigger reason, status, timestamp, format, date range, destination, filename, and error details.

## Product-Specific Guidance

- Manual export must target **Files > iCloud Drive > MedSync** and should make that destination visible in the UI.
- The top-level Activity Log must include:
  - manual export successes and failures
  - automation run successes and failures
  - automation lifecycle events: create, edit, delete
- Per-automation history must stay scoped to the selected automation.
- Trigger reasons should stay consistent across the app:
  - Manual Export
  - Run Now
  - Run All
  - Scheduled/Background
  - Shortcuts
  - Medication Trigger / Background Delivery
- The special medication-trigger automation uses background-delivery frequency options **immediate**, **hourly**, or **daily** and that frequency replaces cadence for that automation mode.

## Testing & Validation Guidance

- Add tests before implementation:
  - reducer/unit tests for TCA behavior
  - serializer/export-runner tests for artifacts and failure mapping
  - persistence tests for structured log storage
  - targeted smoke/UI tests for shell and non-device-only flows
- Prefer simulator automation and dependency-injected tests over device-only validation.
- If a behavior is inherently device-only (real HealthKit permissions/data, Files-app visibility, realistic background wake timing), keep the device pass narrow and document exactly what remains unverified in automated form.
- If the first foundation feature is creating the Xcode project, it is acceptable for initial build/test/lint commands to report that the project does not exist yet; scaffold it first, then rerun the relevant commands.
