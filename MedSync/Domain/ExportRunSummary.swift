import Foundation

enum ExportRequest: Equatable, Sendable {
    case manual(MedicationExportOptions)
    case automation(Automation, triggerReason: TriggerReason)

    var exportOptions: MedicationExportOptions {
        switch self {
        case let .manual(options):
            options
        case let .automation(automation, _):
            automation.exportOptions
        }
    }

    var triggerReason: TriggerReason {
        switch self {
        case .manual:
            .manualExport
        case let .automation(_, triggerReason):
            triggerReason
        }
    }

    var automation: Automation? {
        guard case let .automation(automation, _) = self else { return nil }
        return automation
    }
}

struct ExportRunSummary: Equatable, Sendable {
    var filename: String
    var relativePath: String
    var recordCount: Int
    var destination: ExportDestinationKind
    var format: ExportFormat
    var dateRangePreset: DateRangePreset
    var dateRange: ClosedRange<Date>
    var triggerReason: TriggerReason
    var automationID: UUID?
    var automationName: String?
}

