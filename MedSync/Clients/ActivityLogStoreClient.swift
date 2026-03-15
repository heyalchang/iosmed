import ComposableArchitecture
import Foundation

struct ActivityLogStoreClient: Sendable {
    var load: @Sendable () async throws -> [ActivityLogEntry]
    var append: @Sendable (ActivityLogEntry) async throws -> Void
    var clear: @Sendable () async throws -> Void
}

extension ActivityLogStoreClient: DependencyKey {
    static let liveValue: Self = {
        let store = ActivityLogFileStore()
        return Self(
            load: {
                try await store.load()
            },
            append: { entry in
                try await store.append(entry)
            },
            clear: {
                try await store.clear()
            }
        )
    }()

    static let testValue = Self(
        load: { [] },
        append: { _ in },
        clear: { }
    )
}

extension DependencyValues {
    var activityLogStore: ActivityLogStoreClient {
        get { self[ActivityLogStoreClient.self] }
        set { self[ActivityLogStoreClient.self] = newValue }
    }
}

actor ActivityLogFileStore {
    private let fileStore: JSONFileStore<[ActivityLogEntry]>

    init(fileStore: JSONFileStore<[ActivityLogEntry]> = JSONFileStore(filename: "activity-log.json", defaultValue: [])) {
        self.fileStore = fileStore
    }

    func load() async throws -> [ActivityLogEntry] {
        try await fileStore.load().sorted { $0.timestamp > $1.timestamp }
    }

    func append(_ entry: ActivityLogEntry) async throws {
        var entries = try await fileStore.load()
        entries.append(entry)
        try await fileStore.save(entries)
    }

    func clear() async throws {
        try await fileStore.save([])
    }
}
