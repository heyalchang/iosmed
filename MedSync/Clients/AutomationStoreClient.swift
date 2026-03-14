import ComposableArchitecture
import Foundation

struct AutomationStoreClient: Sendable {
    var load: @Sendable () async throws -> [Automation]
    var upsert: @Sendable (Automation) async throws -> [Automation]
    var delete: @Sendable (UUID) async throws -> [Automation]
}

extension AutomationStoreClient: DependencyKey {
    static let liveValue: Self = {
        let store = AutomationFileStore()
        return Self(
            load: {
                try await store.load()
            },
            upsert: { automation in
                try await store.upsert(automation)
            },
            delete: { id in
                try await store.delete(id)
            }
        )
    }()

    static let testValue = Self(
        load: { [] },
        upsert: { _ in [] },
        delete: { _ in [] }
    )
}

extension DependencyValues {
    var automationStore: AutomationStoreClient {
        get { self[AutomationStoreClient.self] }
        set { self[AutomationStoreClient.self] = newValue }
    }
}

private actor AutomationFileStore {
    private let fileStore = JSONFileStore<[Automation]>(filename: "automations.json", defaultValue: [])

    func load() async throws -> [Automation] {
        try await fileStore.load().sorted { $0.updatedAt > $1.updatedAt }
    }

    func upsert(_ automation: Automation) async throws -> [Automation] {
        var automations = try await fileStore.load()
        if let index = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[index] = automation
        } else {
            automations.append(automation)
        }
        try await fileStore.save(automations)
        return automations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func delete(_ id: UUID) async throws -> [Automation] {
        var automations = try await fileStore.load()
        automations.removeAll { $0.id == id }
        try await fileStore.save(automations)
        return automations.sorted { $0.updatedAt > $1.updatedAt }
    }
}
