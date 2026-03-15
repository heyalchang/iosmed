import XCTest
@testable import MedSync

final class AutomationSchedulePlannerTests: XCTestCase {
    func testNextDueDateUsesLastScheduledAttemptWhenAvailable() {
        let createdAt = ISO8601DateFormatter().date(from: "2026-03-14T08:00:00-07:00")!
        let lastAttempt = ISO8601DateFormatter().date(from: "2026-03-14T09:30:00-07:00")!
        let automation = Automation(
            name: "Morning Export",
            trigger: .schedule(ScheduledCadence(every: 2, unit: .hours)),
            createdAt: createdAt,
            updatedAt: createdAt
        )
        var runtimeState = AutomationRuntimeState()
        runtimeState.recordScheduledAttempt(for: automation.id, at: lastAttempt)

        let nextDueDate = AutomationSchedulePlanner.nextDueDate(
            for: automation,
            runtimeState: runtimeState,
            calendar: Calendar(identifier: .gregorian)
        )

        XCTAssertEqual(
            nextDueDate,
            ISO8601DateFormatter().date(from: "2026-03-14T11:30:00-07:00")!
        )
    }

    func testDueAutomationsOnlyIncludesEnabledScheduledAutomations() {
        let createdAt = ISO8601DateFormatter().date(from: "2026-03-14T08:00:00-07:00")!
        let dueAutomation = Automation(
            name: "Due Export",
            trigger: .schedule(ScheduledCadence(every: 1, unit: .hours)),
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let futureAutomation = Automation(
            name: "Future Export",
            trigger: .schedule(ScheduledCadence(every: 4, unit: .hours)),
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let medicationTrigger = Automation(
            name: "Medication Trigger",
            trigger: .medicationTaken(.immediate),
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let disabledAutomation = Automation(
            name: "Disabled Export",
            isEnabled: false,
            trigger: .schedule(ScheduledCadence(every: 1, unit: .hours)),
            createdAt: createdAt,
            updatedAt: createdAt
        )

        let due = AutomationSchedulePlanner.dueAutomations(
            from: [futureAutomation, medicationTrigger, disabledAutomation, dueAutomation],
            runtimeState: AutomationRuntimeState(),
            now: ISO8601DateFormatter().date(from: "2026-03-14T10:30:00-07:00")!,
            calendar: Calendar(identifier: .gregorian)
        )

        XCTAssertEqual(due.map(\.name), ["Due Export"])
    }

    func testNextRefreshDateReturnsEarliestDueDateAcrossAutomations() {
        let createdAt = ISO8601DateFormatter().date(from: "2026-03-14T08:00:00-07:00")!
        let hourly = Automation(
            name: "Hourly",
            trigger: .schedule(ScheduledCadence(every: 1, unit: .hours)),
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let dailyish = Automation(
            name: "Later",
            trigger: .schedule(ScheduledCadence(every: 5, unit: .hours)),
            createdAt: createdAt,
            updatedAt: createdAt
        )

        let nextRefreshDate = AutomationSchedulePlanner.nextRefreshDate(
            from: [dailyish, hourly],
            runtimeState: AutomationRuntimeState(),
            calendar: Calendar(identifier: .gregorian)
        )

        XCTAssertEqual(
            nextRefreshDate,
            ISO8601DateFormatter().date(from: "2026-03-14T09:00:00-07:00")!
        )
    }
}
