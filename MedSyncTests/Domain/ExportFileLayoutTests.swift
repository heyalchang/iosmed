import XCTest
@testable import MedSync

final class ExportFileLayoutTests: XCTestCase {
    func testManualExportPlanUsesMonthDirectory() {
        let date = ISO8601DateFormatter().date(from: "2026-03-14T11:05:00-07:00")!
        let request = ExportRequest.manual(MedicationExportOptions(format: .json))

        let plan = ExportFileLayout.plan(for: request, executedAt: date, runID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!)

        XCTAssertEqual(plan.relativeDirectory, "MedSync/Manual Exports/2026-03")
        XCTAssertTrue(plan.filename.hasPrefix("medications-manual-export-20260314T110500-0700-aaaaaaaa"))
        XCTAssertTrue(plan.filename.hasSuffix(".json"))
    }

    func testAutomationPlanSlugifiesName() {
        let date = ISO8601DateFormatter().date(from: "2026-03-14T11:05:00-07:00")!
        let automation = Automation(name: "PM Export / Med Trigger", exportOptions: MedicationExportOptions(format: .csv))
        let request = ExportRequest.automation(automation, triggerReason: .runNow)

        let plan = ExportFileLayout.plan(for: request, executedAt: date, runID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!)

        XCTAssertEqual(plan.relativeDirectory, "MedSync/Automations/pm-export-med-trigger/2026-03")
        XCTAssertTrue(plan.filename.hasPrefix("medications-pm-export-med-trigger-20260314T110500-0700-aaaaaaaa"))
        XCTAssertTrue(plan.filename.hasSuffix(".csv"))
    }
}

