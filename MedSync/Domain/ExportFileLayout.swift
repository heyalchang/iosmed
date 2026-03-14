import Foundation

struct ExportFilePlan: Equatable, Sendable {
    var relativeDirectory: String
    var filename: String

    var relativePath: String {
        "\(relativeDirectory)/\(filename)"
    }
}

enum ExportFileLayout {
    static let rootFolderName = "MedSync"

    static var destinationDescription: String {
        ExportDestinationKind.iCloudDrive.displayName
    }

    static func plan(for request: ExportRequest, executedAt: Date, runID: UUID = UUID()) -> ExportFilePlan {
        let month = MedSyncDateFormatter.monthDirectory(from: executedAt)
        let timestamp = MedSyncDateFormatter.filenameTimestamp(from: executedAt)
        let suffix = String(runID.uuidString.prefix(8)).lowercased()
        let filenamePrefix: String
        let subdirectory: String

        switch request {
        case .manual:
            filenamePrefix = "medications-manual-export"
            subdirectory = "\(rootFolderName)/Manual Exports/\(month)"
        case let .automation(automation, _):
            filenamePrefix = "medications-\(slug(automation.name))"
            subdirectory = "\(rootFolderName)/Automations/\(slug(automation.name))/\(month)"
        }

        return ExportFilePlan(
            relativeDirectory: subdirectory,
            filename: "\(filenamePrefix)-\(timestamp)-\(suffix).\(request.exportOptions.format.fileExtension)"
        )
    }

    static func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let collapsed = value
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "-")
        let filteredScalars = collapsed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let filtered = String(filteredScalars)
        let squashed = filtered.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        return squashed.trimmingCharacters(in: CharacterSet(charactersIn: "-")).isEmpty ? "automation" : squashed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

enum MedSyncDateFormatter {
    static func exportString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withTimeZone]
        return formatter.string(from: date)
    }

    static func exportDate(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withTimeZone]
        return formatter.date(from: string)
    }

    static func filenameTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd'T'HHmmssZ"
        return formatter.string(from: date)
    }

    static func monthDirectory(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}

extension JSONEncoder {
    static var medSync: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(MedSyncDateFormatter.exportString(from: date))
        }
        return encoder
    }
}

extension JSONDecoder {
    static var medSync: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            guard let date = MedSyncDateFormatter.exportDate(from: rawValue) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(rawValue)")
            }
            return date
        }
        return decoder
    }
}
