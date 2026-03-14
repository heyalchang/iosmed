import ComposableArchitecture
import Foundation

struct ExportRunnerClient: Sendable {
    var run: @Sendable (ExportRequest) async throws -> ExportRunSummary
}

extension ExportRunnerClient: DependencyKey {
    static let liveValue = Self(
        run: { request in
            let healthKit = HealthKitClient.liveValue
            let iCloudDrive = ICloudDriveClient.liveValue
            let payload = try await healthKit.fetchMedicationPayload(request.exportOptions)
            let data = try MedicationExportSerializer.serialize(payload, as: request.exportOptions.format)
            let plan = ExportFileLayout.plan(for: request, executedAt: payload.exportedAt)
            _ = try iCloudDrive.write(data, plan)

            return ExportRunSummary(
                filename: plan.filename,
                relativePath: plan.relativePath,
                recordCount: payload.data.medications.count,
                destination: .iCloudDrive,
                format: request.exportOptions.format,
                dateRangePreset: request.exportOptions.dateRange.preset,
                dateRange: payload.dateRange.start...payload.dateRange.end,
                triggerReason: request.triggerReason,
                automationID: request.automation?.id,
                automationName: request.automation?.name
            )
        }
    )

    static let testValue = Self(
        run: { request in
            let now = Date()
            return ExportRunSummary(
                filename: "test.\(request.exportOptions.format.fileExtension)",
                relativePath: "MedSync/test.\(request.exportOptions.format.fileExtension)",
                recordCount: 0,
                destination: .iCloudDrive,
                format: request.exportOptions.format,
                dateRangePreset: request.exportOptions.dateRange.preset,
                dateRange: request.exportOptions.dateRange.resolved(now: now),
                triggerReason: request.triggerReason,
                automationID: request.automation?.id,
                automationName: request.automation?.name
            )
        }
    )
}

extension DependencyValues {
    var exportRunner: ExportRunnerClient {
        get { self[ExportRunnerClient.self] }
        set { self[ExportRunnerClient.self] = newValue }
    }
}

