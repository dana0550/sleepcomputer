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

        closedMock.baselineSleepDisabled = true

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
        XCTAssertEqual(closedMock.setCalls, [true])
        XCTAssertEqual(closedMock.restoreCalls.count, 1)
        XCTAssertEqual(closedMock.restoreCalls.first?[.sleepDisabled], true)
    }

    func testSetFullAwakeEnableCapturesBaselineOncePerSession() async {
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
        await controller.setFullAwakeEnabled(true)

        XCTAssertEqual(closedMock.capturedBaselineCount, 1)
    }

    func testMenuIconStaysOnDuringPendingEnableTransition() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        closedMock.suspendNextEnable = true

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        let task = Task {
            await controller.setFullAwakeEnabled(true)
        }

        await waitForCondition { closedMock.isWaitingToCompleteEnable }

        XCTAssertTrue(controller.fullAwakeSwitchIsOn)
        XCTAssertEqual(controller.menuIconName, "AwakeBarStatusClosed")

        closedMock.resumePendingEnableIfNeeded()
        await task.value
    }

    func testRequestFullAwakeChangeSetsPendingStateSynchronously() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        closedMock.suspendNextEnable = true

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        controller.requestFullAwakeChange(true)

        XCTAssertTrue(controller.isApplyingFullAwakeChange)
        XCTAssertTrue(controller.fullAwakeSwitchIsOn)
        XCTAssertEqual(controller.menuIconName, "AwakeBarStatusClosed")

        await waitForCondition { closedMock.isWaitingToCompleteEnable }
        closedMock.resumePendingEnableIfNeeded()
        await waitForCondition { !controller.isApplyingFullAwakeChange }
        XCTAssertTrue(controller.isFullAwakeEnabled)
    }

    func testRefreshSetupStateDoesNotMutateStateDuringEnableTransition() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        closedMock.suspendNextEnable = true
        setupMock.refreshResult = .approvalRequired

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        controller.requestFullAwakeChange(true)
        await waitForCondition { closedMock.isWaitingToCompleteEnable }

        controller.refreshSetupState()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(openMock.setCalls, [true])
        XCTAssertEqual(controller.closedLidSetupState, .ready)

        closedMock.resumePendingEnableIfNeeded()
        await waitForCondition { !controller.isApplyingFullAwakeChange }
        XCTAssertTrue(controller.isFullAwakeEnabled)
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

    func testBootstrapIgnoresLegacyRestoreIntentAndStaysOff() async {
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
        XCTAssertEqual(setupMock.openSettingsCalls, 0)
    }

    func testBootstrapWithOffIntentDoesNotForceClosedLidDisable() async {
        let suiteName = "MenuBarControllerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(false, forKey: "awakebar.openLidEnabled")

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

        await controller.bootstrapIfNeeded()

        XCTAssertFalse(controller.isFullAwakeEnabled)
        XCTAssertEqual(closedMock.setCalls, [])
    }

    func testBootstrapWithPendingSessionRestoresAndClearsPendingState() async {
        let suiteName = "MenuBarControllerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = AppStateStore(userDefaults: defaults)
        store.saveOverrideSession(
            ClosedLidOverrideSession(
                snapshot: ClosedLidOverrideSnapshot(sleepDisabled: false),
                pendingRestore: true,
                lastRestoreError: "previous failure"
            )
        )

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

        await controller.bootstrapIfNeeded()

        XCTAssertEqual(closedMock.restoreCalls.count, 1)
        XCTAssertNil(store.loadOverrideSession())
        XCTAssertNil(controller.pendingRestoreMessage)
    }

    func testBootstrapWithPendingSessionFailureKeepsPendingState() async {
        let suiteName = "MenuBarControllerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = AppStateStore(userDefaults: defaults)
        store.saveOverrideSession(
            ClosedLidOverrideSession(
                snapshot: ClosedLidOverrideSnapshot(sleepDisabled: false),
                pendingRestore: true
            )
        )

        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        closedMock.restoreError = TerminationMockError()

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.bootstrapIfNeeded()

        let session = store.loadOverrideSession()
        XCTAssertEqual(session?.pendingRestore, true)
        XCTAssertNotNil(session?.lastRestoreError)
        XCTAssertNotNil(controller.pendingRestoreMessage)
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

    func testFullAwakeFailureRollbackTracksActualOpenLidStateWhenRollbackFails() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        closedMock.shouldThrow = true
        openMock.disableFailureMode = .throwAndStayEnabled

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
        XCTAssertTrue(controller.state.openLidEnabled)
        XCTAssertTrue(openMock.isEnabled)
        XCTAssertEqual(openMock.setCalls, [true, false])
        XCTAssertEqual(closedMock.setCalls, [])
        XCTAssertTrue(controller.state.transientErrorMessage?.contains("Open-lid awake may still be active") == true)
    }

    func testFullAwakeSetupRequiredRollbackTracksActualOpenLidStateWhenRollbackFails() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        closedMock.setupRequiredState = .approvalRequired
        openMock.disableFailureMode = .throwAndStayEnabled

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
        XCTAssertTrue(controller.state.openLidEnabled)
        XCTAssertTrue(openMock.isEnabled)
        XCTAssertEqual(openMock.setCalls, [true, false])
        XCTAssertEqual(setupMock.openSettingsCalls, 1)
        XCTAssertTrue(controller.state.transientErrorMessage?.contains("Open-lid awake may still be active") == true)
    }

    func testFailedEnableRollbackDoesNotPersistRestoreIntentWhenOtherSettingsAreSaved() async {
        let suiteName = "MenuBarControllerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = AppStateStore(userDefaults: defaults)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()

        closedMock.shouldThrow = true
        openMock.disableFailureMode = .throwAndStayEnabled

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            autoBootstrap: false
        )

        await controller.setFullAwakeEnabled(true)
        controller.setLaunchAtLoginEnabled(true)

        let loaded = store.load()
        XCTAssertTrue(controller.state.openLidEnabled)
        XCTAssertFalse(loaded.openLidEnabled)
        XCTAssertTrue(loaded.launchAtLoginEnabled)
    }

    func testOpenLoginItemsSettingsForApprovalCancelsPreviousPollingTask() async {
        let store = AppStateStore(userDefaults: UserDefaults(suiteName: "MenuBarControllerTests.\(UUID().uuidString)")!)
        let openMock = OpenLidMock()
        let closedMock = ClosedLidMock()
        let setupMock = ClosedLidSetupMock()
        let loginMock = LoginItemMock()
        let attempts = 4

        setupMock.refreshResult = .approvalRequired

        let controller = MenuBarController(
            stateStore: store,
            openLidController: openMock,
            closedLidController: closedMock,
            closedLidSetupController: setupMock,
            loginItemController: loginMock,
            approvalPollingAttempts: attempts,
            approvalPollingIntervalNanoseconds: 20_000_000,
            autoBootstrap: false
        )

        controller.openLoginItemsSettingsForApproval()
        try? await Task.sleep(nanoseconds: 5_000_000)
        controller.openLoginItemsSettingsForApproval()
        try? await Task.sleep(nanoseconds: 140_000_000)

        XCTAssertEqual(setupMock.openSettingsCalls, 2)
        XCTAssertLessThanOrEqual(setupMock.refreshCalls, attempts + 1)
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

    func testPrepareForTerminationRestoresAndClearsOverrideSession() async {
        let suiteName = "MenuBarControllerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
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

        await controller.setFullAwakeEnabled(true)
        await controller.prepareForTermination()

        XCTAssertFalse(controller.state.openLidEnabled)
        XCTAssertFalse(controller.state.closedLidEnabledByApp)
        XCTAssertEqual(closedMock.restoreCalls.count, 1)
        XCTAssertNil(store.loadOverrideSession())
    }

    func testPrepareForTerminationPersistsPendingSessionWhenRestoreFails() async {
        let suiteName = "MenuBarControllerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
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

        await controller.setFullAwakeEnabled(true)
        closedMock.restoreError = TerminationMockError()

        await controller.prepareForTermination()

        XCTAssertFalse(controller.state.openLidEnabled)
        XCTAssertFalse(controller.state.closedLidEnabledByApp)
        let session = store.loadOverrideSession()
        XCTAssertEqual(session?.pendingRestore, true)
        XCTAssertNotNil(session?.lastRestoreError)
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
        XCTAssertEqual(closedMock.setCalls, [true])
        XCTAssertEqual(closedMock.restoreCalls.count, 1)
        XCTAssertFalse(controller.isFullAwakeEnabled)
    }

    func testDisableRestoreFailureRollsBackToPreviousOnState() async {
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
        closedMock.restoreError = ClosedLidControlError.setupRequired(.approvalRequired)

        await controller.setFullAwakeEnabled(false)

        XCTAssertTrue(controller.isFullAwakeEnabled)
        XCTAssertEqual(controller.closedLidSetupState, .approvalRequired)
        XCTAssertEqual(openMock.setCalls, [true, false, true])
        XCTAssertEqual(closedMock.setCalls, [true, true])
        XCTAssertTrue(controller.state.transientErrorMessage?.contains("Could not restore previous sleep settings") == true)
    }

    func testDisableSurfacesErrorWhenRestoreAndRollbackBothFail() async {
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
        closedMock.restoreError = ClosedLidControlError.setupRequired(.approvalRequired)
        closedMock.setupRequiredState = .approvalRequired

        await controller.setFullAwakeEnabled(false)

        XCTAssertEqual(closedMock.setCalls, [true])
        XCTAssertTrue(controller.isFullAwakeEnabled)
        XCTAssertTrue(controller.state.transientErrorMessage?.contains("Could not restore previous sleep settings") == true)
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

    func testRefreshSetupStateClearsClosedLidStateWhenOpenLidDisableFails() async {
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
        XCTAssertFalse(controller.isFullAwakeEnabled)
        XCTAssertTrue(openMock.isEnabled)
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
    var failNextDisableWithSetupRequired: ClosedLidSetupState?
    var captureError: Error?
    var restoreError: Error?
    var baselineSleepDisabled = false
    private(set) var capturedBaselineCount = 0
    private(set) var restoreCalls: [ClosedLidOverrideSnapshot] = []
    var suspendNextEnable = false
    private(set) var setCalls: [Bool] = []
    private(set) var sleepDisabled = false
    private var pendingEnableContinuation: CheckedContinuation<Void, Never>?

    var isWaitingToCompleteEnable: Bool {
        pendingEnableContinuation != nil
    }

    func setEnabled(_ enabled: Bool) async throws {
        if enabled && suspendNextEnable {
            suspendNextEnable = false
            await withCheckedContinuation { continuation in
                pendingEnableContinuation = continuation
            }
        }
        if !enabled, let failNextDisableWithSetupRequired {
            self.failNextDisableWithSetupRequired = nil
            throw ClosedLidControlError.setupRequired(failNextDisableWithSetupRequired)
        }
        if let setupRequiredState {
            throw ClosedLidControlError.setupRequired(setupRequiredState)
        }
        if shouldThrow {
            struct MockError: Error {}
            throw MockError()
        }
        setCalls.append(enabled)
        sleepDisabled = enabled
    }

    func readSleepDisabled() async throws -> Bool {
        sleepDisabled
    }

    func captureManagedOverridesBaseline() async throws -> ClosedLidOverrideSnapshot {
        if let captureError {
            throw captureError
        }
        capturedBaselineCount += 1
        return ClosedLidOverrideSnapshot(sleepDisabled: baselineSleepDisabled)
    }

    func restoreManagedOverrides(from snapshot: ClosedLidOverrideSnapshot) async throws {
        if let restoreError {
            throw restoreError
        }
        restoreCalls.append(snapshot)
        if let sleepDisabled = snapshot[.sleepDisabled] {
            self.sleepDisabled = sleepDisabled
        }
    }

    func cleanupLegacyArtifacts() async throws -> LegacyCleanupReport {
        LegacyCleanupReport(cleanedPaths: [], skippedPaths: [], backupDirectory: "")
    }

    func resumePendingEnableIfNeeded() {
        pendingEnableContinuation?.resume()
        pendingEnableContinuation = nil
    }
}

private final class ClosedLidSetupMock: ClosedLidSetupControlling {
    var refreshResult: ClosedLidSetupState = .ready
    var startResult: ClosedLidSetupState = .ready
    private(set) var refreshCalls = 0
    private(set) var openSettingsCalls = 0

    func refreshStatus() async -> ClosedLidSetupState {
        refreshCalls += 1
        return refreshResult
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

private struct TerminationMockError: LocalizedError {
    var errorDescription: String? {
        "mock restore failure"
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
