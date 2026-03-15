import ComposableArchitecture
import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif
#if canImport(os)
import os
#endif

enum AutomationSchedulerConfiguration {
    static let fallbackSubsystem = "MedSync"

    static var currentRefreshTaskIdentifier: String {
        refreshTaskIdentifier(bundleIdentifier: Bundle.main.bundleIdentifier)
    }

    static var currentLoggerSubsystem: String {
        loggerSubsystem(bundleIdentifier: Bundle.main.bundleIdentifier)
    }

    static func refreshTaskIdentifier(bundleIdentifier: String?) -> String {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
            return "\(fallbackSubsystem).automation-refresh"
        }
        return "\(bundleIdentifier).automation-refresh"
    }

    static func loggerSubsystem(bundleIdentifier: String?) -> String {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
            return fallbackSubsystem
        }
        return bundleIdentifier
    }
}

struct AutomationSchedulerClient: Sendable {
    var syncAutomations: @Sendable ([Automation]) async -> Void
    var refreshDueAutomations: @Sendable () async -> Void
    var handleAppRefresh: @Sendable () async -> Void
}

extension AutomationSchedulerClient: DependencyKey {
    static let liveValue: Self = {
        let service = AutomationSchedulerService()
        return Self(
            syncAutomations: { automations in
                await service.syncAutomations(automations)
            },
            refreshDueAutomations: {
                await service.refreshDueAutomations()
            },
            handleAppRefresh: {
                await service.handleAppRefresh()
            }
        )
    }()

    static let testValue = Self(
        syncAutomations: { _ in },
        refreshDueAutomations: { },
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
    #if canImport(os)
    private let logger = Logger(
        subsystem: AutomationSchedulerConfiguration.currentLoggerSubsystem,
        category: "AutomationScheduler"
    )
    #endif

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
        await refreshDueAutomations()
    }

    func refreshDueAutomations() async {
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
            _ = try? await runtimeStore.update { state in
                state.recordScheduledAttempt(for: automation.id, at: Date())
            }
        }

        _ = try? await runtimeStore.update { state in
            let validAutomationIDs = Set(automations.map(\.id))
            let staleIDs = Set(state.scheduledRuns.map(\.automationID)).subtracting(validAutomationIDs)
            state.removeState(for: staleIDs)
        }

        let refreshedState = (try? await runtimeStore.load()) ?? runtimeState
        await scheduleNextRefresh(for: automations, runtimeState: refreshedState)
    }

    private func scheduleNextRefresh(for automations: [Automation], runtimeState: AutomationRuntimeState) async {
        #if canImport(BackgroundTasks)
        let refreshTaskIdentifier = AutomationSchedulerConfiguration.currentRefreshTaskIdentifier
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: refreshTaskIdentifier)

        guard let nextRefreshDate = AutomationSchedulePlanner.nextRefreshDate(
            from: automations,
            runtimeState: runtimeState
        ) else {
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = max(nextRefreshDate, Date())
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if canImport(os)
            logger.error("Failed to submit background refresh request: \(error.localizedDescription)")
            #endif
        }
        #endif
    }
}
