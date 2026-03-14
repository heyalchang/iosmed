import ComposableArchitecture
import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

struct HealthKitClient: Sendable {
    var requestAuthorization: @Sendable () async throws -> Void
    var fetchMedicationPayload: @Sendable (MedicationExportOptions) async throws -> MedicationExportPayload
    var configureMedicationBackgroundDelivery: @Sendable (MedicationBackgroundDeliveryFrequency?) async throws -> Void
}

enum HealthKitClientError: LocalizedError, Equatable {
    case unavailable
    case missingMedication(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Health data is unavailable on this device."
        case let .missingMedication(name):
            "Could not resolve metadata for medication \(name)."
        }
    }
}

extension HealthKitClient: DependencyKey {
    static let liveValue: Self = {
        #if canImport(HealthKit)
        let service = HealthKitMedicationService()
        return Self(
            requestAuthorization: {
                try await service.requestAuthorization()
            },
            fetchMedicationPayload: { options in
                try await service.fetchMedicationPayload(options: options)
            },
            configureMedicationBackgroundDelivery: { frequency in
                try await service.configureMedicationBackgroundDelivery(frequency)
            }
        )
        #else
        return Self(
            requestAuthorization: { throw HealthKitClientError.unavailable },
            fetchMedicationPayload: { _ in throw HealthKitClientError.unavailable },
            configureMedicationBackgroundDelivery: { _ in throw HealthKitClientError.unavailable }
        )
        #endif
    }()

    static let testValue = Self(
        requestAuthorization: { },
        fetchMedicationPayload: { options in
            let now = Date()
            let range = options.dateRange.resolved(now: now)
            return MedicationExportPayload(exportedAt: now, dateRange: range, preset: options.dateRange.preset, medications: [])
        },
        configureMedicationBackgroundDelivery: { _ in }
    )
}

extension DependencyValues {
    var healthKitClient: HealthKitClient {
        get { self[HealthKitClient.self] }
        set { self[HealthKitClient.self] = newValue }
    }
}

#if canImport(HealthKit)
private actor HealthKitMedicationService {
    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitClientError.unavailable
        }

        let readTypes: Set = [
            HKObjectType.medicationDoseEventType(),
            HKObjectType.userAnnotatedMedicationType()
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: CancellationError())
                }
            }
        }
    }

    func fetchMedicationPayload(options: MedicationExportOptions) async throws -> MedicationExportPayload {
        try await requestAuthorization()

        let now = Date()
        let range = options.dateRange.resolved(now: now)
        let medicationEvents = try await doseEvents(in: range)
        let annotatedMedications = try await userAnnotatedMedications()

        let medications = medicationEvents.map { event in
            MedicationExportRecord(
                id: event.uuid.uuidString,
                startDate: event.startDate,
                endDate: event.endDate,
                logStatus: map(logStatus: event.logStatus),
                scheduleType: map(scheduleType: event.scheduleType),
                scheduledDate: event.scheduledDate,
                doseQuantity: event.doseQuantity,
                scheduledDoseQuantity: event.scheduledDoseQuantity,
                unit: event.unit.unitString,
                medication: mapMedication(for: event, userAnnotatedMedications: annotatedMedications)
            )
        }

        return MedicationExportPayload(
            exportedAt: now,
            dateRange: range,
            preset: options.dateRange.preset,
            medications: medications
        )
    }

    func configureMedicationBackgroundDelivery(_ frequency: MedicationBackgroundDeliveryFrequency?) async throws {
        let type = HKObjectType.medicationDoseEventType()

        guard let frequency else {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                healthStore.disableBackgroundDelivery(for: type) { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: CancellationError())
                    }
                }
            }
            return
        }

        try await requestAuthorization()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.enableBackgroundDelivery(for: type, frequency: frequency.hkUpdateFrequency) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: CancellationError())
                }
            }
        }
    }

    private func doseEvents(in range: ClosedRange<Date>) async throws -> [HKMedicationDoseEvent] {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: .medicationDoseEventType(),
                predicate: HKQuery.predicateForSamples(withStart: range.lowerBound, end: range.upperBound, options: []),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let typed = (samples as? [HKMedicationDoseEvent]) ?? []
                continuation.resume(returning: typed)
            }
            healthStore.execute(query)
        }
    }

    private func userAnnotatedMedications() async throws -> [HKUserAnnotatedMedication] {
        let descriptor = HKUserAnnotatedMedicationQueryDescriptor()
        return try await descriptor.result(for: healthStore)
    }

    private func mapMedication(
        for event: HKMedicationDoseEvent,
        userAnnotatedMedications: [HKUserAnnotatedMedication]
    ) -> MedicationIdentity {
        let matchingMedication = userAnnotatedMedications.first {
            ($0.medication.identifier as NSObject).isEqual(event.medicationConceptIdentifier)
        }

        let concept = matchingMedication?.medication
        return MedicationIdentity(
            displayText: concept?.displayText ?? "Medication",
            nickname: matchingMedication?.nickname,
            hasSchedule: matchingMedication?.hasSchedule ?? (event.scheduleType == .schedule),
            isArchived: matchingMedication?.isArchived ?? false,
            generalForm: concept?.generalForm.rawValue ?? "unknown",
            codings: (concept?.relatedCodings ?? []).sorted { $0.code < $1.code }.map {
                MedicationCoding(system: $0.system, version: $0.version, code: $0.code)
            }
        )
    }

    private func map(logStatus: HKMedicationDoseEvent.LogStatus) -> MedicationLogStatus {
        switch logStatus {
        case .notInteracted: .notInteracted
        case .notificationNotSent: .notificationNotSent
        case .snoozed: .snoozed
        case .taken: .taken
        case .skipped: .skipped
        case .notLogged: .notLogged
        @unknown default: .notLogged
        }
    }

    private func map(scheduleType: HKMedicationDoseEvent.ScheduleType) -> MedicationScheduleType {
        switch scheduleType {
        case .asNeeded: .asNeeded
        case .schedule: .scheduled
        @unknown default: .asNeeded
        }
    }
}

private extension MedicationBackgroundDeliveryFrequency {
    var hkUpdateFrequency: HKUpdateFrequency {
        switch self {
        case .immediate: .immediate
        case .hourly: .hourly
        case .daily: .daily
        }
    }
}
#endif
