import XCTest
@testable import MedSync

final class AutomationRuntimeStateTests: XCTestCase {
    func testDecodingLegacyRuntimeStateDefaultsNewMedicationTriggerFields() throws {
        let legacyJSON = """
        {
          "scheduledRuns": [],
          "medicationQueryAnchorData": "AQ=="
        }
        """

        let state = try JSONDecoder.medSync.decode(
            AutomationRuntimeState.self,
            from: Data(legacyJSON.utf8)
        )

        XCTAssertEqual(state.medicationQueryAnchorData, Data([0x01]))
        XCTAssertNil(state.pendingMedicationTrigger)
        XCTAssertTrue(state.processedMedicationTriggerEvents.isEmpty)
    }

    func testCommitPendingMedicationTriggerAdvancesAnchorAndRecordsProcessedEvents() {
        let automation = Automation(name: "Taken Export", trigger: .medicationTaken(.hourly))
        let firstEventID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!
        let secondEventID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let processedAt = Date(timeIntervalSince1970: 500)
        var state = AutomationRuntimeState()
        state.stageMedicationTrigger(
            .init(
                automation: automation,
                queryAnchorData: Data([0x09]),
                triggeringEventIDs: [secondEventID, firstEventID],
                createdAt: Date(timeIntervalSince1970: 490)
            )
        )

        state.commitPendingMedicationTrigger(processedAt: processedAt)

        XCTAssertEqual(state.medicationQueryAnchorData, Data([0x09]))
        XCTAssertNil(state.pendingMedicationTrigger)
        XCTAssertEqual(
            state.processedMedicationTriggerEvents.map(\.eventID),
            [firstEventID, secondEventID]
        )
    }

    func testPruneProcessedMedicationTriggerEventsRemovesExpiredEntries() {
        let retainedEventID = UUID(uuidString: "00000000-0000-0000-0000-000000000110")!
        let expiredEventID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        let now = Date(timeIntervalSince1970: 1_000_000)
        var state = AutomationRuntimeState(
            processedMedicationTriggerEvents: [
                .init(
                    eventID: retainedEventID,
                    processedAt: now.addingTimeInterval(-60)
                ),
                .init(
                    eventID: expiredEventID,
                    processedAt: now.addingTimeInterval(-AutomationRuntimeState.processedMedicationTriggerRetention - 60)
                )
            ]
        )

        state.pruneProcessedMedicationTriggerEvents(referenceDate: now)

        XCTAssertEqual(
            state.processedMedicationTriggerEvents.map(\.eventID),
            [retainedEventID]
        )
    }

    func testRemoveStateClearsPendingMedicationTriggerForDeletedAutomation() {
        let deletedAutomation = Automation(name: "Taken Export", trigger: .medicationTaken(.hourly))
        let retainedAutomationID = UUID(uuidString: "00000000-0000-0000-0000-000000000120")!
        var state = AutomationRuntimeState(
            scheduledRuns: [
                .init(automationID: deletedAutomation.id, lastAttemptAt: Date(timeIntervalSince1970: 600)),
                .init(automationID: retainedAutomationID, lastAttemptAt: Date(timeIntervalSince1970: 601))
            ],
            pendingMedicationTrigger: .init(
                automation: deletedAutomation,
                queryAnchorData: Data([0x05]),
                triggeringEventIDs: [UUID(uuidString: "00000000-0000-0000-0000-000000000121")!],
                createdAt: Date(timeIntervalSince1970: 590)
            )
        )

        state.removeState(for: [deletedAutomation.id])

        XCTAssertNil(state.pendingMedicationTrigger)
        XCTAssertEqual(state.scheduledRuns.map(\.automationID), [retainedAutomationID])
    }
}
