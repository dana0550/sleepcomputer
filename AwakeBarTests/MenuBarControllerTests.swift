import XCTest
@testable import AwakeBar

@MainActor
final class MenuBarControllerTests: XCTestCase {
    func testTurnEverythingOffDisablesBothControllers() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let loginMock = LoginItemMock()

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        controller.setOpenLidEnabled(true)
        await controller.setClosedLidEnabled(true)

        await controller.turnEverythingOff()

        XCTAssertFalse(controller.isOpenLidEnabled)
        XCTAssertFalse(controller.isClosedLidToggleOn)
        XCTAssertEqual(openMock.setCalls, [true, false])
        XCTAssertEqual(closedMock.setCalls, [true, false])
    }

    func testClosedLidFailureKeepsPreviousState() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let loginMock = LoginItemMock()

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.setClosedLidEnabled(true)
        closedMock.shouldThrow = true

        await controller.setClosedLidEnabled(false)

        XCTAssertTrue(controller.isClosedLidToggleOn)
    }

    func testSetLaunchAtLoginPersistsState() {
        let suiteName = "MenuBarControllerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create suite")
        }

        let store = AppStateStore(userDefaults: defaults)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let loginMock = LoginItemMock()

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        controller.setLaunchAtLoginEnabled(true)

        let loaded = store.load()
        XCTAssertTrue(loaded.launchAtLoginEnabled)
        XCTAssertEqual(loginMock.setCalls, [true])
    }

    func testClosedLidSetupRequiredStateIsSurfaced() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let loginMock = LoginItemMock()
        closedMock.setupRequiredState = .approvalRequired

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.setClosedLidEnabled(true)

        XCTAssertEqual(controller.closedLidSetupState, .approvalRequired)
        XCTAssertFalse(controller.isClosedLidToggleOn)
        XCTAssertEqual(closedMock.setCalls, [])
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
