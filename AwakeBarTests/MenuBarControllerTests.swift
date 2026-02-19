import XCTest
@testable import AwakeBar

@MainActor
final class MenuBarControllerTests: XCTestCase {
    func testSetFullAwakeEnabledTurnsOnBothControllers() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.setFullAwakeEnabled(true)

        XCTAssertTrue(controller.isFullAwakeEnabled)
        XCTAssertEqual(controller.closedLidSetupState, .ready)
        XCTAssertEqual(openMock.setCalls, [true])
        XCTAssertEqual(closedMock.setCalls, [true])
    }

    func testSetFullAwakeEnabledFalseRestoresNormalSleep() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.setFullAwakeEnabled(true)
        await controller.setFullAwakeEnabled(false)

        XCTAssertFalse(controller.isFullAwakeEnabled)
        XCTAssertEqual(openMock.setCalls, [true, false])
        XCTAssertEqual(closedMock.setCalls, [true, false])
    }

    func testFullAwakeSetupRequiredDoesNotEnableAndOpensSettings() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        setupMock.startResult = .approvalRequired
        setupMock.refreshResult = .approvalRequired
        closedMock.setupRequiredState = .approvalRequired

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.setFullAwakeEnabled(true)

        XCTAssertFalse(controller.isFullAwakeEnabled)
        XCTAssertEqual(controller.closedLidSetupState, .approvalRequired)
        XCTAssertEqual(openMock.setCalls, [])
        XCTAssertEqual(closedMock.setCalls, [])
        XCTAssertEqual(setupMock.openSettingsCalls, 1)
    }

    func testBootstrapClearsPersistedRestoreIntentWhenAutoRestoreFails() async {
        let suiteName = "MenuBarControllerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(true, forKey: "awakebar.openLidEnabled")

        let store = AppStateStore(userDefaults: defaults)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        setupMock.refreshResult = .approvalRequired
        setupMock.startResult = .approvalRequired
        closedMock.setupRequiredState = .approvalRequired

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.bootstrapIfNeeded()

        XCTAssertFalse(store.load().openLidEnabled)
        XCTAssertFalse(controller.isFullAwakeEnabled)
        XCTAssertEqual(controller.closedLidSetupState, .approvalRequired)
        XCTAssertEqual(setupMock.openSettingsCalls, 1)
    }

    func testFullAwakeFailureRollsBackBothStates() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        closedMock.shouldThrow = true

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.setFullAwakeEnabled(true)

        XCTAssertFalse(controller.isFullAwakeEnabled)
        XCTAssertEqual(openMock.setCalls, [true, false])
        XCTAssertEqual(closedMock.setCalls, [])
    }

    func testSetLaunchAtLoginPersistsState() {
        let suiteName = "MenuBarControllerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create suite")
        }

        let store = AppStateStore(userDefaults: defaults)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        controller.setLaunchAtLoginEnabled(true)

        let loaded = store.load()
        XCTAssertTrue(loaded.launchAtLoginEnabled)
        XCTAssertEqual(loginMock.setCalls, [true])
    }

    func testDisableDoesNotProceedToClosedLidWhenOpenLidDisableFailsAndRemainsEnabled() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.setFullAwakeEnabled(true)
        openMock.disableFailureMode = .throwAndStayEnabled

        await controller.setFullAwakeEnabled(false)

        XCTAssertEqual(openMock.setCalls, [true, false])
        XCTAssertEqual(closedMock.setCalls, [true])
        XCTAssertTrue(controller.isFullAwakeEnabled)
    }

    func testDisableProceedsWhenOpenLidDisableThrowsButControllerReportsDisabled() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.setFullAwakeEnabled(true)
        openMock.disableFailureMode = .throwButDisable

        await controller.setFullAwakeEnabled(false)

        XCTAssertEqual(openMock.setCalls, [true, false])
        XCTAssertEqual(closedMock.setCalls, [true, false])
        XCTAssertFalse(controller.isFullAwakeEnabled)
    }

    func testRefreshSetupStateDisablesOpenLidWhenHelperBecomesNotReady() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.setFullAwakeEnabled(true)
        setupMock.refreshResult = .approvalRequired

        controller.refreshSetupState()
        await waitForCondition { openMock.setCalls == [true, false] }

        XCTAssertFalse(openMock.isEnabled)
        XCTAssertFalse(controller.isFullAwakeEnabled)
        XCTAssertEqual(controller.closedLidSetupState, .approvalRequired)
    }

    func testRefreshSetupStateKeepsOnStateWhenOpenLidDisableFails() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.setFullAwakeEnabled(true)
        openMock.disableFailureMode = .throwAndStayEnabled
        setupMock.refreshResult = .approvalRequired

        controller.refreshSetupState()
        await waitForCondition { openMock.setCalls == [true, false] }

        XCTAssertEqual(closedMock.setCalls, [true])
        XCTAssertTrue(controller.isFullAwakeEnabled)
        XCTAssertEqual(controller.closedLidSetupState, .approvalRequired)
    }
}

private final class OpenLidMock: OpenLidSleepControlling {
    enum DisableFailureMode {
        case none
        case throwAndStayEnabled
        case throwButDisable
    }

    private struct MockDisableError: Error {}

    var disableFailureMode: DisableFailureMode = .none
    private(set) var isEnabled = false
    private(set) var setCalls: [Bool] = []

    func setEnabled(_ enabled: Bool) throws {
        setCalls.append(enabled)
        if !enabled {
            switch disableFailureMode {
            case .none:
                break
            case .throwAndStayEnabled:
                throw MockDisableError()
            case .throwButDisable:
                isEnabled = false
                throw MockDisableError()
            }
        }
        isEnabled = enabled
    }
}

private final class ClosedLidMock: ClosedLidSleepControlling {
    var shouldThrow = false
    var setupRequiredState: ClosedLidSetupState?
    private(set) var setCalls: [Bool] = []

    func setEnabled(_ enabled: Bool) async throws {
        if let setupRequiredState {
            throw ClosedLidControlError.setupRequired(setupRequiredState)
        }
        if shouldThrow {
            struct MockError: Error {}
            throw MockError()
        }
        setCalls.append(enabled)
    }

    func readSleepDisabled() async throws -> Bool {
        false
    }

    func cleanupLegacyArtifacts() async throws -> LegacyCleanupReport {
        LegacyCleanupReport(cleanedPaths: [], skippedPaths: [], backupDirectory: "")
    }
}

private final class ClosedLidSetupMock: ClosedLidSetupControlling {
    var refreshResult: ClosedLidSetupState = .ready
    var startResult: ClosedLidSetupState = .ready
    private(set) var openSettingsCalls = 0

    func refreshStatus() async -> ClosedLidSetupState {
        refreshResult
    }

    func startSetup() async -> ClosedLidSetupState {
        startResult
    }

    func openSystemSettingsForApproval() {
        openSettingsCalls += 1
    }
}

private final class LoginItemMock: LoginItemControlling {
    private(set) var value = false
    private(set) var setCalls: [Bool] = []

    func setEnabled(_ enabled: Bool) throws {
        value = enabled
        setCalls.append(enabled)
    }

    func readEnabled() -> Bool {
        value
    }
}

@MainActor
private func waitForCondition(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    pollNanoseconds: UInt64 = 10_000_000,
    _ condition: () -> Bool
) async {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while !condition() && DispatchTime.now().uptimeNanoseconds < deadline {
        try? await Task.sleep(nanoseconds: pollNanoseconds)
    }
}
