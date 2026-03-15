import ComposableArchitecture
import XCTest
@testable import MedSync

final class AutomationExecutionClientTests: XCTestCase {
    func testRunManualExportSuccessAppendsStructuredLog() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let summary = makeSummary(triggerReason: .manualExport)
        let activityLogRecorder = ActivityLogRecorder()

        let result = try await withDependencies {
            $0.date.now = now
            $0.exportRunner.run = { request in
                XCTAssertEqual(request.triggerReason, .manualExport)
                return summary
            }
            $0.activityLogStore.append = { entry in
                await activityLogRecorder.append(entry)
            }
        } operation: {
            try await AutomationExecutionClient.liveValue.runManualExport(MedicationExportOptions())
        }

        XCTAssertEqual(result, summary)
        let entries = await activityLogRecorder.snapshot()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].eventType, .manualExport)
        XCTAssertEqual(entries[0].status, .success)
        XCTAssertEqual(entries[0].triggerReason, .manualExport)
        XCTAssertEqual(entries[0].filename, summary.filename)
    }

    func testRunAutomationSuccessLogsAndSendsNotification() async throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let automation = Automation(name: "Evening Export", notifyWhenRun: true)
        let summary = makeSummary(
            triggerReason: .runNow,
            automationID: automation.id,
            automationName: automation.name
        )
        let activityLogRecorder = ActivityLogRecorder()
        let notificationRecorder = NotificationRecorder()

        let result = try await withDependencies {
            $0.date.now = now
            $0.exportRunner.run = { request in
                XCTAssertEqual(request.triggerReason, .runNow)
                XCTAssertEqual(request.automation?.id, automation.id)
                return summary
            }
            $0.activityLogStore.append = { entry in
                await activityLogRecorder.append(entry)
            }
            $0.localNotifications.sendAutomationRunNotification = { payload in
                await notificationRecorder.record(payload)
            }
        } operation: {
            try await AutomationExecutionClient.liveValue.runAutomation(
                automation,
                .runNow,
                "Triggered manually"
            )
        }

        XCTAssertEqual(result, summary)
        let entries = await activityLogRecorder.snapshot()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].eventType, .automationRun)
        XCTAssertEqual(entries[0].status, .success)
        XCTAssertEqual(entries[0].message, "Triggered manually")

        let payloads = await notificationRecorder.snapshot()
        XCTAssertEqual(payloads, [
            AutomationNotificationPayload(
                automationName: automation.name,
                triggerReason: .runNow,
                status: .success,
                filename: summary.filename,
                errorMessage: nil
            )
        ])
    }

    func testRunAutomationFailureLogsAndSendsFailureNotification() async {
        let now = Date(timeIntervalSince1970: 3_000)
        let automation = Automation(name: "Evening Export", notifyWhenRun: true)
        let activityLogRecorder = ActivityLogRecorder()
        let notificationRecorder = NotificationRecorder()

        do {
            _ = try await withDependencies {
                $0.date.now = now
                $0.exportRunner.run = { _ in
                    throw TestExecutionError.boom
                }
                $0.activityLogStore.append = { entry in
                    await activityLogRecorder.append(entry)
                }
                $0.localNotifications.sendAutomationRunNotification = { payload in
                    await notificationRecorder.record(payload)
                }
            } operation: {
                try await AutomationExecutionClient.liveValue.runAutomation(
                    automation,
                    .scheduledBackground,
                    "Background catch-up"
                )
            }
            XCTFail("Expected automation execution to throw")
        } catch let error as UserFacingError {
            XCTAssertEqual(error, UserFacingError("boom"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let entries = await activityLogRecorder.snapshot()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].eventType, .automationRun)
        XCTAssertEqual(entries[0].status, .failure)
        XCTAssertEqual(entries[0].triggerReason, .scheduledBackground)
        XCTAssertEqual(entries[0].message, "Background catch-up")
        XCTAssertEqual(entries[0].errorDetails, "boom")

        let payloads = await notificationRecorder.snapshot()
        XCTAssertEqual(payloads, [
            AutomationNotificationPayload(
                automationName: automation.name,
                triggerReason: .scheduledBackground,
                status: .failure,
                filename: nil,
                errorMessage: "boom"
            )
        ])
    }

    private func makeSummary(
        triggerReason: TriggerReason,
        automationID: UUID? = nil,
        automationName: String? = nil
    ) -> ExportRunSummary {
        let now = Date(timeIntervalSince1970: 1_000)
        return ExportRunSummary(
            filename: "medications.json",
            relativePath: "MedSync/medications.json",
            recordCount: 2,
            destination: .iCloudDrive,
            format: .json,
            dateRangePreset: .lastWeek,
            dateRange: now...now,
            triggerReason: triggerReason,
            automationID: automationID,
            automationName: automationName
        )
    }
}

private actor ActivityLogRecorder {
    private var entries: [ActivityLogEntry] = []

    func append(_ entry: ActivityLogEntry) {
        entries.append(entry)
    }

    func snapshot() -> [ActivityLogEntry] {
        entries
    }
}

private actor NotificationRecorder {
    private var payloads: [AutomationNotificationPayload] = []

    func record(_ payload: AutomationNotificationPayload) {
        payloads.append(payload)
    }

    func snapshot() -> [AutomationNotificationPayload] {
        payloads
    }
}

private enum TestExecutionError: LocalizedError {
    case boom

    var errorDescription: String? {
        "boom"
    }
}
