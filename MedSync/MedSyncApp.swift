import SwiftUI
import ComposableArchitecture

@main
struct MedSyncApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    init() {
        if !AppRuntime.isRunningTests {
            Task {
                await AppBootstrap.run()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
        .backgroundTask(.appRefresh(AutomationSchedulerConfiguration.refreshTaskIdentifier)) {
            await AutomationSchedulerClient.liveValue.handleAppRefresh()
        }
    }
}
