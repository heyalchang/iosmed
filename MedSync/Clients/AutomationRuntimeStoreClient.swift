import ComposableArchitecture
import Foundation

struct AutomationRuntimeStoreClient: Sendable {
    var load: @Sendable () async throws -> AutomationRuntimeState
    var update: @Sendable (@escaping @Sendable (inout AutomationRuntimeState) -> Void) async throws -> AutomationRuntimeState
}

extension AutomationRuntimeStoreClient: DependencyKey {
    static let liveValue: Self = {
        let store = AutomationRuntimeFileStore()
        return Self(
            load: {
                try await store.load()
            },
            update: { mutation in
                try await store.update(mutation)
            }
        )
    }()

    static let testValue = Self(
        load: { AutomationRuntimeState() },
        update: { mutation in
            var state = AutomationRuntimeState()
            mutation(&state)
            return state
        }
    )
}

extension DependencyValues {
    var automationRuntimeStore: AutomationRuntimeStoreClient {
        get { self[AutomationRuntimeStoreClient.self] }
        set { self[AutomationRuntimeStoreClient.self] = newValue }
    }
}

actor AutomationRuntimeFileStore {
    private let fileStore: JSONFileStore<AutomationRuntimeState>

    init(
        fileStore: JSONFileStore<AutomationRuntimeState> = JSONFileStore(
            filename: "automation-runtime-state.json",
            defaultValue: AutomationRuntimeState()
        )
    ) {
        self.fileStore = fileStore
    }

    func load() async throws -> AutomationRuntimeState {
        try await fileStore.load()
    }

    func update(_ mutation: @Sendable (inout AutomationRuntimeState) -> Void) async throws -> AutomationRuntimeState {
        var state = try await fileStore.load()
        mutation(&state)
        try await fileStore.save(state)
        return state
    }
}
