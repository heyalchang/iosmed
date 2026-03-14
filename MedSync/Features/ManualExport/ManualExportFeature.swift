import ComposableArchitecture
import Foundation

@Reducer
struct ManualExportFeature {
    @ObservableState
    struct State: Equatable {
        var exportOptions = MedicationExportOptions()
        var isExporting = false
        var resultMessage: String?
    }

    enum Action: Equatable {
        case datePresetChanged(DateRangePreset)
        case customStartChanged(Date)
        case customEndChanged(Date)
        case formatChanged(ExportFormat)
        case timeGroupingChanged(TimeGrouping)
        case exportButtonTapped
        case exportResponse(Result<ExportRunSummary, UserFacingError>)
    }

    @Dependency(\.exportRunner) var exportRunner
    @Dependency(\.activityLogStore) var activityLogStore
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .datePresetChanged(preset):
                state.exportOptions.dateRange.preset = preset
                return .none

            case let .customStartChanged(date):
                state.exportOptions.dateRange.customStart = date
                return .none

            case let .customEndChanged(date):
                state.exportOptions.dateRange.customEnd = date
                return .none

            case let .formatChanged(format):
                state.exportOptions.format = format
                return .none

            case let .timeGroupingChanged(grouping):
                state.exportOptions.timeGrouping = grouping
                return .none

            case .exportButtonTapped:
                state.isExporting = true
                state.resultMessage = nil
                let exportOptions = state.exportOptions
                return .run { [now] send in
                    do {
                        let summary = try await exportRunner.run(.manual(exportOptions))
                        try await activityLogStore.append(.run(summary: summary, timestamp: now))
                        await send(.exportResponse(.success(summary)))
                    } catch {
                        let range = exportOptions.dateRange.resolved(now: now)
                        let failureSummary = ExportRunSummary(
                            filename: "",
                            relativePath: "",
                            recordCount: 0,
                            destination: .iCloudDrive,
                            format: exportOptions.format,
                            dateRangePreset: exportOptions.dateRange.preset,
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
                        await send(.exportResponse(.failure(UserFacingError(error.localizedDescription))))
                    }
                }

            case let .exportResponse(.success(summary)):
                state.isExporting = false
                state.resultMessage = "Saved \(summary.filename) to \(ExportFileLayout.destinationDescription)."
                return .none

            case let .exportResponse(.failure(error)):
                state.isExporting = false
                state.resultMessage = error.message
                return .none
            }
        }
    }
}
