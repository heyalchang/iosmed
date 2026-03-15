# Policy Decisions

## 2026-03-14

### Medication-trigger export reliability

- Priority: never miss a medication-triggered export.
- Implication: at-least-once behavior is preferred over at-most-once behavior for medication-trigger automation runs.
- Follow-on decision: the medication-trigger runtime should move to a two-phase anchor model instead of advancing the committed anchor before export success.
- Current implementation note: the repository now includes a two-phase pending/committed medication-trigger runtime with processed-event dedupe tracking.
- Intended shape:
  - persist a pending anchor after observing new qualifying `.taken` medication events
  - run the selected automation
  - commit the anchor only after a successful export
  - keep dedupe data for processed event IDs so retries after partial success do not create avoidable duplicates

### Persistence direction

- Direction: SwiftData is the agreed long-term persistence layer for structured local data in this app.
- Scope: automations, activity logs, and runtime state should ultimately live behind dependency clients backed by SwiftData.
- Constraint: reducers must continue to interact through dependency clients so TCA features remain testable.
- Phase decision: do not make SwiftData migration a Phase 1 blocker.
- Transitional note: the current JSON file stores are acceptable for Phase 1 as long as they remain behind dependency clients and support the required structured log/runtime behavior.
