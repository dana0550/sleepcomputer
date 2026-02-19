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

    func testStartSetupEnabledServiceWaitsForHelperWithoutReRegistration() async {
        let daemon = MockDaemonClientForSetup()
        daemon.pingSequence = [false, false, true]
        let service = MockDaemonService(status: .enabled)

        let controller = makeController(daemon: daemon, service: service)

        let state = await controller.startSetup()
        XCTAssertEqual(state, .ready)
        XCTAssertEqual(service.unregisterCalls, 0)
        XCTAssertEqual(service.registerCalls, 0)
    }

    func testStartSetupEnabledServiceFailureDoesNotUnregisterOrRegister() async {
        let daemon = MockDaemonClientForSetup()
        daemon.pingValue = false
        let service = MockDaemonService(status: .enabled)

        let controller = makeController(daemon: daemon, service: service)

        let state = await controller.startSetup()
        guard case .unavailable(let message) = state else {
            return XCTFail("Expected unavailable")
        }
        XCTAssertTrue(message.contains("did not launch"))
        XCTAssertEqual(service.unregisterCalls, 0)
        XCTAssertEqual(service.registerCalls, 0)
    }

    func testStartSetupNotRegisteredFailureRegistersOnceWithoutRepairLoop() async {
        let daemon = MockDaemonClientForSetup()
        daemon.pingValue = false
        let service = MockDaemonService(status: .notRegistered)

        let controller = makeController(daemon: daemon, service: service)

        let state = await controller.startSetup()
        guard case .unavailable(let message) = state else {
            return XCTFail("Expected unavailable")
        }
        XCTAssertTrue(message.contains("sfltool resetbtm"))
        XCTAssertEqual(service.registerCalls, 1)
        XCTAssertEqual(service.unregisterCalls, 0)
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

    func testRefreshStatusMapsNotFoundToNotRegistered() async {
        let daemon = MockDaemonClientForSetup()
        let service = MockDaemonService(status: .notFound)

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.refreshStatus()
        XCTAssertEqual(state, .notRegistered)
    }

    func testStartSetupReturnsApprovalRequiredWithoutRegisterRetryLoop() async {
        let daemon = MockDaemonClientForSetup()
        let service = MockDaemonService(status: .requiresApproval)

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.startSetup()
        XCTAssertEqual(state, .approvalRequired)
        XCTAssertEqual(service.registerCalls, 0)
        XCTAssertEqual(service.unregisterCalls, 0)
    }

    func testStartSetupReturnsApprovalRequiredImmediatelyAfterRegisterWhenApprovalPending() async {
        let daemon = MockDaemonClientForSetup()
        daemon.pingValue = true
        let service = MockDaemonService(status: .notRegistered)
        service.statusAfterRegister = .requiresApproval

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.startSetup()
        XCTAssertEqual(state, .approvalRequired)
        XCTAssertEqual(service.registerCalls, 1)
        XCTAssertEqual(service.unregisterCalls, 0)
    }

    func testStartSetupReturnsUnavailableWhenNotFoundPersistsAfterRegister() async {
        let daemon = MockDaemonClientForSetup()
        let service = MockDaemonService(status: .notFound)
        service.statusAfterRegister = .notFound

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.startSetup()
        guard case .unavailable(let message) = state else {
            return XCTFail("Expected unavailable")
        }
        XCTAssertTrue(message.contains("registration did not persist"))
        XCTAssertEqual(service.registerCalls, 1)
        XCTAssertEqual(service.unregisterCalls, 0)
    }

    func testStartSetupTreatsNotFoundAsSetupRequiredAndRegisters() async {
        let daemon = MockDaemonClientForSetup()
        let service = MockDaemonService(status: .notFound)

        let controller = ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: "/Applications/AwakeBar.app") },
            openSettings: {}
        )

        let state = await controller.startSetup()
        XCTAssertEqual(state, .ready)
        XCTAssertEqual(service.registerCalls, 1)
        XCTAssertEqual(service.unregisterCalls, 0)
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
        guard case .unavailable(let message) = state else {
            return XCTFail("Expected unavailable")
        }
        XCTAssertTrue(message.contains("did not launch"))
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

    func testIsInApplicationsRejectsApplicationsDirectoryRoot() {
        XCTAssertFalse(ClosedLidSetupController.isInApplications(URL(fileURLWithPath: "/Applications")))
        XCTAssertTrue(ClosedLidSetupController.isInApplications(URL(fileURLWithPath: "/Applications/AwakeBar.app")))
    }

    private func makeController(
        daemon: MockDaemonClientForSetup,
        service: MockDaemonService,
        appPath: String = "/Applications/AwakeBar.app",
        openSettings: @escaping () -> Void = {}
    ) -> ClosedLidSetupController {
        ClosedLidSetupController(
            daemonClient: daemon,
            daemonService: service,
            appBundleURLProvider: { URL(fileURLWithPath: appPath) },
            retryDelayNanoseconds: 0,
            openSettings: openSettings
        )
    }
}

@MainActor
private final class MockDaemonClientForSetup: PrivilegedDaemonControlling {
    var pingValue = true
    var shouldThrowPing = false
    var pingSequence: [Bool] = []

    func ping() async throws {
        struct PingError: Error {}

        if shouldThrowPing {
            throw PingError()
        }
        if !pingSequence.isEmpty {
            let next = pingSequence.removeFirst()
            if next {
                return
            }
            throw PingError()
        }
        if pingValue {
            return
        }
        throw PingError()
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
    var statusAfterRegister: SMAppService.Status = .enabled
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
        status = statusAfterRegister
    }

    func unregister() throws {
        unregisterCalls += 1
        status = .notRegistered
    }
}
