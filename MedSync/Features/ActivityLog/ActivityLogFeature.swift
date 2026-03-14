import ComposableArchitecture

@Reducer
struct ActivityLogFeature {
    @ObservableState
    struct State: Equatable {
        var entries: [ActivityLogEntry] = []
        var isLoading = false
        var errorMessage: String?
    }

    enum Action: Equatable {
        case task
        case logsResponse(Result<[ActivityLogEntry], UserFacingError>)
    }

    @Dependency(\.activityLogStore) var activityLogStore

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { send in
                    do {
                        let entries = try await activityLogStore.load()
                        await send(.logsResponse(.success(entries)))
                    } catch {
                        await send(.logsResponse(.failure(UserFacingError(error.localizedDescription))))
                    }
                }

            case let .logsResponse(.success(entries)):
                state.isLoading = false
                state.entries = entries
                return .none

            case let .logsResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.message
                return .none
            }
        }
    }
}
