import ComposableArchitecture
import Foundation

@Reducer
struct AutomationDetailFeature {
    struct LoadResult: Equatable {
        var history: [ActivityLogEntry]
        var lastScheduledAttempt: Date?
        var nextEligibleRun: Date?
    }

    @ObservableState
    struct State: Equatable {
        var automation: Automation
        var history: [ActivityLogEntry] = []
        var lastScheduledAttempt: Date?
        var nextEligibleRun: Date?
        var isLoading = false
        var errorMessage: String?
    }

    enum Action: Equatable {
        case task
        case historyResponse(Result<LoadResult, UserFacingError>)
    }

    @Dependency(\.activityLogStore) var activityLogStore
    @Dependency(\.automationRuntimeStore) var automationRuntimeStore

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                let automationID = state.automation.id
                let automation = state.automation
                return .run { send in
                    do {
                        async let historyTask = activityLogStore.load()
                        async let runtimeStateTask = automationRuntimeStore.load()

                        let entries = try await historyTask
                            .filter { $0.automationID == automationID }
                        let runtimeState = try await runtimeStateTask
                        await send(
                            .historyResponse(
                                .success(
                                    LoadResult(
                                        history: entries,
                                        lastScheduledAttempt: runtimeState.lastScheduledAttempt(for: automationID),
                                        nextEligibleRun: AutomationSchedulePlanner.nextDueDate(
                                            for: automation,
                                            runtimeState: runtimeState
                                        )
                                    )
                                )
                            )
                        )
                    } catch {
                        await send(.historyResponse(.failure(UserFacingError(error.localizedDescription))))
                    }
                }

            case let .historyResponse(.success(result)):
                state.isLoading = false
                state.history = result.history
                state.lastScheduledAttempt = result.lastScheduledAttempt
                state.nextEligibleRun = result.nextEligibleRun
                return .none

            case let .historyResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.message
                return .none
            }
        }
    }
}
