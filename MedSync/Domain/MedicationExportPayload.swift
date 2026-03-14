import Foundation

enum MedicationLogStatus: String, Codable, Equatable, Sendable {
    case notInteracted
    case notificationNotSent
    case snoozed
    case taken
    case skipped
    case notLogged
}

enum MedicationScheduleType: String, Codable, Equatable, Sendable {
    case asNeeded
    case scheduled
}

struct MedicationCoding: Codable, Equatable, Sendable {
    var system: String
    var version: String?
    var code: String
}

struct MedicationIdentity: Codable, Equatable, Sendable {
    var displayText: String
    var nickname: String?
    var hasSchedule: Bool
    var isArchived: Bool
    var generalForm: String
    var codings: [MedicationCoding]
}

struct MedicationExportRecord: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var startDate: Date
    var endDate: Date
    var logStatus: MedicationLogStatus
    var scheduleType: MedicationScheduleType
    var scheduledDate: Date?
    var doseQuantity: Double?
    var scheduledDoseQuantity: Double?
    var unit: String
    var medication: MedicationIdentity
}

struct MedicationExportPayload: Codable, Equatable, Sendable {
    struct ExportDateRangeSummary: Codable, Equatable, Sendable {
        var preset: DateRangePreset
        var start: Date
        var end: Date
    }

    struct PayloadData: Codable, Equatable, Sendable {
        var medications: [MedicationExportRecord]
    }

    var schemaVersion: Int
    var exportedAt: Date
    var exportType: String
    var dateRange: ExportDateRangeSummary
    var data: PayloadData

    init(exportedAt: Date, dateRange: ClosedRange<Date>, preset: DateRangePreset, medications: [MedicationExportRecord]) {
        schemaVersion = 1
        self.exportedAt = exportedAt
        exportType = "medications"
        self.dateRange = ExportDateRangeSummary(preset: preset, start: dateRange.lowerBound, end: dateRange.upperBound)
        data = PayloadData(medications: medications)
    }
}

enum MedicationExportSerializer {
    static func serialize(_ payload: MedicationExportPayload, as format: ExportFormat) throws -> Data {
        switch format {
        case .json:
            let encoder = JSONEncoder.medSync
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(payload)
        case .csv:
            return Data(csvString(for: payload).utf8)
        }
    }

    static func csvString(for payload: MedicationExportPayload) -> String {
        let headers = [
            "id",
            "startDate",
            "endDate",
            "logStatus",
            "scheduleType",
            "scheduledDate",
            "doseQuantity",
            "scheduledDoseQuantity",
            "unit",
            "displayText",
            "nickname",
            "hasSchedule",
            "isArchived",
            "generalForm",
            "codings"
        ]

        let rows = payload.data.medications.map { record -> String in
            let row: [String] = [
                escape(record.id),
                escape(MedSyncDateFormatter.exportString(from: record.startDate)),
                escape(MedSyncDateFormatter.exportString(from: record.endDate)),
                escape(record.logStatus.rawValue),
                escape(record.scheduleType.rawValue),
                escape(record.scheduledDate.map { MedSyncDateFormatter.exportString(from: $0) } ?? ""),
                escape(string(from: record.doseQuantity)),
                escape(string(from: record.scheduledDoseQuantity)),
                escape(record.unit),
                escape(record.medication.displayText),
                escape(record.medication.nickname ?? ""),
                escape(String(record.medication.hasSchedule)),
                escape(String(record.medication.isArchived)),
                escape(record.medication.generalForm),
                escape(record.medication.codings.map { "\($0.system)|\($0.version ?? "")|\($0.code)" }.joined(separator: ";"))
            ]
            return row.joined(separator: ",")
        }

        return ([headers.joined(separator: ",")] + rows).joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func string(from value: Double?) -> String {
        guard let value else { return "" }
        return String(value)
    }
}
