import ComposableArchitecture
import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

enum AutomationSchedulerConfiguration {
    static let refreshTaskIdentifier = "com.placeholder.MedSync.automation-refresh"
}

struct AutomationSchedulerClient: Sendable {
    var syncAutomations: @Sendable ([Automation]) async -> Void
    var handleAppRefresh: @Sendable () async -> Void
}

extension AutomationSchedulerClient: DependencyKey {
    static let liveValue: Self = {
        let service = AutomationSchedulerService()
        return Self(
            syncAutomations: { automations in
                await service.syncAutomations(automations)
            },
            handleAppRefresh: {
                await service.handleAppRefresh()
            }
        )
    }()

    static let testValue = Self(
        syncAutomations: { _ in },
        handleAppRefresh: { }
    )
}

extension DependencyValues {
    var automationScheduler: AutomationSchedulerClient {
        get { self[AutomationSchedulerClient.self] }
        set { self[AutomationSchedulerClient.self] = newValue }
    }
}

private actor AutomationSchedulerService {
    func syncAutomations(_ automations: [Automation]) async {
        let runtimeStore = AutomationRuntimeStoreClient.liveValue
        let runtimeState = try? await runtimeStore.update { state in
            let validAutomationIDs = Set(automations.map(\.id))
            let staleIDs = Set(state.scheduledRuns.map(\.automationID)).subtracting(validAutomationIDs)
            state.removeState(for: staleIDs)
        }

        await scheduleNextRefresh(
            for: automations,
            runtimeState: runtimeState ?? AutomationRuntimeState()
        )
    }

    func handleAppRefresh() async {
        let automationStore = AutomationStoreClient.liveValue
        let runtimeStore = AutomationRuntimeStoreClient.liveValue

        let automations = (try? await automationStore.load()) ?? []
        let runtimeState = (try? await runtimeStore.load()) ?? AutomationRuntimeState()
        let now = Date()
        let dueAutomations = AutomationSchedulePlanner.dueAutomations(
            from: automations,
            runtimeState: runtimeState,
            now: now
        )

        for automation in dueAutomations {
            _ = try? await AutomationExecutionClient.liveValue.runAutomation(
                automation,
                .scheduledBackground,
                nil
            )
        }

        _ = try? await runtimeStore.update { state in
            for automation in dueAutomations {
                state.recordScheduledAttempt(for: automation.id, at: now)
            }
            let validAutomationIDs = Set(automations.map(\.id))
            let staleIDs = Set(state.scheduledRuns.map(\.automationID)).subtracting(validAutomationIDs)
            state.removeState(for: staleIDs)
        }

        let refreshedState = (try? await runtimeStore.load()) ?? runtimeState
        await scheduleNextRefresh(for: automations, runtimeState: refreshedState)
    }

    private func scheduleNextRefresh(for automations: [Automation], runtimeState: AutomationRuntimeState) async {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: AutomationSchedulerConfiguration.refreshTaskIdentifier)

        guard let nextRefreshDate = AutomationSchedulePlanner.nextRefreshDate(
            from: automations,
            runtimeState: runtimeState
        ) else {
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: AutomationSchedulerConfiguration.refreshTaskIdentifier)
        request.earliestBeginDate = max(nextRefreshDate, Date())
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }
}
