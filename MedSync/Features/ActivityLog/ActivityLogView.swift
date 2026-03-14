import SwiftUI
import ComposableArchitecture

struct ActivityLogView: View {
    let store: StoreOf<ActivityLogFeature>

    var body: some View {
        List {
            if store.entries.isEmpty {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "list.bullet.rectangle.portrait",
                    description: Text("Manual exports, automation runs, and automation lifecycle events will appear here.")
                )
            } else {
                ForEach(store.entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.message ?? entry.eventType.rawValue)
                                .font(.headline)
                            Spacer()
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let automationName = entry.automationName {
                            Text(automationName)
                                .font(.subheadline)
                        }

                        HStack {
                            Text(entry.status.rawValue.capitalized)
                            if let triggerReason = entry.triggerReason {
                                Text("•")
                                Text(triggerReason.displayName)
                            }
                            if let filename = entry.filename, !filename.isEmpty {
                                Text("•")
                                Text(filename)
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        if let errorDetails = entry.errorDetails {
                            Text(errorDetails)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let errorMessage = store.errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Activity Log")
        .task {
            await store.send(.task).finish()
        }
    }
}

