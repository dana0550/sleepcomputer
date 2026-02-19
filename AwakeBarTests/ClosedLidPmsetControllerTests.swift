import XCTest
@testable import AwakeBar

@MainActor
final class ClosedLidPmsetControllerTests: XCTestCase {
    func testSetEnabledThrowsWhenSetupNotReady() async {
        let daemon = MockDaemonClient()
        let setup = MockSetupController(state: .notRegistered)
        let controller = ClosedLidPmsetController(daemonClient: daemon, setupController: setup)

        do {
            try await controller.setEnabled(true)
            XCTFail("Expected setup-required error")
        } catch let ClosedLidControlError.setupRequired(state) {
            XCTAssertEqual(state, .notRegistered)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(daemon.setCalls, [])
    }

    func testReadSleepDisabledUsesDaemonWhenReady() async throws {
        let daemon = MockDaemonClient()
        daemon.sleepDisabledValue = true
        let setup = MockSetupController(state: .ready)
        let controller = ClosedLidPmsetController(daemonClient: daemon, setupController: setup)

        let value = try await controller.readSleepDisabled()

        XCTAssertTrue(value)
        XCTAssertEqual(daemon.readCalls, 1)
    }

    func testCaptureManagedOverridesReadsBaselineWhenReady() async throws {
        let daemon = MockDaemonClient()
        daemon.sleepDisabledValue = true
        let setup = MockSetupController(state: .ready)
        let controller = ClosedLidPmsetController(daemonClient: daemon, setupController: setup)

        let snapshot = try await controller.captureManagedOverridesBaseline()

        XCTAssertEqual(snapshot[.sleepDisabled], true)
        XCTAssertEqual(daemon.readCalls, 1)
    }

    func testRestoreManagedOverridesAppliesSleepDisabledValue() async throws {
        let daemon = MockDaemonClient()
        let setup = MockSetupController(state: .ready)
        let controller = ClosedLidPmsetController(daemonClient: daemon, setupController: setup)

        try await controller.restoreManagedOverrides(from: ClosedLidOverrideSnapshot(sleepDisabled: false))

        XCTAssertEqual(daemon.setCalls, [false])
    }

    func testCleanupUsesDaemonWhenReady() async throws {
        let daemon = MockDaemonClient()
        daemon.cleanupResult = LegacyCleanupReport(
            cleanedPaths: ["/tmp/a"],
            skippedPaths: ["/tmp/b"],
            backupDirectory: "/tmp/backup"
        )
        let setup = MockSetupController(state: .ready)
        let controller = ClosedLidPmsetController(daemonClient: daemon, setupController: setup)

        let report = try await controller.cleanupLegacyArtifacts()

        XCTAssertEqual(report.cleanedPaths, ["/tmp/a"])
        XCTAssertEqual(report.skippedPaths, ["/tmp/b"])
        XCTAssertEqual(report.backupDirectory, "/tmp/backup")
    }
}

@MainActor
private final class MockDaemonClient: PrivilegedDaemonControlling {
    var sleepDisabledValue = false
    var cleanupResult = LegacyCleanupReport(cleanedPaths: [], skippedPaths: [], backupDirectory: "")
    private(set) var setCalls: [Bool] = []
    private(set) var readCalls = 0

    func ping() async throws {
    }

    func setSleepDisabled(_ disabled: Bool) async throws {
        setCalls.append(disabled)
    }

    func readSleepDisabled() async throws -> Bool {
        readCalls += 1
        return sleepDisabledValue
    }

    func cleanupLegacyArtifacts() async throws -> LegacyCleanupReport {
        cleanupResult
    }
}

@MainActor
private final class MockSetupController: ClosedLidSetupControlling {
    var state: ClosedLidSetupState

    init(state: ClosedLidSetupState) {
        self.state = state
    }

    func refreshStatus() async -> ClosedLidSetupState {
        state
    }

    func startSetup() async -> ClosedLidSetupState {
        state
    }

    func openSystemSettingsForApproval() {}
}
