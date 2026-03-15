# Competitor Parity Roadmap

## Purpose

This note sizes the major work remaining after the current MedSync Phase 1 baseline if the goal shifts from "usable medication exporter" to "match the main practical features of Auto Health Export."

Use this together with:

- `docs/phase1-handoff.md` for the current MedSync baseline
- `docs/healthautoexport-spec.md` for competitor/reference context

This is a planning estimate, not an implementation contract.

## Current Baseline

The current MedSync app is a narrow vertical slice:

- medications only
- iCloud Drive only
- CSV and JSON only
- manual export
- automation CRUD and run controls
- best-effort scheduled automations
- medication-trigger automation
- structured activity logs
- local notifications
- App Intent / Shortcuts support

That is a solid Phase 1 base, but it is still much narrower than the public Auto Health Export surface.

## Relative Sizing

Treat the current codebase plus device-readiness work as `1.0x`.

Estimated additional effort:

- finish the current base to a solid device-usable build: `+0.2x` to `+0.4x`
- reach the main practical feature set of Auto Health Export: `+3x` to `+4x`
- approach broad public-surface parity: `+5x` to `+7x`

Interpretation:

- the current app is roughly `15%` to `25%` of broad competitor parity
- the gap is not mostly polish; it is mostly missing product surface

## Biggest Workstreams

### 1. Additional health domains

Add the other exported data types beyond medications:

- health metrics
- symptoms
- cycle tracking
- ECG
- heart-rate notifications
- state of mind

This is the largest remaining product bucket because each domain needs:

- HealthKit mapping
- export modeling
- UI selection/configuration
- logs and error handling
- tests

Rough size: `+1.5x` to `+2x`

### 2. Workouts as a dedicated subsystem

Workouts are not just another data type. They are their own feature family:

- versioned export schemas
- workout metadata
- optional workout metrics time series
- route support
- GPX export
- workout-specific time grouping and flags

Rough size: `+1x` to `+1.5x`

This is likely the hardest single domain after general health metrics.

### 3. Richer export semantics

The competitor surface includes more than raw data extraction:

- export versioning
- meaningful grouping and summarization
- unit preferences
- multi-file CSV behavior
- zip packaging
- export history and re-share flows

Rough size: `+0.75x` to `+1.25x`

### 4. Destination ecosystem

The current app has one destination. Main parity would require several:

- REST API
- Google Drive
- Dropbox
- MQTT
- Home Assistant
- Calendar

Each destination brings:

- auth/setup
- request or file-delivery semantics
- retries/timeouts
- folder/topic/entity naming rules
- destination-specific logging and troubleshooting UX

Rough size: `+1.5x` to `+2x`

This is the second biggest bucket after domain expansion.

### 5. Integration surfaces

The competitor also exposes integration entry points beyond the core app:

- widgets
- richer Shortcuts workflows
- deep-link automation creation
- optional local server / network-query feature

Rough size: `+0.5x` to `+1x`

The local server is not the most important value surface, but it is part of the public feature set.

### 6. Hardening and real-device behavior

Every added domain and destination multiplies:

- background behavior edge cases
- HealthKit access timing issues
- cloud auth failures
- larger export sizes
- retention and activity-log scale
- regression surface

Rough size: `+1x` ongoing

This is the part that tends to make parity slower than the feature checklist suggests.

## Highest-Leverage Order

If the goal is "competitive enough" rather than "clone everything," the fastest sequence is:

1. Finish device-readiness for the current medication baseline.
2. Add general health metrics.
3. Add REST API destination.
4. Add workouts.
5. Add one major cloud destination, likely Google Drive.
6. Add export-history / richer packaging / remaining destination polish.

Why this order:

- health metrics are the biggest missing user-facing surface
- REST API gives broad downstream flexibility with one integration
- workouts add major product value after metrics
- a major cloud destination closes a large usability gap

## What To Defer If Time Matters

If schedule matters more than full parity, defer these until later:

- local server / network query feature
- full deep-link automation creation surface
- Calendar and Home Assistant before REST API is solid
- clone-level CSV parity across every domain
- clone-level multipart delivery fidelity

## Important Caveat About Compatibility

Matching the competitor's broad feature set is one problem.

Matching it byte-for-byte is a different problem.

The reference material in `docs/healthautoexport-spec.md` explicitly calls out gaps in the public docs around:

- exact CSV schemas for every data type
- exact multipart form structure for REST CSV uploads

If exact compatibility matters, add a separate capture-and-fixture effort on top of the estimates above.

## Bottom Line

The current app is a real base, but not a near-parity base.

The biggest remaining lifts are:

- more health domains
- workouts
- multiple destinations

If MedSync is only meant to become a strong medication exporter, the current Phase 1 path is appropriate.

If the goal shifts to "replace Auto Health Export for most people," expect a multi-phase expansion, not a short follow-up sprint.
