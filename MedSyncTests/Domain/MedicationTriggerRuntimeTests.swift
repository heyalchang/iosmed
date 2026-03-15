import XCTest
@testable import MedSync

final class MedicationTriggerRuntimeTests: XCTestCase {
    func testFailedPendingTriggerRunLeavesPendingStateAndCommittedAnchorUnchanged() async {
        let committedAnchor = Data([0x01])
        let pendingTrigger = AutomationRuntimeState.PendingMedicationTrigger(
            automation: Automation(name: "Taken Export", trigger: .medicationTaken(.immediate)),
            queryAnchorData: Data([0x02]),
            triggeringEventIDs: [UUID(uuidString: "00000000-0000-0000-0000-000000000201")!],
            createdAt: Date(timeIntervalSince1970: 700)
        )
        let store = TestAutomationRuntimeStore(
            state: AutomationRuntimeState(
                medicationQueryAnchorData: committedAnchor,
                pendingMedicationTrigger: pendingTrigger
            )
        )
        let runtimeStore = AutomationRuntimeStoreClient(
            load: { await store.load() },
            update: { mutation in await store.update(mutation) }
        )
        let automationExecution = AutomationExecutionClient(
            runManualExport: { _ in
                XCTFail("Manual export should not run in medication-trigger tests.")
                throw TestFailure.unexpectedManualExport
            },
            runAutomation: { _, _, _ in
                throw TestFailure.runFailed
            }
        )

        do {
            try await MedicationTriggerRuntime.runPendingMedicationTrigger(
                pendingTrigger,
                runtimeStore: runtimeStore,
                automationExecution: automationExecution,
                processedAt: Date(timeIntervalSince1970: 701)
            )
            XCTFail("Expected pending trigger execution to throw.")
        } catch let error as TestFailure {
            XCTAssertEqual(error, .runFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let state = await store.load()
        XCTAssertEqual(state.medicationQueryAnchorData, committedAnchor)
        XCTAssertEqual(state.pendingMedicationTrigger, pendingTrigger)
        XCTAssertTrue(state.processedMedicationTriggerEvents.isEmpty)
    }
}

private actor TestAutomationRuntimeStore {
    private var state: AutomationRuntimeState

    init(state: AutomationRuntimeState) {
        self.state = state
    }

    func load() -> AutomationRuntimeState {
        state
    }

    func update(_ mutation: @Sendable (inout AutomationRuntimeState) -> Void) -> AutomationRuntimeState {
        mutation(&state)
        return state
    }
}

private enum TestFailure: Error, Equatable {
    case runFailed
    case unexpectedManualExport
}
