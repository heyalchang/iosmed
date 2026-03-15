import Foundation

struct AutomationRuntimeState: Codable, Equatable, Sendable {
    struct ScheduledRun: Codable, Equatable, Sendable {
        var automationID: UUID
        var lastAttemptAt: Date
    }

    var scheduledRuns: [ScheduledRun] = []
    var medicationQueryAnchorData: Data?

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

    mutating func removeState(for automationIDs: Set<UUID>) {
        scheduledRuns.removeAll { automationIDs.contains($0.automationID) }
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
