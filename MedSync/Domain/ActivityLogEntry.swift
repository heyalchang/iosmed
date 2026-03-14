import Foundation

enum ActivityEventType: String, Codable, Equatable, Sendable {
    case manualExport
    case automationRun
    case automationLifecycle
}

enum ActivityStatus: String, Codable, Equatable, Sendable {
    case success
    case failure
    case info
}

struct ActivityLogEntry: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var eventType: ActivityEventType
    var automationID: UUID?
    var automationName: String?
    var triggerReason: TriggerReason?
    var status: ActivityStatus
    var timestamp: Date
    var format: ExportFormat?
    var dateRangePreset: DateRangePreset?
    var dateRangeStart: Date?
    var dateRangeEnd: Date?
    var destination: ExportDestinationKind?
    var filename: String?
    var errorDetails: String?
    var message: String?

    init(
        id: UUID = UUID(),
        eventType: ActivityEventType,
        automationID: UUID? = nil,
        automationName: String? = nil,
        triggerReason: TriggerReason? = nil,
        status: ActivityStatus,
        timestamp: Date,
        format: ExportFormat? = nil,
        dateRangePreset: DateRangePreset? = nil,
        dateRangeStart: Date? = nil,
        dateRangeEnd: Date? = nil,
        destination: ExportDestinationKind? = nil,
        filename: String? = nil,
        errorDetails: String? = nil,
        message: String? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.automationID = automationID
        self.automationName = automationName
        self.triggerReason = triggerReason
        self.status = status
        self.timestamp = timestamp
        self.format = format
        self.dateRangePreset = dateRangePreset
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.destination = destination
        self.filename = filename
        self.errorDetails = errorDetails
        self.message = message
    }
}

extension ActivityLogEntry {
    static func run(
        summary: ExportRunSummary,
        status: ActivityStatus = .success,
        errorDetails: String? = nil,
        timestamp: Date,
        message: String? = nil
    ) -> Self {
        ActivityLogEntry(
            eventType: summary.triggerReason == .manualExport ? .manualExport : .automationRun,
            automationID: summary.automationID,
            automationName: summary.automationName,
            triggerReason: summary.triggerReason,
            status: status,
            timestamp: timestamp,
            format: summary.format,
            dateRangePreset: summary.dateRangePreset,
            dateRangeStart: summary.dateRange.lowerBound,
            dateRangeEnd: summary.dateRange.upperBound,
            destination: summary.destination,
            filename: summary.filename,
            errorDetails: errorDetails,
            message: message ?? defaultRunMessage(triggerReason: summary.triggerReason, status: status)
        )
    }

    static func automationLifecycle(
        action: String,
        automation: Automation,
        timestamp: Date
    ) -> Self {
        ActivityLogEntry(
            eventType: .automationLifecycle,
            automationID: automation.id,
            automationName: automation.name,
            status: .info,
            timestamp: timestamp,
            format: automation.exportOptions.format,
            dateRangePreset: automation.exportOptions.dateRange.preset,
            destination: .iCloudDrive,
            message: action
        )
    }

    private static func defaultRunMessage(triggerReason: TriggerReason, status: ActivityStatus) -> String {
        let suffix: String
        switch status {
        case .success:
            suffix = "completed"
        case .failure:
            suffix = "failed"
        case .info:
            suffix = "updated"
        }

        switch triggerReason {
        case .manualExport:
            return "Manual export \(suffix)"
        case .runNow:
            return "Run Now export \(suffix)"
        case .runAll:
            return "Run All export \(suffix)"
        case .scheduledBackground:
            return "Scheduled export \(suffix)"
        case .shortcuts:
            return "Shortcuts export \(suffix)"
        case .medicationTriggerBackgroundDelivery:
            return "Medication-triggered export \(suffix)"
        }
    }
}
