import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        Form {
            Section("Phase 1 Scope") {
                Text("MedSync Phase 1 is medications only.")
                Text("The only live export destination is iCloud Drive > MedSync.")
                Text("Scheduled automation timing is best effort; iOS decides the actual execution time.")
            }

            Section("Medication Trigger") {
                Text("One automation can be marked as the medication-taken automation.")
                Text("That automation is the one MedSync will run after qualifying newly logged taken medication events wake the app.")
            }

            Section("Permissions") {
                LabeledContent("Notifications", value: store.notificationStatus.displayName)

                Button("Allow Notifications") {
                    store.send(.requestNotificationPermissionTapped)
                }

                Button("Request HealthKit Access") {
                    store.send(.requestHealthKitAccessTapped)
                }
            }

            if let statusMessage = store.statusMessage {
                Section("Status") {
                    Text(statusMessage)
                }
            }
        }
        .navigationTitle("Settings")
        .task {
            await store.send(.task).finish()
        }
    }
}
