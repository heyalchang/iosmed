import ComposableArchitecture
import Foundation

struct AutomationExecutionClient: Sendable {
    var runManualExport: @Sendable (MedicationExportOptions) async throws -> ExportRunSummary
    var runAutomation: @Sendable (Automation, TriggerReason, String?) async throws -> ExportRunSummary
}

extension AutomationExecutionClient: DependencyKey {
    static let liveValue: Self = {
        let service = AutomationExecutionService()
        return Self(
            runManualExport: { options in
                try await service.runManualExport(options)
            },
            runAutomation: { automation, triggerReason, detailMessage in
                try await service.runAutomation(
                    automation,
                    triggerReason: triggerReason,
                    detailMessage: detailMessage
                )
            }
        )
    }()

    static let testValue = Self(
        runManualExport: { options in
            let now = Date()
            return ExportRunSummary(
                filename: "manual.\(options.format.fileExtension)",
                relativePath: "MedSync/manual.\(options.format.fileExtension)",
                recordCount: 0,
                destination: .iCloudDrive,
                format: options.format,
                dateRangePreset: options.dateRange.preset,
                dateRange: options.dateRange.resolved(now: now),
                triggerReason: .manualExport,
                automationID: nil,
                automationName: nil
            )
        },
        runAutomation: { automation, triggerReason, _ in
            let now = Date()
            return ExportRunSummary(
                filename: "\(ExportFileLayout.slug(automation.name)).\(automation.exportOptions.format.fileExtension)",
                relativePath: "MedSync/\(ExportFileLayout.slug(automation.name)).\(automation.exportOptions.format.fileExtension)",
                recordCount: 0,
                destination: .iCloudDrive,
                format: automation.exportOptions.format,
                dateRangePreset: automation.exportOptions.dateRange.preset,
                dateRange: automation.exportOptions.dateRange.resolved(now: now),
                triggerReason: triggerReason,
                automationID: automation.id,
                automationName: automation.name
            )
        }
    )
}

extension DependencyValues {
    var automationExecution: AutomationExecutionClient {
        get { self[AutomationExecutionClient.self] }
        set { self[AutomationExecutionClient.self] = newValue }
    }
}

private actor AutomationExecutionService {
    @Dependency(\.activityLogStore) private var activityLogStore
    @Dependency(\.date.now) private var currentDate
    @Dependency(\.exportRunner) private var exportRunner
    @Dependency(\.localNotifications) private var localNotifications

    func runManualExport(_ options: MedicationExportOptions) async throws -> ExportRunSummary {
        do {
            let summary = try await exportRunner.run(.manual(options))
            try await activityLogStore.append(.run(summary: summary, timestamp: currentDate))
            return summary
        } catch {
            let now = currentDate
            let range = options.dateRange.resolved(now: now)
            let failureSummary = ExportRunSummary(
                filename: "",
                relativePath: "",
                recordCount: 0,
                destination: .iCloudDrive,
                format: options.format,
                dateRangePreset: options.dateRange.preset,
                dateRange: range,
                triggerReason: .manualExport,
                automationID: nil,
                automationName: nil
            )
            try? await activityLogStore.append(
                .run(
                    summary: failureSummary,
                    status: .failure,
                    errorDetails: error.localizedDescription,
                    timestamp: now
                )
            )
            throw UserFacingError(error.localizedDescription)
        }
    }

    func runAutomation(
        _ automation: Automation,
        triggerReason: TriggerReason,
        detailMessage: String?
    ) async throws -> ExportRunSummary {
        do {
            let summary = try await exportRunner.run(.automation(automation, triggerReason: triggerReason))
            try await activityLogStore.append(
                .run(summary: summary, timestamp: currentDate, message: detailMessage)
            )
            if automation.notifyWhenRun {
                await localNotifications.sendAutomationRunNotification(
                    AutomationNotificationPayload(
                        automationName: automation.name,
                        triggerReason: triggerReason,
                        status: .success,
                        filename: summary.filename,
                        errorMessage: nil
                    )
                )
            }
            return summary
        } catch {
            let now = currentDate
            let range = automation.exportOptions.dateRange.resolved(now: now)
            let failureSummary = ExportRunSummary(
                filename: "",
                relativePath: "",
                recordCount: 0,
                destination: .iCloudDrive,
                format: automation.exportOptions.format,
                dateRangePreset: automation.exportOptions.dateRange.preset,
                dateRange: range,
                triggerReason: triggerReason,
                automationID: automation.id,
                automationName: automation.name
            )
            try? await activityLogStore.append(
                .run(
                    summary: failureSummary,
                    status: .failure,
                    errorDetails: error.localizedDescription,
                    timestamp: now,
                    message: detailMessage
                )
            )
            if automation.notifyWhenRun {
                await localNotifications.sendAutomationRunNotification(
                    AutomationNotificationPayload(
                        automationName: automation.name,
                        triggerReason: triggerReason,
                        status: .failure,
                        filename: nil,
                        errorMessage: error.localizedDescription
                    )
                )
            }
            throw UserFacingError(error.localizedDescription)
        }
    }
}
