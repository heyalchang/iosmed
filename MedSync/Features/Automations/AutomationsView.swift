import SwiftUI
import ComposableArchitecture

struct AutomationsView: View {
    @Bindable var store: StoreOf<AutomationsFeature>

    var body: some View {
        let automations = store.automations
        let isRunningAll = store.isRunningAll
        let statusMessage = store.statusMessage

        List {
            destinationSection(isRunningAll: isRunningAll, automations: automations)

            if automations.isEmpty {
                emptyStateSection
            } else {
                automationListSection(automations: automations)
            }

            if let statusMessage {
                statusSection(message: statusMessage)
            }
        }
        .navigationTitle("Automations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.addButtonTapped)
                } label: {
                    Label("New Automation", systemImage: "plus")
                }
            }
        }
        .task {
            await store.send(.task).finish()
        }
        .sheet(item: $store.scope(state: \.editor, action: \.editor)) { editorStore in
            NavigationStack {
                AutomationEditorView(store: editorStore)
            }
        }
    }

    @ViewBuilder
    private func destinationSection(
        isRunningAll: Bool,
        automations: IdentifiedArrayOf<Automation>
    ) -> some View {
        Section {
            LabeledContent("Destination", value: ExportFileLayout.destinationDescription)
            Button("Run All") {
                store.send(.runAllButtonTapped)
            }
            .disabled(automations.isEmpty || isRunningAll)
        }
    }

    private var emptyStateSection: some View {
        Section {
            ContentUnavailableView(
                "No Automations Yet",
                systemImage: "clock.badge.exclamationmark",
                description: Text("Create a medication export automation for iCloud Drive, or mark one automation as the medication-taken trigger.")
            )
        }
    }

    @ViewBuilder
    private func automationListSection(automations: IdentifiedArrayOf<Automation>) -> some View {
        Section("Automations") {
            ForEach(automations) { automation in
                AutomationRowView(
                    automation: automation,
                    onToggleEnabled: { isEnabled in
                        store.send(.toggleEnabled(automation.id, isEnabled))
                    },
                    onRunNow: {
                        store.send(.runNowButtonTapped(automation.id))
                    },
                    onEdit: {
                        store.send(.editButtonTapped(automation.id))
                    }
                )
            }
            .onDelete { offsets in
                store.send(.delete(offsets))
            }
        }
    }

    private func statusSection(message: String) -> some View {
        Section("Status") {
            Text(message)
        }
    }
}

private struct AutomationRowView: View {
    let automation: Automation
    let onToggleEnabled: (Bool) -> Void
    let onRunNow: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(automation.name)
                        .font(.headline)
                    Text(automation.trigger.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { automation.isEnabled },
                        set: { isEnabled in
                            onToggleEnabled(isEnabled)
                        }
                    )
                )
                .labelsHidden()
            }

            HStack {
                Text(automation.exportOptions.format.displayName)
                Text("•")
                Text(automation.exportOptions.dateRange.preset.displayName)
                Text("•")
                Text(automation.notifyWhenRun ? "Notify" : "Silent")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            HStack {
                Button("Run Now", action: onRunNow)
                Button("Edit", action: onEdit)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
