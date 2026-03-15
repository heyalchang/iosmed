import XCTest
@testable import MedSync

final class MedicationTriggerPlannerTests: XCTestCase {
    func testInitialAnchorPrimesWithoutRunningAutomation() {
        XCTAssertFalse(
            MedicationTriggerPlanner.shouldRunAutomation(
                previousAnchorData: nil,
                newlyTakenEventCount: 2
            )
        )
    }

    func testKnownAnchorRunsWhenNewTakenEventsArrive() {
        XCTAssertTrue(
            MedicationTriggerPlanner.shouldRunAutomation(
                previousAnchorData: Data([0x01]),
                newlyTakenEventCount: 1
            )
        )
    }

    func testDetailMessagePluralizesCount() {
        XCTAssertEqual(
            MedicationTriggerPlanner.detailMessage(for: 3),
            "Triggered after 3 newly logged taken medication events."
        )
    }
}
