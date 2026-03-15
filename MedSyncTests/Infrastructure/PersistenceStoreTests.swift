import XCTest
@testable import MedSync

final class PersistenceStoreTests: XCTestCase {
    func testAutomationFileStorePersistsSortedAutomationsAndDeletes() async throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let olderAutomation = Automation(
            name: "Older",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let newerAutomation = Automation(
            name: "Newer",
            createdAt: Date(timeIntervalSince1970: 101),
            updatedAt: Date(timeIntervalSince1970: 300)
        )

        let store = makeAutomationStore(directoryURL: directoryURL)
        _ = try await store.upsert(olderAutomation)
        _ = try await store.upsert(newerAutomation)

        let loaded = try await makeAutomationStore(directoryURL: directoryURL).load()
        XCTAssertEqual(loaded.map(\.id), [newerAutomation.id, olderAutomation.id])

        _ = try await makeAutomationStore(directoryURL: directoryURL).delete(olderAutomation.id)
        let remaining = try await makeAutomationStore(directoryURL: directoryURL).load()
        XCTAssertEqual(remaining.map(\.id), [newerAutomation.id])
    }

    func testActivityLogFileStoreAppendsSortedEntriesAndClears() async throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let olderEntry = ActivityLogEntry(
            eventType: .manualExport,
            triggerReason: .manualExport,
            status: .success,
            timestamp: Date(timeIntervalSince1970: 100)
        )
        let newerEntry = ActivityLogEntry(
            eventType: .automationRun,
            automationName: "Evening Export",
            triggerReason: .runNow,
            status: .failure,
            timestamp: Date(timeIntervalSince1970: 200),
            errorDetails: "boom"
        )

        let store = makeActivityLogStore(directoryURL: directoryURL)
        try await store.append(olderEntry)
        try await store.append(newerEntry)

        let loaded = try await makeActivityLogStore(directoryURL: directoryURL).load()
        XCTAssertEqual(loaded.map(\.id), [newerEntry.id, olderEntry.id])

        try await makeActivityLogStore(directoryURL: directoryURL).clear()
        let clearedEntries = try await makeActivityLogStore(directoryURL: directoryURL).load()
        XCTAssertTrue(clearedEntries.isEmpty)
    }

    func testAutomationRuntimeFileStorePersistsMutationAcrossReloads() async throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let automation = Automation(name: "Medication Export", trigger: .medicationTaken(.hourly))
        let anchorData = Data([0x0A, 0x0B])
        let triggeringEventID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        let createdAt = Date(timeIntervalSince1970: 500)
        let processedAt = Date(timeIntervalSince1970: 600)

        _ = try await makeRuntimeStore(directoryURL: directoryURL).update { state in
            state.stageMedicationTrigger(
                .init(
                    automation: automation,
                    queryAnchorData: anchorData,
                    triggeringEventIDs: [triggeringEventID],
                    createdAt: createdAt
                )
            )
        }

        let stagedState = try await makeRuntimeStore(directoryURL: directoryURL).load()
        XCTAssertEqual(stagedState.pendingMedicationTrigger?.automation.id, automation.id)
        XCTAssertEqual(stagedState.pendingMedicationTrigger?.queryAnchorData, anchorData)

        _ = try await makeRuntimeStore(directoryURL: directoryURL).update { state in
            state.commitPendingMedicationTrigger(processedAt: processedAt)
        }

        let committedState = try await makeRuntimeStore(directoryURL: directoryURL).load()
        XCTAssertNil(committedState.pendingMedicationTrigger)
        XCTAssertEqual(committedState.medicationQueryAnchorData, anchorData)
        XCTAssertEqual(committedState.processedMedicationTriggerEvents.map(\.eventID), [triggeringEventID])
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("medsync-store-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func makeAutomationStore(directoryURL: URL) -> AutomationFileStore {
        AutomationFileStore(
            fileStore: JSONFileStore(
                filename: "automations.json",
                defaultValue: [],
                directoryURL: directoryURL
            )
        )
    }

    private func makeActivityLogStore(directoryURL: URL) -> ActivityLogFileStore {
        ActivityLogFileStore(
            fileStore: JSONFileStore(
                filename: "activity-log.json",
                defaultValue: [],
                directoryURL: directoryURL
            )
        )
    }

    private func makeRuntimeStore(directoryURL: URL) -> AutomationRuntimeFileStore {
        AutomationRuntimeFileStore(
            fileStore: JSONFileStore(
                filename: "automation-runtime-state.json",
                defaultValue: AutomationRuntimeState(),
                directoryURL: directoryURL
            )
        )
    }
}
