import AppIntents
import Dependencies
import Foundation

struct AutomationAppEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Automation")
    static let defaultQuery = AutomationEntityQuery()

    let id: UUID
    let name: String
    let subtitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: subtitle)
        )
    }
}

struct AutomationEntityQuery: EntityQuery {
    func entities(for identifiers: [AutomationAppEntity.ID]) async throws -> [AutomationAppEntity] {
        let automations = try await AutomationEntityQueryService().load()
        let byID = Dictionary(uniqueKeysWithValues: automations.map { ($0.id, $0) })
        return identifiers.compactMap { id in
            guard let automation = byID[id] else { return nil }
            return AutomationAppEntity(
                id: automation.id,
                name: automation.name,
                subtitle: automation.trigger.displayName
            )
        }
    }

    func suggestedEntities() async throws -> [AutomationAppEntity] {
        try await AutomationEntityQueryService()
            .load()
            .map { automation in
                AutomationAppEntity(
                    id: automation.id,
                    name: automation.name,
                    subtitle: automation.trigger.displayName
                )
            }
    }
}

struct RunAutomationIntent: AppIntent {
    static let title: LocalizedStringResource = "Run Automation"
    static let description = IntentDescription("Runs one MedSync automation immediately.")
    static let openAppWhenRun = false

    @Parameter(title: "Automation")
    var automation: AutomationAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$automation)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (selectedAutomation, summary) = try await RunAutomationIntentService().run(automationID: automation.id)

        return .result(
            dialog: IntentDialog("Ran \(selectedAutomation.name) and wrote \(summary.filename).")
        )
    }
}

struct MedSyncShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunAutomationIntent(),
            phrases: [
                "Run \(\.$automation) in \(.applicationName)",
                "Export medications with \(\.$automation) in \(.applicationName)"
            ],
            shortTitle: "Run Automation",
            systemImageName: "square.and.arrow.up"
        )
    }
}

private actor AutomationEntityQueryService {
    @Dependency(\.automationStore) private var automationStore

    func load() async throws -> [Automation] {
        try await automationStore.load()
    }
}

private actor RunAutomationIntentService {
    @Dependency(\.automationExecution) private var automationExecution
    @Dependency(\.automationStore) private var automationStore

    func run(automationID: UUID) async throws -> (Automation, ExportRunSummary) {
        let automations = try await automationStore.load()
        guard let selectedAutomation = automations.first(where: { $0.id == automationID }) else {
            throw UserFacingError("The selected automation no longer exists.")
        }

        let summary = try await automationExecution.runAutomation(
            selectedAutomation,
            .shortcuts,
            nil
        )
        return (selectedAutomation, summary)
    }
}
