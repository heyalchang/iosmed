import ComposableArchitecture
import Foundation

struct MedicationTriggerClient: Sendable {
    var syncAutomationSelection: @Sendable ([Automation]) async -> Void
}

extension MedicationTriggerClient: DependencyKey {
    static let liveValue = Self(
        syncAutomationSelection: { automations in
            let frequency = automations
                .first(where: { $0.isEnabled && $0.trigger.medicationFrequency != nil })?
                .trigger
                .medicationFrequency

            try? await HealthKitClient.liveValue.configureMedicationBackgroundDelivery(frequency)
        }
    )

    static let testValue = Self(
        syncAutomationSelection: { _ in }
    )
}

extension DependencyValues {
    var medicationTriggerClient: MedicationTriggerClient {
        get { self[MedicationTriggerClient.self] }
        set { self[MedicationTriggerClient.self] = newValue }
    }
}

