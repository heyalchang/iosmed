import Foundation

enum TriggerReason: String, Codable, Equatable, Sendable, CaseIterable {
    case manualExport
    case runNow
    case runAll
    case scheduledBackground
    case shortcuts
    case medicationTriggerBackgroundDelivery

    var displayName: String {
        switch self {
        case .manualExport: "Manual Export"
        case .runNow: "Run Now"
        case .runAll: "Run All"
        case .scheduledBackground: "Scheduled / Background"
        case .shortcuts: "Shortcuts"
        case .medicationTriggerBackgroundDelivery: "Medication Trigger / Background Delivery"
        }
    }
}

enum CadenceUnit: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case minutes
    case hours
    case days
    case weeks

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

struct ScheduledCadence: Codable, Equatable, Sendable {
    var every: Int
    var unit: CadenceUnit

    init(every: Int = 1, unit: CadenceUnit = .hours) {
        self.every = min(max(every, 1), 5)
        self.unit = unit
    }

    var displayName: String {
        "Every \(every) \(unit.rawValue)"
    }
}

enum MedicationBackgroundDeliveryFrequency: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case immediate
    case hourly
    case daily

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

enum AutomationTrigger: Codable, Equatable, Sendable {
    case schedule(ScheduledCadence)
    case medicationTaken(MedicationBackgroundDeliveryFrequency)

    var displayName: String {
        switch self {
        case let .schedule(cadence):
            cadence.displayName
        case let .medicationTaken(frequency):
            "Medication Taken (\(frequency.displayName))"
        }
    }

    var medicationFrequency: MedicationBackgroundDeliveryFrequency? {
        guard case let .medicationTaken(frequency) = self else { return nil }
        return frequency
    }

    var scheduledCadence: ScheduledCadence? {
        guard case let .schedule(cadence) = self else { return nil }
        return cadence
    }
}

struct Automation: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var notifyWhenRun: Bool
    var exportOptions: MedicationExportOptions
    var trigger: AutomationTrigger
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        notifyWhenRun: Bool = false,
        exportOptions: MedicationExportOptions = MedicationExportOptions(),
        trigger: AutomationTrigger = .schedule(ScheduledCadence()),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.notifyWhenRun = notifyWhenRun
        self.exportOptions = exportOptions
        self.trigger = trigger
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct AutomationDraft: Equatable, Sendable {
    enum TriggerMode: String, CaseIterable, Equatable, Sendable, Identifiable {
        case schedule
        case medicationTaken

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .schedule: "Scheduled"
            case .medicationTaken: "Medication Taken"
            }
        }
    }

    var id: UUID?
    var name: String = ""
    var isEnabled: Bool = true
    var notifyWhenRun: Bool = false
    var exportOptions: MedicationExportOptions = MedicationExportOptions()
    var triggerMode: TriggerMode = .schedule
    var cadenceEvery: Int = 1
    var cadenceUnit: CadenceUnit = .hours
    var medicationFrequency: MedicationBackgroundDeliveryFrequency = .immediate
    var createdAt: Date?

    init() {}

    init(automation: Automation) {
        id = automation.id
        name = automation.name
        isEnabled = automation.isEnabled
        notifyWhenRun = automation.notifyWhenRun
        exportOptions = automation.exportOptions
        createdAt = automation.createdAt

        switch automation.trigger {
        case let .schedule(cadence):
            triggerMode = .schedule
            cadenceEvery = cadence.every
            cadenceUnit = cadence.unit
        case let .medicationTaken(frequency):
            triggerMode = .medicationTaken
            medicationFrequency = frequency
        }
    }

    func makeAutomation(now: Date) -> Automation {
        Automation(
            id: id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: isEnabled,
            notifyWhenRun: notifyWhenRun,
            exportOptions: exportOptions,
            trigger: triggerMode == .schedule
                ? .schedule(ScheduledCadence(every: cadenceEvery, unit: cadenceUnit))
                : .medicationTaken(medicationFrequency),
            createdAt: createdAt ?? now,
            updatedAt: now
        )
    }
}
