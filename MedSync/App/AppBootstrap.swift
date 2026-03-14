import Foundation

enum AppBootstrap {
    static func run() async {
        await MedicationTriggerClient.liveValue.start()

        let automations = (try? await AutomationStoreClient.liveValue.load()) ?? []
        await MedicationTriggerClient.liveValue.syncAutomationSelection(automations)
        await AutomationSchedulerClient.liveValue.syncAutomations(automations)
        await AutomationSchedulerClient.liveValue.refreshDueAutomations()
    }
}
