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

    @Dependency(\.automationExecution) var automationExecution

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
                return .run { send in
                    do {
                        let summary = try await automationExecution.runManualExport(exportOptions)
                        await send(.exportResponse(.success(summary)))
                    } catch {
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
