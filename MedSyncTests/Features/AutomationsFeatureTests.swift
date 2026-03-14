import ComposableArchitecture
import XCTest
@testable import MedSync

@MainActor
final class AutomationsFeatureTests: XCTestCase {
    func testTaskLoadsAutomations() async {
        let automation = Automation(name: "Morning Export")

        let store = TestStore(initialState: AutomationsFeature.State()) {
            AutomationsFeature()
        } withDependencies: {
            $0.automationStore.load = { [automation] }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(.automationsResponse(.success([automation]))) {
            $0.isLoading = false
            $0.automations = [automation]
        }
    }
}

