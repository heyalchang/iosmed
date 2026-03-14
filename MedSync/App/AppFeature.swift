import ComposableArchitecture

@Reducer
struct AppFeature {
    enum Tab: Hashable {
        case manualExport
        case automations
        case activityLog
        case settings
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .manualExport
        var manualExport = ManualExportFeature.State()
        var automations = AutomationsFeature.State()
        var activityLog = ActivityLogFeature.State()
        var settings = SettingsFeature.State()
    }

    enum Action: Equatable {
        case selectedTabChanged(Tab)
        case manualExport(ManualExportFeature.Action)
        case automations(AutomationsFeature.Action)
        case activityLog(ActivityLogFeature.Action)
        case settings(SettingsFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.manualExport, action: \.manualExport) {
            ManualExportFeature()
        }
        Scope(state: \.automations, action: \.automations) {
            AutomationsFeature()
        }
        Scope(state: \.activityLog, action: \.activityLog) {
            ActivityLogFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }

        Reduce { state, action in
            switch action {
            case let .selectedTabChanged(tab):
                state.selectedTab = tab
                return .none

            case .manualExport, .automations, .activityLog, .settings:
                return .none
            }
        }
    }
}

