import XCTest
@testable import MedSync

final class MedicationTriggerPlannerTests: XCTestCase {
    func testInitialAnchorPrimesWithoutRunningAutomation() {
        let action = MedicationTriggerPlanner.observationAction(
            state: AutomationRuntimeState(),
            newAnchorData: Data([0x01]),
            takenEventIDs: [UUID(), UUID()],
            automation: Automation(name: "Taken Export", trigger: .medicationTaken(.immediate)),
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(action, .commitAnchor(Data([0x01])))
    }

    func testKnownAnchorStagesPendingTriggerWhenNewTakenEventsArrive() {
        let automation = Automation(name: "Taken Export", trigger: .medicationTaken(.hourly))
        let now = Date(timeIntervalSince1970: 200)
        let eventID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let action = MedicationTriggerPlanner.observationAction(
            state: AutomationRuntimeState(medicationQueryAnchorData: Data([0x01])),
            newAnchorData: Data([0x02]),
            takenEventIDs: [eventID],
            automation: automation,
            now: now
        )

        XCTAssertEqual(
            action,
            .stagePending(
                AutomationRuntimeState.PendingMedicationTrigger(
                    automation: automation,
                    queryAnchorData: Data([0x02]),
                    triggeringEventIDs: [eventID],
                    createdAt: now
                )
            )
        )
    }

    func testPendingTriggerRetriesBeforeReadingNewObservationState() {
        let pendingTrigger = AutomationRuntimeState.PendingMedicationTrigger(
            automation: Automation(name: "Taken Export", trigger: .medicationTaken(.daily)),
            queryAnchorData: Data([0x03]),
            triggeringEventIDs: [UUID(uuidString: "00000000-0000-0000-0000-000000000010")!],
            createdAt: Date(timeIntervalSince1970: 300)
        )

        let action = MedicationTriggerPlanner.observationAction(
            state: AutomationRuntimeState(
                medicationQueryAnchorData: Data([0x01]),
                pendingMedicationTrigger: pendingTrigger
            ),
            newAnchorData: Data([0x04]),
            takenEventIDs: [UUID()],
            automation: Automation(name: "Ignored Export", trigger: .medicationTaken(.immediate)),
            now: Date(timeIntervalSince1970: 301)
        )

        XCTAssertEqual(action, .retryPending(pendingTrigger))
    }

    func testPreviouslyProcessedEventIDsDoNotRestagePendingTrigger() {
        let eventID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
        let processedAt = Date(timeIntervalSince1970: 400)
        var state = AutomationRuntimeState(medicationQueryAnchorData: Data([0x01]))
        state.recordProcessedMedicationTriggerEvents([eventID], processedAt: processedAt)

        let action = MedicationTriggerPlanner.observationAction(
            state: state,
            newAnchorData: Data([0x02]),
            takenEventIDs: [eventID],
            automation: Automation(name: "Taken Export", trigger: .medicationTaken(.immediate)),
            now: Date(timeIntervalSince1970: 401)
        )

        XCTAssertEqual(action, .commitAnchor(Data([0x02])))
    }

    func testNewTakenEventsAdvanceAnchorWhenNoMedicationTriggerAutomationIsSelected() {
        let action = MedicationTriggerPlanner.observationAction(
            state: AutomationRuntimeState(medicationQueryAnchorData: Data([0x01])),
            newAnchorData: Data([0x02]),
            takenEventIDs: [UUID(uuidString: "00000000-0000-0000-0000-000000000030")!],
            automation: nil,
            now: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(action, .commitAnchor(Data([0x02])))
    }

    func testDetailMessagePluralizesCount() {
        XCTAssertEqual(
            MedicationTriggerPlanner.detailMessage(for: 3),
            "Triggered after 3 newly logged taken medication events."
        )
    }
}
