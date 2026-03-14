import ComposableArchitecture
import XCTest
@testable import MedSync

@MainActor
final class AutomationsFeatureTests: XCTestCase {
    func testToggleEnabledPersistsAndSyncsSchedulers() async {
        let now = ISO8601DateFormatter().date(from: "2026-03-14T11:05:00-07:00")!
        let automation = Automation(name: "Morning Export", trigger: .schedule(ScheduledCadence(every: 2, unit: .hours)))
        let capture = AutomationSyncCapture()

        let store = TestStore(
            initialState: AutomationsFeature.State(automations: [automation])
        ) {
            AutomationsFeature()
        } withDependencies: {
            $0.automationStore.upsert = { updatedAutomation in
                [updatedAutomation]
            }
            $0.activityLogStore.append = { _ in }
            $0.medicationTriggerClient.syncAutomationSelection = { automations in
                await capture.recordMedicationSync(automations)
            }
            $0.automationScheduler.syncAutomations = { automations in
                await capture.recordSchedulerSync(automations)
            }
            $0.date.now = now
        }

        await store.send(.toggleEnabled(automation.id, false)) {
            $0.automations[id: automation.id]?.isEnabled = false
            $0.automations[id: automation.id]?.updatedAt = now
        }
        await store.receive(.saveAutomationResponse(.success([
            Automation(
                id: automation.id,
                name: automation.name,
                isEnabled: false,
                notifyWhenRun: automation.notifyWhenRun,
                exportOptions: automation.exportOptions,
                trigger: automation.trigger,
                createdAt: automation.createdAt,
                updatedAt: now
            )
        ]), savedAutomation: Automation(
            id: automation.id,
            name: automation.name,
            isEnabled: false,
            notifyWhenRun: automation.notifyWhenRun,
            exportOptions: automation.exportOptions,
            trigger: automation.trigger,
            createdAt: automation.createdAt,
            updatedAt: now
        ), actionLabel: "Updated automation")) {
            $0.automations = [
                Automation(
                    id: automation.id,
                    name: automation.name,
                    isEnabled: false,
                    notifyWhenRun: automation.notifyWhenRun,
                    exportOptions: automation.exportOptions,
                    trigger: automation.trigger,
                    createdAt: automation.createdAt,
                    updatedAt: now
                )
            ]
            $0.statusMessage = "Updated automation: Morning Export"
        }

        let medicationSyncs = await capture.medicationSyncs
        let schedulerSyncs = await capture.schedulerSyncs
        XCTAssertEqual(medicationSyncs.count, 1)
        XCTAssertEqual(schedulerSyncs.count, 1)
        XCTAssertEqual(medicationSyncs.first?.first?.isEnabled, false)
        XCTAssertEqual(schedulerSyncs.first?.first?.isEnabled, false)
    }

    func testMedicationTriggerConflictIsRejected() async {
        let now = ISO8601DateFormatter().date(from: "2026-03-14T11:05:00-07:00")!
        let existing = Automation(
            name: "Taken Export",
            trigger: .medicationTaken(.immediate)
        )
        var state = AutomationsFeature.State(automations: [existing])
        state.editor = AutomationEditorFeature.State(
            draft: medicationTriggerDraft(name: "Second Trigger", frequency: .hourly)
        )

        let store = TestStore(initialState: state) {
            AutomationsFeature()
        } withDependencies: {
            $0.date.now = now
        }

        await store.send(
            .editor(
                .presented(
                    .delegate(
                        .save(
                            medicationTriggerDraft(name: "Second Trigger", frequency: .hourly)
                        )
                    )
                )
            )
        ) {
            $0.statusMessage = "Only one automation can be marked for medication-taken background delivery."
        }
    }

    func testTaskLoadsAutomations() async {
        let automation = Automation(name: "Morning Export")

        let store = TestStore(initialState: AutomationsFeature.State()) {
            AutomationsFeature()
        } withDependencies: {
            $0.automationStore.load = { [automation] }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(.automationsResponse(.success([automation]))) {
            $0.isLoading = false
            $0.automations = [automation]
        }
    }
}

private actor AutomationSyncCapture {
    private(set) var medicationSyncs: [[Automation]] = []
    private(set) var schedulerSyncs: [[Automation]] = []

    func recordMedicationSync(_ automations: [Automation]) {
        medicationSyncs.append(automations)
    }

    func recordSchedulerSync(_ automations: [Automation]) {
        schedulerSyncs.append(automations)
    }
}

private func medicationTriggerDraft(
    name: String,
    frequency: MedicationBackgroundDeliveryFrequency
) -> AutomationDraft {
    var draft = AutomationDraft()
    draft.name = name
    draft.triggerMode = .medicationTaken
    draft.medicationFrequency = frequency
    draft.cadenceUnit = .hours
    return draft
}
