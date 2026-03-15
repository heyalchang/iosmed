import SwiftUI
import ComposableArchitecture

@main
struct MedSyncApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasBootstrapped = false

    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .task {
                    guard !AppRuntime.isRunningTests, !hasBootstrapped else { return }
                    hasBootstrapped = true
                    await AppBootstrap.run()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard !AppRuntime.isRunningTests, newPhase == .active, hasBootstrapped else { return }
            Task {
                await AppBootstrap.run()
            }
        }
        .backgroundTask(.appRefresh(AutomationSchedulerConfiguration.refreshTaskIdentifier)) {
            await AutomationSchedulerClient.liveValue.handleAppRefresh()
        }
    }
}
