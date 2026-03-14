import SwiftUI
import ComposableArchitecture

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        TabView(
            selection: Binding(
                get: { store.selectedTab },
                set: { store.send(.selectedTabChanged($0)) }
            )
        ) {
            NavigationStack {
                ManualExportView(
                    store: store.scope(state: \.manualExport, action: \.manualExport)
                )
            }
            .tabItem {
                Label("Manual Export", systemImage: "square.and.arrow.up")
            }
            .tag(AppFeature.Tab.manualExport)

            NavigationStack {
                AutomationsView(
                    store: store.scope(state: \.automations, action: \.automations)
                )
            }
            .tabItem {
                Label("Automations", systemImage: "clock.arrow.circlepath")
            }
            .tag(AppFeature.Tab.automations)

            NavigationStack {
                ActivityLogView(
                    store: store.scope(state: \.activityLog, action: \.activityLog)
                )
            }
            .tabItem {
                Label("Activity Log", systemImage: "list.bullet.rectangle")
            }
            .tag(AppFeature.Tab.activityLog)

            NavigationStack {
                SettingsView(
                    store: store.scope(state: \.settings, action: \.settings)
                )
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppFeature.Tab.settings)
        }
    }
}

