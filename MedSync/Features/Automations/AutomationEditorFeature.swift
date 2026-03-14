import ComposableArchitecture
import Foundation

@Reducer
struct AutomationEditorFeature {
    @ObservableState
    struct State: Equatable {
        var draft: AutomationDraft
        var validationMessage: String?

        var title: String {
            draft.id == nil ? "New Automation" : "Edit Automation"
        }
    }

    enum Action: Equatable {
        case nameChanged(String)
        case enabledChanged(Bool)
        case notifyWhenRunChanged(Bool)
        case datePresetChanged(DateRangePreset)
        case customStartChanged(Date)
        case customEndChanged(Date)
        case formatChanged(ExportFormat)
        case timeGroupingChanged(TimeGrouping)
        case triggerModeChanged(AutomationDraft.TriggerMode)
        case cadenceEveryChanged(Int)
        case cadenceUnitChanged(CadenceUnit)
        case medicationFrequencyChanged(MedicationBackgroundDeliveryFrequency)
        case saveButtonTapped
        case cancelButtonTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case save(AutomationDraft)
        case cancel
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .nameChanged(value):
                state.draft.name = value
                state.validationMessage = nil
                return .none

            case let .enabledChanged(value):
                state.draft.isEnabled = value
                return .none

            case let .notifyWhenRunChanged(value):
                state.draft.notifyWhenRun = value
                return .none

            case let .datePresetChanged(preset):
                state.draft.exportOptions.dateRange.preset = preset
                return .none

            case let .customStartChanged(date):
                state.draft.exportOptions.dateRange.customStart = date
                return .none

            case let .customEndChanged(date):
                state.draft.exportOptions.dateRange.customEnd = date
                return .none

            case let .formatChanged(format):
                state.draft.exportOptions.format = format
                return .none

            case let .timeGroupingChanged(grouping):
                state.draft.exportOptions.timeGrouping = grouping
                return .none

            case let .triggerModeChanged(mode):
                state.draft.triggerMode = mode
                return .none

            case let .cadenceEveryChanged(value):
                state.draft.cadenceEvery = min(max(value, 1), 5)
                return .none

            case let .cadenceUnitChanged(value):
                state.draft.cadenceUnit = value
                return .none

            case let .medicationFrequencyChanged(value):
                state.draft.medicationFrequency = value
                return .none

            case .saveButtonTapped:
                guard !state.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    state.validationMessage = "Automation name is required."
                    return .none
                }
                return .send(.delegate(.save(state.draft)))

            case .cancelButtonTapped:
                return .send(.delegate(.cancel))

            case .delegate:
                return .none
            }
        }
    }
}

