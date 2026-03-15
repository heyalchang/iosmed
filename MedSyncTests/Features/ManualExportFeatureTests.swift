import ComposableArchitecture
import XCTest
@testable import MedSync

@MainActor
final class ManualExportFeatureTests: XCTestCase {
    func testExportSuccessUpdatesStatusMessage() async {
        let now = ISO8601DateFormatter().date(from: "2026-03-14T11:05:00-07:00")!
        let summary = ExportRunSummary(
            filename: "medications-manual-export.json",
            relativePath: "MedSync/Manual Exports/2026-03/medications-manual-export.json",
            recordCount: 2,
            destination: .iCloudDrive,
            format: .json,
            dateRangePreset: .lastWeek,
            dateRange: now...now,
            triggerReason: .manualExport,
            automationID: nil,
            automationName: nil
        )

        let store = TestStore(initialState: ManualExportFeature.State()) {
            ManualExportFeature()
        } withDependencies: {
            $0.automationExecution.runManualExport = { _ in summary }
        }

        await store.send(.exportButtonTapped) {
            $0.isExporting = true
            $0.resultMessage = nil
        }
        await store.receive(.exportResponse(.success(summary))) {
            $0.isExporting = false
            $0.resultMessage = "Saved medications-manual-export.json to Files > iCloud Drive > MedSync."
        }
    }
}
