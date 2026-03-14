import Foundation

enum ExportFormat: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case csv
    case json

    var id: String { rawValue }

    var displayName: String {
        rawValue.uppercased()
    }

    var fileExtension: String {
        rawValue
    }
}

enum TimeGrouping: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case minutes
    case hours
    case days
    case weeks
    case months
    case years

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minutes: "Minutes"
        case .hours: "Hours"
        case .days: "Days"
        case .weeks: "Weeks"
        case .months: "Months"
        case .years: "Years"
        }
    }
}

enum DateRangePreset: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case lastDay
    case lastWeek
    case lastTwoWeeks
    case lastMonth
    case last90Days
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lastDay: "Last Day"
        case .lastWeek: "Last Week"
        case .lastTwoWeeks: "Last Two Weeks"
        case .lastMonth: "Last Month"
        case .last90Days: "Last 90 Days"
        case .custom: "Custom"
        }
    }

    fileprivate var dayCount: Int? {
        switch self {
        case .lastDay: 1
        case .lastWeek: 7
        case .lastTwoWeeks: 14
        case .lastMonth: 30
        case .last90Days: 90
        case .custom: nil
        }
    }
}

struct ExportDateRange: Codable, Equatable, Sendable {
    var preset: DateRangePreset
    var customStart: Date
    var customEnd: Date

    init(
        preset: DateRangePreset = .lastWeek,
        customStart: Date = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now,
        customEnd: Date = .now
    ) {
        self.preset = preset
        self.customStart = customStart
        self.customEnd = customEnd
    }

    func resolved(now: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        if preset == .custom {
            let start = min(customStart, customEnd)
            let end = max(customStart, customEnd)
            return start...end
        }

        let dayCount = preset.dayCount ?? 1
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: now) ?? now
        return start...now
    }
}

struct MedicationExportOptions: Codable, Equatable, Sendable {
    var dateRange: ExportDateRange
    var format: ExportFormat
    var timeGrouping: TimeGrouping

    init(
        dateRange: ExportDateRange = ExportDateRange(),
        format: ExportFormat = .json,
        timeGrouping: TimeGrouping = .days
    ) {
        self.dateRange = dateRange
        self.format = format
        self.timeGrouping = timeGrouping
    }
}

enum ExportDestinationKind: String, Codable, Equatable, Sendable {
    case iCloudDrive

    var displayName: String {
        switch self {
        case .iCloudDrive:
            "Files > iCloud Drive > MedSync"
        }
    }
}
