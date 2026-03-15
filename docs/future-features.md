# Future Features

## Agreed Directions

### SwiftData migration

- SwiftData is an agreed future direction for local persistence in MedSync.
- It is deferred beyond Phase 1 unless device validation or real usage exposes a concrete limitation in the current JSON-backed stores.
- The target shape is SwiftData-backed dependency clients for:
  - automations
  - structured activity logs
  - automation runtime state
- Motivation:
  - better queryability for top-level and per-automation history
  - cleaner evolution for retention, filtering, and future persistence needs
  - preserves testability as long as reducers continue to use dependency clients rather than direct framework access
