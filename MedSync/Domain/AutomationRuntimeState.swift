import Foundation

struct AutomationRuntimeState: Codable, Equatable, Sendable {
    struct ScheduledRun: Codable, Equatable, Sendable {
        var automationID: UUID
        var lastAttemptAt: Date
    }

    struct PendingMedicationTrigger: Codable, Equatable, Sendable {
        var automation: Automation
        var queryAnchorData: Data
        var triggeringEventIDs: [UUID]
        var createdAt: Date
    }

    struct ProcessedMedicationTriggerEvent: Codable, Equatable, Sendable {
        var eventID: UUID
        var processedAt: Date
    }

    static let processedMedicationTriggerRetention: TimeInterval = 60 * 60 * 24 * 30

    var scheduledRuns: [ScheduledRun] = []
    var medicationQueryAnchorData: Data?
    var pendingMedicationTrigger: PendingMedicationTrigger?
    var processedMedicationTriggerEvents: [ProcessedMedicationTriggerEvent] = []

    func lastScheduledAttempt(for automationID: UUID) -> Date? {
        scheduledRuns.first(where: { $0.automationID == automationID })?.lastAttemptAt
    }

    mutating func recordScheduledAttempt(for automationID: UUID, at date: Date) {
        if let index = scheduledRuns.firstIndex(where: { $0.automationID == automationID }) {
            scheduledRuns[index].lastAttemptAt = date
        } else {
            scheduledRuns.append(ScheduledRun(automationID: automationID, lastAttemptAt: date))
        }
    }

    func hasProcessedMedicationTriggerEvent(_ eventID: UUID) -> Bool {
        processedMedicationTriggerEvents.contains(where: { $0.eventID == eventID })
    }

    mutating func advanceMedicationQueryAnchor(_ anchorData: Data, referenceDate: Date) {
        medicationQueryAnchorData = anchorData
        pruneProcessedMedicationTriggerEvents(referenceDate: referenceDate)
    }

    mutating func stageMedicationTrigger(_ pendingTrigger: PendingMedicationTrigger) {
        pendingMedicationTrigger = PendingMedicationTrigger(
            automation: pendingTrigger.automation,
            queryAnchorData: pendingTrigger.queryAnchorData,
            triggeringEventIDs: normalizedMedicationEventIDs(pendingTrigger.triggeringEventIDs),
            createdAt: pendingTrigger.createdAt
        )
    }

    mutating func commitPendingMedicationTrigger(processedAt: Date) {
        guard let pendingMedicationTrigger else {
            return
        }

        medicationQueryAnchorData = pendingMedicationTrigger.queryAnchorData
        recordProcessedMedicationTriggerEvents(
            pendingMedicationTrigger.triggeringEventIDs,
            processedAt: processedAt
        )
        self.pendingMedicationTrigger = nil
    }

    mutating func recordProcessedMedicationTriggerEvents(_ eventIDs: [UUID], processedAt: Date) {
        let normalizedEventIDs = normalizedMedicationEventIDs(eventIDs)
        let normalizedSet = Set(normalizedEventIDs)

        processedMedicationTriggerEvents.removeAll { normalizedSet.contains($0.eventID) }
        processedMedicationTriggerEvents.append(
            contentsOf: normalizedEventIDs.map {
                ProcessedMedicationTriggerEvent(eventID: $0, processedAt: processedAt)
            }
        )
        processedMedicationTriggerEvents.sort { lhs, rhs in
            if lhs.processedAt == rhs.processedAt {
                return lhs.eventID.uuidString < rhs.eventID.uuidString
            }
            return lhs.processedAt > rhs.processedAt
        }
        pruneProcessedMedicationTriggerEvents(referenceDate: processedAt)
    }

    mutating func pruneProcessedMedicationTriggerEvents(referenceDate: Date) {
        let cutoff = referenceDate.addingTimeInterval(-Self.processedMedicationTriggerRetention)
        processedMedicationTriggerEvents.removeAll { $0.processedAt < cutoff }
    }

    mutating func removeState(for automationIDs: Set<UUID>) {
        scheduledRuns.removeAll { automationIDs.contains($0.automationID) }
        if let pendingMedicationTrigger, automationIDs.contains(pendingMedicationTrigger.automation.id) {
            self.pendingMedicationTrigger = nil
        }
    }

    private func normalizedMedicationEventIDs(_ eventIDs: [UUID]) -> [UUID] {
        Array(Set(eventIDs)).sorted { $0.uuidString < $1.uuidString }
    }
}

extension AutomationRuntimeState {
    private enum CodingKeys: String, CodingKey {
        case scheduledRuns
        case medicationQueryAnchorData
        case pendingMedicationTrigger
        case processedMedicationTriggerEvents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.scheduledRuns = try container.decodeIfPresent([ScheduledRun].self, forKey: .scheduledRuns) ?? []
        self.medicationQueryAnchorData = try container.decodeIfPresent(Data.self, forKey: .medicationQueryAnchorData)
        self.pendingMedicationTrigger = try container.decodeIfPresent(
            PendingMedicationTrigger.self,
            forKey: .pendingMedicationTrigger
        )
        self.processedMedicationTriggerEvents = try container.decodeIfPresent(
            [ProcessedMedicationTriggerEvent].self,
            forKey: .processedMedicationTriggerEvents
        ) ?? []
    }
}

enum AutomationSchedulePlanner {
    static func nextDueDate(
        for automation: Automation,
        runtimeState: AutomationRuntimeState,
        calendar: Calendar = .current
    ) -> Date? {
        guard automation.isEnabled, let cadence = automation.trigger.scheduledCadence else {
            return nil
        }

        let baseDate = runtimeState.lastScheduledAttempt(for: automation.id) ?? automation.createdAt
        return calendar.date(byAdding: cadence.dateComponents, to: baseDate)
    }

    static func dueAutomations(
        from automations: [Automation],
        runtimeState: AutomationRuntimeState,
        now: Date,
        calendar: Calendar = .current
    ) -> [Automation] {
        automations
            .filter { automation in
                guard let nextDueDate = nextDueDate(for: automation, runtimeState: runtimeState, calendar: calendar) else {
                    return false
                }
                return nextDueDate <= now
            }
            .sorted { lhs, rhs in
                let lhsDue = nextDueDate(for: lhs, runtimeState: runtimeState, calendar: calendar) ?? .distantFuture
                let rhsDue = nextDueDate(for: rhs, runtimeState: runtimeState, calendar: calendar) ?? .distantFuture
                return lhsDue < rhsDue
            }
    }

    static func nextRefreshDate(
        from automations: [Automation],
        runtimeState: AutomationRuntimeState,
        calendar: Calendar = .current
    ) -> Date? {
        automations
            .compactMap { nextDueDate(for: $0, runtimeState: runtimeState, calendar: calendar) }
            .min()
    }
}

private extension ScheduledCadence {
    var dateComponents: DateComponents {
        switch unit {
        case .minutes:
            DateComponents(minute: every)
        case .hours:
            DateComponents(hour: every)
        case .days:
            DateComponents(day: every)
        case .weeks:
            DateComponents(day: every * 7)
        }
    }
}
