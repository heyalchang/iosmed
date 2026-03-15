Replicating Auto Health Export on iOS: A Deep Functional Spec Based on Public Docs
Scope and product framing
This report reverse-engineers the functionality of the iOS app commonly referred to as “Auto Health Export,” which appears (in current public documentation and store listings) as Health Auto Export – JSON+CSV. The app’s core value proposition is to export (and/or continuously sync) a large catalog of HealthKit-derived health metrics and workout-related data from iPhone/iPad, in JSON/CSV (and GPX for routes), either manually or via automations to multiple external destinations. 

The requested scope here is: (a) fully spec the data exports (schemas, flags, time grouping, versioning), (b) fully spec the automation/export destinations and triggers, and (c) structure the result so a coding agent can implement a clone with a modular “headless core + UI shell” architecture that supports rearranging or replacing the frontend. The one explicit deprioritization is Sync to Mac / desktop viewing; it is only noted in passing and is not expanded into a full spec.

Because this is an iOS HealthKit-derived system, the spec must treat “background schedules” as best-effort (system-controlled) and also treat “device locked” as a hard constraint for reading HealthKit data; this is both explicitly documented by the product docs and independently documented by the platform vendor. 

Functional surface area
Health Auto Export’s functionality can be decomposed into five user-facing subsystems: manual exports, automations, triggers, local network querying, and observability (logs/notifications).

Manual exports provide a configurable “export job” UI allowing the user to choose a date range, export format (CSV/JSON), export version (v1/v2), and then enable/disable and configure each data type. Date range presets include Today, Yesterday, Last 7/14/30/90 Days, and Custom start/end. Health metrics support time grouping at seconds/minutes/hours/days/weeks/months/years and a “Summarize Data” toggle (for JSON health metrics), while workouts support optional GPX route export and optional “workout metrics” time-series export, with per-workout time grouping at minutes or seconds when export version 2 is used. CSV exports generate multiple files (one per selected data type, plus per-workout metadata files and GPX route files if enabled), which are zipped if multiple outputs exist; JSON exports generate one JSON file plus optional GPX route files. Manual exports keep an “Export History” so prior exports can be re-shared. 

Automations are configurable workflows that run in the background when possible and export/sync data to a chosen destination. Public docs enumerate automation types including REST API, cloud storage options, MQTT, Home Assistant, Calendar, and a “Connect to Server” mode for local network querying/control. The docs also emphasize that iOS does not allow reliable “run at a specific time” background execution; instead, automations are opportunistic and also can be manually triggered in multiple ways. 

Triggering mechanisms exist beyond a background cadence. The product exposes: (a) a Home Screen widget that displays automation status and can manually trigger an automation; (b) a Shortcuts “Run Automation” action that can be bound to a “Time of Day” personal automation for more predictable schedules; and (c) in-app manual execution of a configured automation via a manual export test flow. 

Local network querying/control is presented as a TCP/MCP server feature: it runs a local network server (default port documented as 9000) and supports querying health data and automation control programmatically, but it requires the app to be in the foreground and is “currently unencrypted” in the vendor docs. The public reference implementation for desktop integration (TypeScript) requires that the phone and computer share a Wi‑Fi subnet and uses the phone’s IP address as a host parameter. 

Observability includes per-automation activity logs and configurable in-app notifications. For example, Google Drive automation docs expose two notification toggles (“Notify on Cache Update” and “Notify When Run”) and repeatedly reference Activity Logs as the primary debugging surface for HTTP status codes or cloud API errors. Troubleshooting docs also direct users to Activity Logs first and enumerate common failure modes (permissions, connectivity, URL validity, timeouts). 

How to Sync Apple Health Data to Google Drive — Manage and Export Apple  Health Data
HealthyApps
HealthyApps
HealthyApps

Data types and export schemas
The canonical output format for structured exports is JSON with a stable top-level structure: a single JSON object containing a data object with arrays per supported data type. The documented arrays are: metrics, workouts, stateOfMind, medications, symptoms, cycleTracking, ecg, and heartRateNotifications. The documented date-time format is yyyy-MM-dd HH:mm:ss Z (timezone offset included). 

Health metrics JSON schema is organized as an array of “metric objects,” each with a name, units, and a data array. Metric names are reported in snake_case (“Step Count” → step_count). Most metric data entries are { "qty": <Number>, "date": <timestamp> }, but the docs define special structures for specific metric families: Blood Pressure splits into systolic/diastolic; Heart Rate exports min/avg/max buckets; Sleep Analysis can be “aggregated” (a per-day structure with totals and phase durations plus bed/sleep windows) or “unaggregated” (segment-level data with startDate/endDate and a value phase label such as Core/REM/Deep/Asleep/etc.). Blood Glucose includes mealTime metadata; Sexual Activity encodes protection state counts; Handwashing/Toothbrushing have a categorical completion value; Insulin Delivery includes reason (Bolus/Basal). 

Workouts JSON schema is explicitly versioned. Version 2 is the “recommended” structure and uses a required core of { id, name, start, end, duration } plus a large set of optional fields (distance, speed, elevation, temperature/humidity, intensity, swimming-specific fields, heart rate summaries, time-series arrays, route data, and metadata). When “Include Workout Metrics” is enabled, many per-workout quantities are exported as arrays of { date, qty, units, source } time-series points. Heart rate has both a summary object and arrays for heartRateData and heartRateRecovery. Routes appear as arrays of latitude/longitude/altitude/course/etc. location points (and may also be exported as separate GPX files through the manual export setting). Version 1 is documented as a legacy format for existing workflows. 

Other supported data types have dedicated schemas:

Symptoms export as an array of { start, end, name, severity, userEntered, source }, with semantics for point-in-time vs duration-based symptoms based on whether start == end. 
Cycle Tracking exports as { start, end, name, value, isCycleStart? } with type-specific allowed values (e.g., Menstrual Flow values and other reproductive-health tracking types). 
ECG exports as { start, end, classification, severity, averageHeartRate, numberOfVoltageMeasurements, voltageMeasurements[], samplingFrequency, source }, with voltageMeasurements including millisecond timestamps. 
Heart Rate Notifications export as { start, end, threshold?, heartRate[], heartRateVariation[] } where each heart rate point includes an interval-annotated timestamp; threshold is present for high/low notifications and absent for irregular rhythm events. 
Medications export as { displayText, nickname?, start, end?, scheduledDate?, form, status, isArchived, dosage?, codings[] } with codings including RxNorm systems in examples; the docs also state this data type is only available on iOS 26.0+ in their current documentation set. 
State of Mind exports as { id, start, end, kind, labels[], associations[], valence, valenceClassification, metadata } and is documented as iOS 18.0+ in the same doc set. 
The app also documents a large catalog of supported “Health Metrics” and shows category groupings (Activity Metrics, Body Measurements, Cardiovascular, Sleep, Nutrition, Environmental, etc.) and also enumerates workout-related metrics and route/GPX support. This list is important for implementing a clone because it defines the checklist of HealthKit types to map into exportable “MetricName” identifiers and transforms. 

Unit handling is user-configurable: unit preferences can be stored per metric and affect both manual and automated exports. JSON exports carry units inline at each value, while CSV exports are described as annotating units in column headers (e.g., Active Energy (kcal)). 

Export destinations and integration semantics
A clone needs a single internal concept: Automation = (data selection + export format + date period + cadence + destination adapter + delivery policy). The public docs show that many settings are shared across destinations, with destination-specific auth/config layered on top. 

Cloud storage automations
For Dropbox, the automation flow uses an authorization redirect and a “copy the code back into the app” step. The docs emphasize least-privilege behavior: the app requests access to create/manage files “in its own folder” and does not access the entire account, and Activity Logs are used to debug token refresh and storage-quota issues. 

For Google Drive, the docs specify an OAuth-style “Connect Google” authorization flow and then a folder scheme: the app creates a root folder named “Health Auto Export” and then creates subfolders based on a user-configured folder name. Files are organized and named based on the chosen date range grouping and saved under that folder. CSV format can optionally be “Convert to Google Sheet,” which turns CSV uploads into Sheets for easier viewing/collaboration, and Activity Logs are referenced for HTTP status codes and Google API error messages. 

For iCloud Drive, the docs state that no special authentication is required beyond being signed into iCloud with iCloud Drive enabled. File output location is explicitly documented as iCloud Drive > Health Auto Export > {automation_name}/. The guide also repeatedly references Activity Logs for save failures and notes real-world operational constraints (device charging/unlocked behavior affects how frequently background actions can run).

REST API automations
REST API automations are the “webhook” path: send data via HTTP POST to a configured URL, with configurable request timeout and arbitrary custom HTTP headers for authentication/metadata. Export format supports JSON or CSV; docs in multiple locales state that Content-Type is automatically set to application/json for JSON exports and multipart/form-data for CSV exports. 

The docs also state that the app automatically adds headers including automation-name, automation-id, automation-aggregation, automation-period, and a per-request session-id (useful for idempotency/correlation on the receiving side). 

Date-period semantics are surfaced in multiple places (manual export and deep link): the period presets include a default behavior, “Since last sync,” Today, Yesterday, Previous 7 Days, and a “Realtime” mode (with extra constraints) for REST API automations created via deep links. 

Batching is an explicit delivery option for REST API + JSON: deep link documentation defines batchrequests=true as “send data in batches over multiple requests,” intended to avoid single oversized payloads; constraints are enforced (only valid for REST API with JSON). 

MQTT automations
MQTT automations publish the standard JSON export payload to a configured topic. The docs specify QoS “at most once delivery,” retain disabled (messages are not retained), and a JSON payload matching the standard export structure.

Home Assistant automations
Home Assistant automations are described as syncing health metrics as sensor states. The docs show setup via a Long-Lived Access Token and also describe an entity ID naming convention hae.{automation_name} (lowercase, no spaces) and troubleshooting around naming and token/header configuration. 

Calendar automation
Calendar automation creates (and later updates) calendar events based on the selected data type/time period. The docs state that events are updated by matching an “event key,” new events are created when no match exists, and events are not deleted automatically. When “Workouts” is selected, the configuration includes route inclusion toggles and a “Include Workout Metrics” toggle; for v2 exports, workout metric time grouping is minutes or seconds. 

Widget, Shortcuts, and deep link config as integration surfaces
The Automations widget displays a single automation per widget instance, shows last-run date/time with status colors/icons, refreshes approximately every ~20 minutes (subject to iOS scheduling), and can manually trigger an automation by tapping. The docs also explicitly note that because the widget accesses health data it only refreshes when the device is unlocked. 

Shortcuts integration is a first-class scheduling surface: the docs describe a “Run Automation” Shortcuts action which can be scheduled via a Time-of-Day trigger. The docs claim this is “more predictable” than background cadence alone, but also require the device be unlocked at trigger time for HealthKit access. 

Deep link automation is a configuration interface that programmatically creates REST API automations. The documented base scheme is com.HealthExport://automation and required parameters are name and url; parameters are case-insensitive and can set export format, data type, period, aggregation, export version, workout flags, HTTP headers, timeouts, batching, notifications, and enablement state. The docs also specify validation rules and precedence (e.g., period=realtime requires syncinterval=seconds, and CSV implies aggregation). 

Platform constraints that dominate the spec
A correct clone must be engineered around platform constraints, not just UI. The two load-bearing constraints are HealthKit data protection and iOS background execution policy.

HealthKit data is encrypted at rest and can be unreadable while the device is locked. Apple’s developer documentation explicitly defines errorDatabaseInaccessible as occurring when an app queries HealthKit while the device is locked.  Apple’s HealthKit privacy guidance similarly explains that the system encrypts the HealthKit store when the user locks the device, and apps may not be able to read data at that time.  Apple’s platform security documentation adds a concrete operational detail: Health data is stored under a Data Protection class where access is relinquished ~10 minutes after lock and becomes accessible again after user authentication, with some special cases during an active workout session. 

Background execution cannot be treated as cron. Apple’s own developer forums state there is no general-purpose mechanism for running arbitrary code at a specific time or guaranteed interval in the background; background execution is discretionary and must use supported mechanisms (BGTaskScheduler classes, background URLSession, background notifications, etc.).  The product’s own automations guide mirrors this: it says iOS does not allow apps to run “at a specified time,” and background execution is system-determined; it then points users to widgets and Shortcuts as manual/assisted triggers. 

HealthKit background delivery is relevant for a “sync when data changes” architecture, but it has explicit entitlement requirements and still doesn’t override the encryption/lock constraint. Apple documents that HealthKit background delivery requires the specific entitlement for iOS 15+ and is enabled via enableBackgroundDelivery(for:frequency:withCompletion:); observer queries are the recommended mechanism to be notified of changes and to wake the app. 

Finally, export performance can be bounded by device memory and processing time. The manual export docs explicitly warn that large date ranges or second/minute-level aggregation can exceed memory limits and crash the app, and recommend mitigating by reducing date range, selected data types, and/or granularity. 

A spec blueprint a coding agent can implement in a few cycles
This section converts the reverse-engineered behavior into a buildable spec for an agent, with explicit interfaces and acceptance criteria. It is written to support a “headless core” so you can later replace or rearrange UI freely.

Core domain model
Define these core types (names are illustrative; choose Swift naming conventions):

ExportDataType: healthMetrics | workouts | symptoms | cycleTracking | ecg | heartRateNotifications | medications | stateOfMind. 
ExportFormat: json | csv (plus gpx as an auxiliary output for workout routes). 
ExportVersion: v1 | v2 (v2 is default/recommended; workouts v1 remains for compatibility). 
ExportPeriod (date preset): default | lastsync | today | yesterday | previous7days | realtime. 
TimeGroupingInterval: none | seconds | minutes | hours | days | weeks | months | years for health metrics; and minutes | seconds for workout metadata time-grouping when v2 + includeWorkoutMetrics. 
AutomationDestinationType: restApi | dropbox | googleDrive | iCloudDrive | mqtt | homeAssistant | calendar. 
Represent an Automation as:

AutomationID (UUID)
name (string)
enabled (bool) 
destination: DestinationConfig
dataType: ExportDataType
selection: DataSelection
For healthMetrics: optional metricsAllowList where metric names are the UI “raw values” (e.g., “Step Count”, “Heart Rate”), matching deep link docs. 
For workouts: workout-type allow-list (not exhaustively documented in the help center pages we captured here, but “select workouts” is part of manual export). 
exportSettings: ExportSettings
format, exportVersion, period
For health metrics JSON: aggregateData and aggregateSleep semantics (doc indicates aggregation behavior varies by format and metric type). 
interval/time grouping (health metrics) and workout metadata grouping (workouts + v2). 
syncCadence (quantity + unit), with explicit support for “seconds cadence” only as a special case for realtime. 
deliveryPolicy
REST API JSON: batchRequests (bool); request timeout; headers.
destination-level retry/backoff strategy (not explicitly documented, but required for robustness)
Export engine architecture
Implement a “core export pipeline” independent of UI:

HealthDataReadService: reads HealthKit data for a requested (dataType, selection, date range, aggregation settings).
Aggregator: applies time grouping and any “summarize”/aggregation rules (especially health metrics and sleep).
Serializer:
JSON serializer must emit the documented top-level schema and per-type schemas. 
CSV serializer must at minimum obey: (a) data are always aggregated when CSV is used with multiple metrics, and (b) units appear in headers. 
GPX serializer produces per-workout route GPX when enabled. 
DestinationAdapters implement a single interface, e.g. deliver(exportArtifacts, automationContext) -> DeliveryResult:
REST API adapter: POST with headers, timeout, JSON vs multipart for CSV, plus built-in header injection for automation/session metadata.
Cloud adapters: write files to destination folder structures and naming rules, including the root Health Auto Export folder semantics where documented. 
MQTT adapter: publish JSON to configured topic with QoS0/retain false. 
Home Assistant adapter: send metric values to entity IDs per naming convention. 
Calendar adapter: create/update events by event key; never auto-delete. 
StateStore: stores last successful run timestamps per automation (required for period=lastsync). 
ActivityLogService: append per-run metadata (timestamp, success/failure, error details, request IDs). 
Triggering and scheduling spec
Your clone needs three trigger classes, each mapped to iOS realities:

Interactive triggers: manual export button, widget tap, and an in-app “manual test” for each automation. 
Shortcuts trigger: expose a Shortcuts action “Run Automation” to trigger a selected automation; expected UX is that users can create a Time-of-Day automation in the Shortcuts app, and the spec should document the “device must be unlocked” requirement because HealthKit reads may fail when locked. 
Best-effort background cadence: implement BGTaskScheduler-based scheduling for periodic attempts, but treat it as opportunistic; schedule should be stored as “desired cadence,” not as guaranteed execution time. The product’s docs and Apple’s docs agree that exact-time scheduling is not supported. 
Local network server spec
If duplicating the “Connect to Server” feature:

Implement a local TCP server (default port 9000) that is explicitly foreground-only, and treat encryption/authentication as part of your own design (the product docs call their current design “unencrypted”). 
Minimum RPC surface area to match docs: query health data, run automations, and return structured data. 
Provide a developer-facing “client example” concept similar to the public TypeScript example that connects to a phone-hosted server on the same Wi‑Fi and uses a host/IP environment setting. 
Acceptance criteria
A coding agent can implement this in “few cycles” if you enforce narrow, testable slices. The acceptance checks below are derived directly from public schemas and documented behavior.

JSON export golden tests: for each data type, generate exports and validate against the documented field sets and structural rules (data wrapper, date formats, special-case metrics, workouts v2 optionality). 
Manual export packaging: CSV → multiple files per enabled data type; include workout-metrics files when enabled; include per-workout GPX files when enabled; zip multi-file exports; persist export history. 
Google Drive file placement: root folder “Health Auto Export” plus automation-named subfolder, file names based on date range grouping; optional CSV→Sheets conversion flag. 
iCloud Drive file placement: iCloud Drive > Health Auto Export > {automation_name}/. 
REST API request behavior: POST with custom headers; automatic Content-Type selection (application/json vs multipart/form-data); automatic inclusion of automation/session headers; batch requests only valid for JSON. 
MQTT publish behavior: JSON payload uses the standard export format; QoS0 and retain false. 
Widget UX minimum: show enabled/disabled/error states, last-run timestamp, manual trigger; note that refresh only occurs when unlocked.
What is not fully specified from public docs alone
Two aspects are only partially recoverable from the public docs captured here and would require either (a) observing real outputs from the live app or (b) deeper inspection of their open-source tooling docs:

Exact CSV schemas per data type (column sets, wide vs long layout) are described at a high level (multi-file, aggregation rules, units in headers) but not exhaustively enumerated for every data type. 
Exact multipart/form-data field names and multi-file mapping for REST API CSV exports are described at the level of Content-Type, but not at the level of “form part names” and “one request vs multiple requests for multiple files.” 
If you want a coding agent to match byte-for-byte CSV and REST CSV delivery semantics, treat those as an explicit “capture + lock” task: generate exports from the reference app across representative configurations and turn the results into golden fixtures.

Brief note on Mac sync
Sync-to-Mac exists as a separate system meant to propagate health metrics and workouts to desktop and to support desktop views/dashboards, but it is excluded from this spec per your request. 
