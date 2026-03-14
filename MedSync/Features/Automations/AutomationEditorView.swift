import SwiftUI
import ComposableArchitecture

struct AutomationEditorView: View {
    let store: StoreOf<AutomationEditorFeature>

    var body: some View {
        Form {
            Section("Identity") {
                TextField(
                    "Automation Name",
                    text: Binding(
                        get: { store.draft.name },
                        set: { store.send(.nameChanged($0)) }
                    )
                )
                Toggle(
                    "Enabled",
                    isOn: Binding(
                        get: { store.draft.isEnabled },
                        set: { store.send(.enabledChanged($0)) }
                    )
                )
                Toggle(
                    "Notify When Run",
                    isOn: Binding(
                        get: { store.draft.notifyWhenRun },
                        set: { store.send(.notifyWhenRunChanged($0)) }
                    )
                )
            }

            Section("Trigger") {
                Picker(
                    "Mode",
                    selection: Binding(
                        get: { store.draft.triggerMode },
                        set: { store.send(.triggerModeChanged($0)) }
                    )
                ) {
                    ForEach(AutomationDraft.TriggerMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if store.draft.triggerMode == .schedule {
                    Stepper(
                        value: Binding(
                            get: { store.draft.cadenceEvery },
                            set: { store.send(.cadenceEveryChanged($0)) }
                        ),
                        in: 1...5
                    ) {
                        Text("Every \(store.draft.cadenceEvery)")
                    }

                    Picker(
                        "Cadence Unit",
                        selection: Binding(
                            get: { store.draft.cadenceUnit },
                            set: { store.send(.cadenceUnitChanged($0)) }
                        )
                    ) {
                        ForEach(CadenceUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }

                    Text("iOS schedules this as best effort. The app will request background runs, but exact timing is not guaranteed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Picker(
                        "Background Delivery",
                        selection: Binding(
                            get: { store.draft.medicationFrequency },
                            set: { store.send(.medicationFrequencyChanged($0)) }
                        )
                    ) {
                        ForEach(MedicationBackgroundDeliveryFrequency.allCases) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }

                    Text("This marks the selected automation as the event-triggered export when a newly logged taken medication event wakes the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Export Options") {
                Picker(
                    "Date Range",
                    selection: Binding(
                        get: { store.draft.exportOptions.dateRange.preset },
                        set: { store.send(.datePresetChanged($0)) }
                    )
                ) {
                    ForEach(DateRangePreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                if store.draft.exportOptions.dateRange.preset == .custom {
                    DatePicker(
                        "Start",
                        selection: Binding(
                            get: { store.draft.exportOptions.dateRange.customStart },
                            set: { store.send(.customStartChanged($0)) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    DatePicker(
                        "End",
                        selection: Binding(
                            get: { store.draft.exportOptions.dateRange.customEnd },
                            set: { store.send(.customEndChanged($0)) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Picker(
                    "Format",
                    selection: Binding(
                        get: { store.draft.exportOptions.format },
                        set: { store.send(.formatChanged($0)) }
                    )
                ) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                Picker(
                    "Time Grouping",
                    selection: Binding(
                        get: { store.draft.exportOptions.timeGrouping },
                        set: { store.send(.timeGroupingChanged($0)) }
                    )
                ) {
                    ForEach(TimeGrouping.allCases) { grouping in
                        Text(grouping.displayName).tag(grouping)
                    }
                }
            }

            if let validationMessage = store.validationMessage {
                Section("Validation") {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(store.title)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    store.send(.cancelButtonTapped)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    store.send(.saveButtonTapped)
                }
            }
        }
    }
}

