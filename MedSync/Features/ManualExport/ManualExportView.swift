import SwiftUI
import ComposableArchitecture

struct ManualExportView: View {
    let store: StoreOf<ManualExportFeature>

    var body: some View {
        Form {
            Section("Destination") {
                LabeledContent("Files", value: ExportFileLayout.destinationDescription)
                Text("Exports are written into visible iCloud Drive folders and never overwrite an existing successful export.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Export Options") {
                Picker(
                    "Date Range",
                    selection: Binding(
                        get: { store.exportOptions.dateRange.preset },
                        set: { store.send(.datePresetChanged($0)) }
                    )
                ) {
                    ForEach(DateRangePreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                if store.exportOptions.dateRange.preset == .custom {
                    DatePicker(
                        "Start",
                        selection: Binding(
                            get: { store.exportOptions.dateRange.customStart },
                            set: { store.send(.customStartChanged($0)) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    DatePicker(
                        "End",
                        selection: Binding(
                            get: { store.exportOptions.dateRange.customEnd },
                            set: { store.send(.customEndChanged($0)) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Picker(
                    "Format",
                    selection: Binding(
                        get: { store.exportOptions.format },
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
                        get: { store.exportOptions.timeGrouping },
                        set: { store.send(.timeGroupingChanged($0)) }
                    )
                ) {
                    ForEach(TimeGrouping.allCases) { grouping in
                        Text(grouping.displayName).tag(grouping)
                    }
                }

                Text("Time grouping is stored now for future health-data phases. Medication exports in Phase 1 are event-based and not aggregated.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    store.send(.exportButtonTapped)
                } label: {
                    if store.isExporting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Export Now")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(store.isExporting)
            }

            if let resultMessage = store.resultMessage {
                Section("Status") {
                    Text(resultMessage)
                }
            }
        }
        .navigationTitle("Manual Export")
    }
}

