import XCTest
import ServiceManagement
@testable import AwakeBar

@MainActor
final class ClosedLidSetupControllerTests: XCTestCase {
    func testRefreshStatusReturnsNotInApplicationsWhenBundleOutsideApplications() async {
        let daemon = MockDaemonClientForSetup()
        let service = MockDaemonService(status: .enabled)

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Users/test/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.refreshStatus()
        XCTAssertEqual(state, .notInApplications)
    }

    func testRefreshStatusReturnsReadyWhenEnabledAndPingSucceeds() async {
        let daemon = MockDaemonClientForSetup()
        daemon.pingValue = true
        let service = MockDaemonService(status: .enabled)

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.refreshStatus()
        XCTAssertEqual(state, .ready)
    }

    func testStartSetupRegistersWhenNotRegistered() async {
        let daemon = MockDaemonClientForSetup()
        let service = MockDaemonService(status: .notRegistered)

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.startSetup()
        XCTAssertEqual(state, .ready)
        XCTAssertEqual(service.registerCalls, 1)
    }

    func testStartSetupRepairsEnabledServiceWhenPingInitiallyFails() async {
        let daemon = MockDaemonClientForSetup()
        daemon.pingSequence = [false, false, true]
        let service = MockDaemonService(status: .enabled)

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.startSetup()
        XCTAssertEqual(state, .ready)
        XCTAssertEqual(service.unregisterCalls, 1)
        XCTAssertEqual(service.registerCalls, 1)
    }

    func testRefreshStatusMapsApprovalRequired() async {
        let daemon = MockDaemonClientForSetup()
        let service = MockDaemonService(status: .requiresApproval)

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.refreshStatus()
        XCTAssertEqual(state, .approvalRequired)
    }

    func testRefreshStatusMapsNotFoundToUnavailable() async {
        let daemon = MockDaemonClientForSetup()
        let service = MockDaemonService(status: .notFound)

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.refreshStatus()
        guard case .unavailable(let message) = state else {
            return XCTFail("Expected unavailable")
        }
        XCTAssertTrue(message.contains("not found"))
    }

    func testRefreshStatusReturnsUnavailableWhenPingFails() async {
        let daemon = MockDaemonClientForSetup()
        daemon.shouldThrowPing = true
        let service = MockDaemonService(status: .enabled)

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.refreshStatus()
        guard case .unavailable = state else {
            return XCTFail("Expected unavailable")
        }
    }

    func testStartSetupReturnsUnavailableWhenRegisterFails() async {
        struct MockError: Error {}

        let daemon = MockDaemonClientForSetup()
        let service = MockDaemonService(status: .notRegistered)
        service.registerError = MockError()

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.startSetup()
        guard case .unavailable = state else {
            return XCTFail("Expected unavailable")
        }
    }

    func testOpenSystemSettingsForApprovalCallsHook() {
        let daemon = MockDaemonClientForSetup()
        let service = MockDaemonService(status: .requiresApproval)
        var didOpen = false

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: { didOpen = true }
        )

        controller.openSystemSettingsForApproval()
        XCTAssertTrue(didOpen)
    }
}

@MainActor
private final class MockDaemonClientForSetup: PrivilegedDaemonControlling {
    var pingValue = true
    var shouldThrowPing = false
    var pingSequence: [Bool] = []

    func ping() async throws -> Bool {
        if shouldThrowPing {
            struct PingError: Error {}
            throw PingError()
        }
        if !pingSequence.isEmpty {
            return pingSequence.removeFirst()
        }
        return pingValue
    }

    func setSleepDisabled(_ disabled: Bool) async throws {}

    func readSleepDisabled() async throws -> Bool {
        false
    }

    func cleanupLegacyArtifacts() async throws -> LegacyCleanupReport {
        LegacyCleanupReport(cleanedPaths: [], skippedPaths: [], backupDirectory: "")
    }
}

private final class MockDaemonService: DaemonServiceManaging {
    var status: SMAppService.Status
    var registerError: Error?
    private(set) var registerCalls = 0
    private(set) var unregisterCalls = 0

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        if let registerError {
            throw registerError
        }
        registerCalls += 1
        status = .enabled
    }

    func unregister() throws {
        unregisterCalls += 1
        status = .notRegistered
    }
}
