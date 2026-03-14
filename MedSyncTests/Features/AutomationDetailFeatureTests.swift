import ComposableArchitecture
import XCTest
@testable import MedSync

@MainActor
final class AutomationDetailFeatureTests: XCTestCase {
    func testTaskLoadsScopedHistoryAndRuntimeScheduleStatus() async {
        let createdAt = ISO8601DateFormatter().date(from: "2026-03-14T08:00:00-07:00")!
        let lastAttempt = ISO8601DateFormatter().date(from: "2026-03-14T10:00:00-07:00")!
        let expectedNextRun = ISO8601DateFormatter().date(from: "2026-03-14T12:00:00-07:00")!

        let automation = Automation(
            name: "Morning Export",
            trigger: .schedule(ScheduledCadence(every: 2, unit: .hours)),
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let otherAutomation = Automation(name: "Other Export")
        let matchingEntry = ActivityLogEntry.automationLifecycle(
            action: "Created automation",
            automation: automation,
            timestamp: createdAt
        )
        let otherEntry = ActivityLogEntry.automationLifecycle(
            action: "Created automation",
            automation: otherAutomation,
            timestamp: createdAt.addingTimeInterval(60)
        )

        let store = TestStore(
            initialState: AutomationDetailFeature.State(automation: automation)
        ) {
            AutomationDetailFeature()
        } withDependencies: {
            $0.activityLogStore.load = {
                [otherEntry, matchingEntry]
            }
            $0.automationRuntimeStore.load = {
                AutomationRuntimeState(
                    scheduledRuns: [
                        .init(automationID: automation.id, lastAttemptAt: lastAttempt)
                    ],
                    medicationQueryAnchorData: nil
                )
            }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(
            .historyResponse(
                .success(
                    AutomationDetailFeature.LoadResult(
                        history: [matchingEntry],
                        lastScheduledAttempt: lastAttempt,
                        nextEligibleRun: expectedNextRun
                    )
                )
            )
        ) {
            $0.isLoading = false
            $0.history = [matchingEntry]
            $0.lastScheduledAttempt = lastAttempt
            $0.nextEligibleRun = expectedNextRun
        }
    }
}
