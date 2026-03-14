import ComposableArchitecture
import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

struct MedicationTriggerClient: Sendable {
    var start: @Sendable () async -> Void
    var syncAutomationSelection: @Sendable ([Automation]) async -> Void
}

extension MedicationTriggerClient: DependencyKey {
    static let liveValue: Self = {
        let service = MedicationTriggerService()
        return Self(
            start: {
                await service.start()
            },
            syncAutomationSelection: { automations in
                await service.syncAutomationSelection(automations)
            }
        )
    }()

    static let testValue = Self(
        start: { },
        syncAutomationSelection: { _ in }
    )
}

extension DependencyValues {
    var medicationTriggerClient: MedicationTriggerClient {
        get { self[MedicationTriggerClient.self] }
        set { self[MedicationTriggerClient.self] = newValue }
    }
}

enum MedicationTriggerPlanner {
    static func shouldRunAutomation(
        previousAnchorData: Data?,
        newlyTakenEventCount: Int
    ) -> Bool {
        previousAnchorData != nil && newlyTakenEventCount > 0
    }

    static func detailMessage(for newlyTakenEventCount: Int) -> String {
        newlyTakenEventCount == 1
            ? "Triggered after 1 newly logged taken medication event."
            : "Triggered after \(newlyTakenEventCount) newly logged taken medication events."
    }
}

#if canImport(HealthKit)
private actor MedicationTriggerService {
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var hasStarted = false

    func start() async {
        guard !hasStarted else {
            try? await processObservedChanges()
            return
        }

        hasStarted = true

        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }

        observerQuery = HKObserverQuery(
            sampleType: .medicationDoseEventType(),
            predicate: nil
        ) { [weak self] _, completionHandler, error in
            completionHandler()
            Task {
                await self?.handleObservation(error: error)
            }
        }

        if let observerQuery {
            healthStore.execute(observerQuery)
        }

        try? await processObservedChanges()
    }

    func syncAutomationSelection(_ automations: [Automation]) async {
        let frequency = automations
            .first(where: { $0.isEnabled && $0.trigger.medicationFrequency != nil })?
            .trigger
            .medicationFrequency

        try? await HealthKitClient.liveValue.configureMedicationBackgroundDelivery(frequency)
    }

    private func handleObservation(error: Error?) async {
        guard error == nil else {
            return
        }

        try? await processObservedChanges()
    }

    private func processObservedChanges() async throws {
        let runtimeStore = AutomationRuntimeStoreClient.liveValue
        let currentState = try await runtimeStore.load()
        let previousAnchorData = currentState.medicationQueryAnchorData
        let previousAnchor = try anchor(from: previousAnchorData)
        let result = try await anchoredDoseEvents(after: previousAnchor)

        guard let newAnchor = result.anchor else {
            return
        }

        let anchorData = try archive(anchor: newAnchor)
        _ = try await runtimeStore.update { state in
            state.medicationQueryAnchorData = anchorData
        }

        let takenEvents = result.events.filter { $0.logStatus == .taken }
        guard MedicationTriggerPlanner.shouldRunAutomation(
            previousAnchorData: previousAnchorData,
            newlyTakenEventCount: takenEvents.count
        ) else {
            return
        }

        let automations = try await AutomationStoreClient.liveValue.load()
        guard let automation = automations.first(where: { $0.isEnabled && $0.trigger.medicationFrequency != nil }) else {
            return
        }

        _ = try await AutomationExecutionClient.liveValue.runAutomation(
            automation,
            .medicationTriggerBackgroundDelivery,
            MedicationTriggerPlanner.detailMessage(for: takenEvents.count)
        )
    }

    private func anchoredDoseEvents(after anchor: HKQueryAnchor?) async throws -> (
        events: [HKMedicationDoseEvent],
        anchor: HKQueryAnchor?
    ) {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: .medicationDoseEventType(),
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, newAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let events = (samples as? [HKMedicationDoseEvent]) ?? []
                continuation.resume(returning: (events, newAnchor))
            }

            healthStore.execute(query)
        }
    }

    private func archive(anchor: HKQueryAnchor) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    }

    private func anchor(from data: Data?) throws -> HKQueryAnchor? {
        guard let data else { return nil }
        return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
}
#endif
