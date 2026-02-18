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

    func testFullAwakeSetupRequiredRollsBackOpenLidChange() async {
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
        XCTAssertEqual(openMock.setCalls, [true, false])
        XCTAssertEqual(closedMock.setCalls, [])
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
}

private final class OpenLidMock: OpenLidSleepControlling {
    private(set) var isEnabled = false
    private(set) var setCalls: [Bool] = []

    func setEnabled(_ enabled: Bool) throws {
        setCalls.append(enabled)
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

    func refreshStatus() async -> ClosedLidSetupState {
        refreshResult
    }

    func startSetup() async -> ClosedLidSetupState {
        startResult
    }

    func openSystemSettingsForApproval() {}
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
