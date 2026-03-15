import ComposableArchitecture
import XCTest
@testable import MedSync

final class RunAutomationIntentTests: XCTestCase {
    func testPerformRunsSelectedAutomationWithShortcutsTrigger() async throws {
        let automation = Automation(name: "Shortcut Export")
        let summary = ExportRunSummary(
            filename: "shortcut-export.json",
            relativePath: "MedSync/shortcut-export.json",
            recordCount: 1,
            destination: .iCloudDrive,
            format: .json,
            dateRangePreset: .lastWeek,
            dateRange: Date(timeIntervalSince1970: 10)...Date(timeIntervalSince1970: 20),
            triggerReason: .shortcuts,
            automationID: automation.id,
            automationName: automation.name
        )
        let recorder = AutomationInvocationRecorder()
        var intent = RunAutomationIntent()
        intent.automation = AutomationAppEntity(
            id: automation.id,
            name: automation.name,
            subtitle: automation.trigger.displayName
        )

        _ = try await withDependencies {
            $0.automationStore.load = { [automation] }
            $0.automationExecution.runAutomation = { automation, triggerReason, detailMessage in
                await recorder.record(
                    automationID: automation.id,
                    triggerReason: triggerReason,
                    detailMessage: detailMessage
                )
                return summary
            }
        } operation: {
            try await intent.perform()
        }

        let invocations = await recorder.snapshot()
        XCTAssertEqual(invocations.count, 1)
        XCTAssertEqual(invocations[0].automationID, automation.id)
        XCTAssertEqual(invocations[0].triggerReason, .shortcuts)
        XCTAssertNil(invocations[0].detailMessage)
    }

    func testPerformThrowsWhenAutomationNoLongerExists() async {
        let missingID = UUID()
        var intent = RunAutomationIntent()
        intent.automation = AutomationAppEntity(
            id: missingID,
            name: "Missing Export",
            subtitle: "Every 1 hours"
        )

        do {
            _ = try await withDependencies {
                $0.automationStore.load = { [] }
            } operation: {
                try await intent.perform()
            }
            XCTFail("Expected intent to throw for a missing automation")
        } catch let error as UserFacingError {
            XCTAssertEqual(error, UserFacingError("The selected automation no longer exists."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private actor AutomationInvocationRecorder {
    struct Invocation: Equatable {
        var automationID: UUID
        var triggerReason: TriggerReason
        var detailMessage: String?
    }

    private var invocations: [Invocation] = []

    func record(automationID: UUID, triggerReason: TriggerReason, detailMessage: String?) {
        invocations.append(
            Invocation(
                automationID: automationID,
                triggerReason: triggerReason,
                detailMessage: detailMessage
            )
        )
    }

    func snapshot() -> [Invocation] {
        invocations
    }
}
