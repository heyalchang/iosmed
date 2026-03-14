import SwiftUI
import ComposableArchitecture

struct AutomationDetailView: View {
    let store: StoreOf<AutomationDetailFeature>

    var body: some View {
        List {
            summarySection
            historySection

            if let errorMessage = store.errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(store.automation.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.send(.task).finish()
        }
    }

    private var summarySection: some View {
        Section("Automation") {
            LabeledContent("Trigger", value: store.automation.trigger.displayName)
            LabeledContent("Status", value: store.automation.isEnabled ? "Enabled" : "Disabled")
            LabeledContent("Notifications", value: store.automation.notifyWhenRun ? "On" : "Off")
            LabeledContent("Format", value: store.automation.exportOptions.format.displayName)
            LabeledContent("Date Range", value: store.automation.exportOptions.dateRange.preset.displayName)
            LabeledContent("Time Grouping", value: store.automation.exportOptions.timeGrouping.displayName)
            LabeledContent("Destination", value: ExportFileLayout.destinationDescription)

            if store.automation.trigger.scheduledCadence != nil {
                Text("Scheduled automations are requested as best effort background runs. iOS decides the actual execution time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("This automation runs when a newly logged taken medication event wakes the app through HealthKit background delivery.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        Section("History") {
            if store.isLoading {
                ProgressView()
            } else if store.history.isEmpty {
                ContentUnavailableView(
                    "No Automation Activity Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Runs and lifecycle events for this automation will appear here.")
                )
            } else {
                ForEach(store.history) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.message ?? entry.eventType.rawValue)
                                .font(.headline)
                            Spacer()
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
        }
    }
}
