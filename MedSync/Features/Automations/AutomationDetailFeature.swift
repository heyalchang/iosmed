import ComposableArchitecture

@Reducer
struct AutomationDetailFeature {
    @ObservableState
    struct State: Equatable {
        var automation: Automation
        var history: [ActivityLogEntry] = []
        var isLoading = false
        var errorMessage: String?
    }

    enum Action: Equatable {
        case task
        case historyResponse(Result<[ActivityLogEntry], UserFacingError>)
    }

    @Dependency(\.activityLogStore) var activityLogStore

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                let automationID = state.automation.id
                return .run { send in
                    do {
                        let entries = try await activityLogStore.load()
                            .filter { $0.automationID == automationID }
                        await send(.historyResponse(.success(entries)))
                    } catch {
                        await send(.historyResponse(.failure(UserFacingError(error.localizedDescription))))
                    }
                }

            case let .historyResponse(.success(entries)):
                state.isLoading = false
                state.history = entries
                return .none

            case let .historyResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.message
                return .none
            }
        }
    }
}
