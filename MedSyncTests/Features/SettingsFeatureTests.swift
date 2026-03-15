import ComposableArchitecture
import XCTest
@testable import MedSync

@MainActor
final class SettingsFeatureTests: XCTestCase {
    func testRequestHealthKitAccessResyncsAutomations() async {
        let automation = Automation(
            name: "Taken Export",
            trigger: .medicationTaken(.hourly)
        )
        let capture = SettingsHealthKitCapture()

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.healthKitClient.requestAuthorization = {
                await capture.recordAuthorization()
            }
            $0.automationStore.load = {
                [automation]
            }
            $0.medicationTriggerClient.start = {
                await capture.recordTriggerStart()
            }
            $0.medicationTriggerClient.syncAutomationSelection = { automations in
                await capture.recordMedicationSync(automations)
            }
            $0.automationScheduler.syncAutomations = { automations in
                await capture.recordSchedulerSync(automations)
            }
        }

        await store.send(.requestHealthKitAccessTapped)
        await store.receive(
            .requestHealthKitAccessResponse(
                .success("HealthKit access is ready for medication exports and medication-trigger automations.")
            )
        ) {
            $0.statusMessage = "HealthKit access is ready for medication exports and medication-trigger automations."
        }

        let authorizationCount = await capture.authorizationCount
        let triggerStartCount = await capture.triggerStartCount
        let medicationSyncs = await capture.medicationSyncs
        let schedulerSyncs = await capture.schedulerSyncs

        XCTAssertEqual(authorizationCount, 1)
        XCTAssertEqual(triggerStartCount, 1)
        XCTAssertEqual(medicationSyncs, [[automation]])
        XCTAssertEqual(schedulerSyncs, [[automation]])
    }
}

private actor SettingsHealthKitCapture {
    private(set) var authorizationCount = 0
    private(set) var triggerStartCount = 0
    private(set) var medicationSyncs: [[Automation]] = []
    private(set) var schedulerSyncs: [[Automation]] = []

    func recordAuthorization() {
        authorizationCount += 1
    }

    func recordTriggerStart() {
        triggerStartCount += 1
    }

    func recordMedicationSync(_ automations: [Automation]) {
        medicationSyncs.append(automations)
    }

    func recordSchedulerSync(_ automations: [Automation]) {
        schedulerSyncs.append(automations)
    }
}
