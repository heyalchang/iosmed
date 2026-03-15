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
    enum ObservationAction: Equatable {
        case retryPending(AutomationRuntimeState.PendingMedicationTrigger)
        case commitAnchor(Data)
        case stagePending(AutomationRuntimeState.PendingMedicationTrigger)
        case noAction
    }

    static func observationAction(
        state: AutomationRuntimeState,
        newAnchorData: Data?,
        takenEventIDs: [UUID],
        automation: Automation?,
        now: Date
    ) -> ObservationAction {
        if let pendingMedicationTrigger = state.pendingMedicationTrigger {
            return .retryPending(pendingMedicationTrigger)
        }

        guard let newAnchorData else {
            return .noAction
        }

        guard state.medicationQueryAnchorData != nil else {
            return .commitAnchor(newAnchorData)
        }

        let unprocessedTakenEventIDs = normalizedMedicationTriggerEventIDs(
            takenEventIDs.filter { !state.hasProcessedMedicationTriggerEvent($0) }
        )
        guard !unprocessedTakenEventIDs.isEmpty else {
            return .commitAnchor(newAnchorData)
        }

        guard let automation else {
            return .commitAnchor(newAnchorData)
        }

        return .stagePending(
            AutomationRuntimeState.PendingMedicationTrigger(
                automation: automation,
                queryAnchorData: newAnchorData,
                triggeringEventIDs: unprocessedTakenEventIDs,
                createdAt: now
            )
        )
    }

    static func detailMessage(for newlyTakenEventCount: Int) -> String {
        newlyTakenEventCount == 1
            ? "Triggered after 1 newly logged taken medication event."
            : "Triggered after \(newlyTakenEventCount) newly logged taken medication events."
    }

    static func detailMessage(for pendingMedicationTrigger: AutomationRuntimeState.PendingMedicationTrigger) -> String {
        detailMessage(for: pendingMedicationTrigger.triggeringEventIDs.count)
    }
}

enum MedicationTriggerRuntime {
    static func runPendingMedicationTrigger(
        _ pendingMedicationTrigger: AutomationRuntimeState.PendingMedicationTrigger,
        runtimeStore: AutomationRuntimeStoreClient,
        automationExecution: AutomationExecutionClient,
        processedAt: Date
    ) async throws {
        _ = try await automationExecution.runAutomation(
            pendingMedicationTrigger.automation,
            .medicationTriggerBackgroundDelivery,
            MedicationTriggerPlanner.detailMessage(for: pendingMedicationTrigger)
        )
        _ = try await runtimeStore.update { state in
            state.commitPendingMedicationTrigger(processedAt: processedAt)
        }
    }
}

#if canImport(HealthKit)
private final class ObserverQueryCompletionHandlerBox: @unchecked Sendable {
    private let completionHandler: () -> Void

    init(_ completionHandler: @escaping () -> Void) {
        self.completionHandler = completionHandler
    }

    func call() {
        completionHandler()
    }
}

private actor MedicationTriggerService {
    @Dependency(\.automationExecution) private var automationExecution
    @Dependency(\.automationRuntimeStore) private var automationRuntimeStore
    @Dependency(\.automationStore) private var automationStore
    @Dependency(\.date.now) private var currentDate
    @Dependency(\.healthKitClient) private var healthKitClient

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var hasStarted = false
    private var isProcessingChanges = false
    private var needsProcessingChanges = false

    func start() async {
        guard !hasStarted else {
            await requestProcessing()
            return
        }

        hasStarted = true

        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }

        installObserverQuery(reinstall: false)

        await requestProcessing()
    }

    func syncAutomationSelection(_ automations: [Automation]) async {
        let frequency = automations
            .first(where: { $0.isEnabled && $0.trigger.medicationFrequency != nil })?
            .trigger
            .medicationFrequency

        let configured = (try? await healthKitClient.configureMedicationBackgroundDelivery(frequency)) != nil

        guard hasStarted, frequency != nil, configured else {
            return
        }

        installObserverQuery(reinstall: true)
        await requestProcessing()
    }

    private func handleObservation(error: Error?) async {
        guard error == nil else {
            return
        }

        await requestProcessing()
    }

    private func requestProcessing() async {
        if isProcessingChanges {
            needsProcessingChanges = true
            return
        }

        repeat {
            needsProcessingChanges = false
            isProcessingChanges = true
            try? await processObservedChanges()
            isProcessingChanges = false
        } while needsProcessingChanges
    }

    private func installObserverQuery(reinstall: Bool) {
        if reinstall, let observerQuery {
            healthStore.stop(observerQuery)
            self.observerQuery = nil
        }

        guard observerQuery == nil else {
            return
        }

        observerQuery = HKObserverQuery(
            sampleType: .medicationDoseEventType(),
            predicate: nil
        ) { [weak self] _, completionHandler, error in
            let completion = ObserverQueryCompletionHandlerBox(completionHandler)
            Task {
                await self?.handleObservation(error: error)
                completion.call()
            }
        }

        if let observerQuery {
            healthStore.execute(observerQuery)
        }
    }

    private func processObservedChanges() async throws {
        let runtimeStore = automationRuntimeStore
        let processedAt = currentDate
        let currentState = try await runtimeStore.load()

        if let pendingMedicationTrigger = currentState.pendingMedicationTrigger {
            try await MedicationTriggerRuntime.runPendingMedicationTrigger(
                pendingMedicationTrigger,
                runtimeStore: runtimeStore,
                automationExecution: automationExecution,
                processedAt: processedAt
            )
            return
        }

        let previousAnchorData = currentState.medicationQueryAnchorData
        let previousAnchor = try anchor(from: previousAnchorData)
        let result = try await anchoredDoseEvents(after: previousAnchor)

        let automations = try await automationStore.load()
        let selectedAutomation = automations.first(where: { $0.isEnabled && $0.trigger.medicationFrequency != nil })
        let action = MedicationTriggerPlanner.observationAction(
            state: currentState,
            newAnchorData: result.anchor.flatMap { try? archive(anchor: $0) },
            takenEventIDs: result.events
                .filter { $0.logStatus == .taken }
                .map(\.uuid),
            automation: selectedAutomation,
            now: processedAt
        )

        switch action {
        case let .retryPending(pendingMedicationTrigger):
            try await MedicationTriggerRuntime.runPendingMedicationTrigger(
                pendingMedicationTrigger,
                runtimeStore: runtimeStore,
                automationExecution: automationExecution,
                processedAt: processedAt
            )

        case let .commitAnchor(anchorData):
            _ = try await runtimeStore.update { state in
                state.advanceMedicationQueryAnchor(anchorData, referenceDate: processedAt)
            }

        case let .stagePending(pendingMedicationTrigger):
            _ = try await runtimeStore.update { state in
                state.stageMedicationTrigger(pendingMedicationTrigger)
            }
            try await MedicationTriggerRuntime.runPendingMedicationTrigger(
                pendingMedicationTrigger,
                runtimeStore: runtimeStore,
                automationExecution: automationExecution,
                processedAt: processedAt
            )

        case .noAction:
            return
        }
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
