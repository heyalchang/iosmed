import ComposableArchitecture
import Foundation

@Reducer
struct AutomationsFeature {
    @ObservableState
    struct State: Equatable {
        var automations: IdentifiedArrayOf<Automation> = []
        @Presents var editor: AutomationEditorFeature.State?
        @Presents var detail: AutomationDetailFeature.State?
        var isLoading = false
        var isRunningAll = false
        var statusMessage: String?
    }

    enum Action: Equatable {
        case task
        case automationsResponse(Result<[Automation], UserFacingError>)
        case automationTapped(UUID)
        case addButtonTapped
        case editButtonTapped(UUID)
        case delete(IndexSet)
        case toggleEnabled(UUID, Bool)
        case runNowButtonTapped(UUID)
        case runAllButtonTapped
        case runAllCompleted(successCount: Int, failureCount: Int)
        case detail(PresentationAction<AutomationDetailFeature.Action>)
        case editor(PresentationAction<AutomationEditorFeature.Action>)
        case saveAutomationResponse(Result<[Automation], UserFacingError>, savedAutomation: Automation, actionLabel: String)
        case deleteAutomationResponse(Result<[Automation], UserFacingError>)
        case runResponse(Result<ExportRunSummary, UserFacingError>)
    }

    @Dependency(\.automationStore) var automationStore
    @Dependency(\.activityLogStore) var activityLogStore
    @Dependency(\.automationExecution) var automationExecution
    @Dependency(\.medicationTriggerClient) var medicationTriggerClient
    @Dependency(\.automationScheduler) var automationScheduler
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { send in
                    do {
                        let automations = try await automationStore.load()
                        await send(.automationsResponse(.success(automations)))
                    } catch {
                        await send(.automationsResponse(.failure(UserFacingError(error.localizedDescription))))
                    }
                }

            case let .automationsResponse(.success(automations)):
                state.isLoading = false
                state.automations = IdentifiedArray(uniqueElements: automations)
                return .none

            case let .automationsResponse(.failure(error)):
                state.isLoading = false
                state.statusMessage = error.message
                return .none

            case let .automationTapped(id):
                guard let automation = state.automations[id: id] else { return .none }
                state.detail = AutomationDetailFeature.State(automation: automation)
                return .none

            case .addButtonTapped:
                state.editor = AutomationEditorFeature.State(draft: AutomationDraft())
                return .none

            case let .editButtonTapped(id):
                guard let automation = state.automations[id: id] else { return .none }
                state.editor = AutomationEditorFeature.State(draft: AutomationDraft(automation: automation))
                return .none

            case let .delete(offsets):
                let ids = offsets.compactMap { state.automations[safe: $0]?.id }
                guard let id = ids.first else { return .none }
                guard let automation = state.automations[id: id] else { return .none }
                return .run { [automation, now] send in
                    do {
                        let automations = try await automationStore.delete(id)
                        try await activityLogStore.append(.automationLifecycle(action: "Deleted automation", automation: automation, timestamp: now))
                        await medicationTriggerClient.syncAutomationSelection(automations)
                        await automationScheduler.syncAutomations(automations)
                        await send(.deleteAutomationResponse(.success(automations)))
                    } catch {
                        await send(.deleteAutomationResponse(.failure(UserFacingError(error.localizedDescription))))
                    }
                }

            case let .toggleEnabled(id, isEnabled):
                guard var automation = state.automations[id: id] else { return .none }
                automation.isEnabled = isEnabled
                automation.updatedAt = now
                state.automations[id: id] = automation
                if state.detail?.automation.id == automation.id {
                    state.detail?.automation = automation
                }
                return persist(automation: automation, actionLabel: "Updated automation")

            case let .runNowButtonTapped(id):
                guard let automation = state.automations[id: id] else { return .none }
                return runAutomation(automation, triggerReason: .runNow)

            case .runAllButtonTapped:
                let enabledAutomations = state.automations.elements.filter(\.isEnabled)
                guard !enabledAutomations.isEmpty else {
                    state.statusMessage = "No enabled automations are available to run."
                    return .none
                }

                state.isRunningAll = true
                return .run { [enabledAutomations] send in
                    var successCount = 0
                    var failureCount = 0
                    for automation in enabledAutomations {
                        do {
                            _ = try await automationExecution.runAutomation(automation, .runAll, nil)
                            successCount += 1
                        } catch {
                            failureCount += 1
                        }
                    }
                    await send(.runAllCompleted(successCount: successCount, failureCount: failureCount))
                }

            case let .runAllCompleted(successCount, failureCount):
                state.isRunningAll = false
                state.statusMessage = "Run All finished. Successes: \(successCount). Failures: \(failureCount)."
                return .none

            case .editor(.presented(.delegate(.cancel))):
                state.editor = nil
                return .none

            case let .editor(.presented(.delegate(.save(draft)))):
                let automation = draft.makeAutomation(now: now)
                if automation.trigger.medicationFrequency != nil {
                    let conflicting = state.automations.elements.first {
                        $0.id != automation.id && $0.trigger.medicationFrequency != nil
                    }
                    if conflicting != nil {
                        state.statusMessage = "Only one automation can be marked for medication-taken background delivery."
                        return .none
                    }
                }

                state.editor = nil
                let actionLabel = state.automations[id: automation.id] == nil ? "Created automation" : "Edited automation"
                return persist(automation: automation, actionLabel: actionLabel)

            case .editor:
                return .none

            case .detail:
                return .none

            case let .saveAutomationResponse(.success(automations), savedAutomation, actionLabel):
                state.automations = IdentifiedArray(uniqueElements: automations)
                if state.detail?.automation.id == savedAutomation.id {
                    state.detail?.automation = savedAutomation
                }
                state.statusMessage = "\(actionLabel): \(savedAutomation.name)"
                return .none

            case let .saveAutomationResponse(.failure(error), _, _):
                state.statusMessage = error.message
                return .none

            case let .deleteAutomationResponse(.success(automations)):
                let deletedDetailID = state.detail?.automation.id
                state.automations = IdentifiedArray(uniqueElements: automations)
                if let deletedDetailID, !automations.contains(where: { $0.id == deletedDetailID }) {
                    state.detail = nil
                }
                state.statusMessage = "Automation deleted."
                return .none

            case let .deleteAutomationResponse(.failure(error)):
                state.statusMessage = error.message
                return .none

            case let .runResponse(.success(summary)):
                state.statusMessage = "Ran \(summary.automationName ?? "automation") and wrote \(summary.filename)."
                return .none

            case let .runResponse(.failure(error)):
                state.statusMessage = error.message
                return .none
            }
        }
        .ifLet(\.$editor, action: \.editor) {
            AutomationEditorFeature()
        }
        .ifLet(\.$detail, action: \.detail) {
            AutomationDetailFeature()
        }
    }

    private func persist(automation: Automation, actionLabel: String) -> Effect<Action> {
        .run { [automation, actionLabel, now] send in
            do {
                let automations = try await automationStore.upsert(automation)
                try await activityLogStore.append(.automationLifecycle(action: actionLabel, automation: automation, timestamp: now))
                await medicationTriggerClient.syncAutomationSelection(automations)
                await automationScheduler.syncAutomations(automations)
                await send(.saveAutomationResponse(.success(automations), savedAutomation: automation, actionLabel: actionLabel))
            } catch {
                await send(.saveAutomationResponse(.failure(UserFacingError(error.localizedDescription)), savedAutomation: automation, actionLabel: actionLabel))
            }
        }
    }

    private func runAutomation(_ automation: Automation, triggerReason: TriggerReason) -> Effect<Action> {
        .run { [automation, triggerReason] send in
            do {
                let summary = try await automationExecution.runAutomation(automation, triggerReason, nil)
                await send(.runResponse(.success(summary)))
            } catch {
                await send(.runResponse(.failure(UserFacingError(error.localizedDescription))))
            }
        }
    }
}

private extension IdentifiedArray where Element == Automation {
    subscript(safe index: Int) -> Automation? {
        indices.contains(index) ? self[index] : nil
    }
}
