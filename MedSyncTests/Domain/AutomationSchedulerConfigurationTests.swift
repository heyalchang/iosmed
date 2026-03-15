import XCTest
@testable import MedSync

final class AutomationSchedulerConfigurationTests: XCTestCase {
    func testRefreshTaskIdentifierUsesBundleIdentifierNamespace() {
        XCTAssertEqual(
            AutomationSchedulerConfiguration.refreshTaskIdentifier(
                bundleIdentifier: "com.example.MedSync"
            ),
            "com.example.MedSync.automation-refresh"
        )
    }

    func testRefreshTaskIdentifierFallsBackWhenBundleIdentifierMissing() {
        XCTAssertEqual(
            AutomationSchedulerConfiguration.refreshTaskIdentifier(bundleIdentifier: nil),
            "MedSync.automation-refresh"
        )
    }

    func testLoggerSubsystemFallsBackWhenBundleIdentifierMissing() {
        XCTAssertEqual(
            AutomationSchedulerConfiguration.loggerSubsystem(bundleIdentifier: nil),
            "MedSync"
        )
    }
}
