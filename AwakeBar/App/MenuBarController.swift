import Foundation
import SwiftUI

@MainActor
final class MenuBarController: ObservableObject {
    @Published private(set) var state: AppState
    @Published private(set) var isApplyingClosedLidChange = false

    private let stateStore: AppStateStore
    private let openLidController: OpenLidSleepControlling
    private let closedLidController: ClosedLidSleepControlling
    private let closedLidSetupController: ClosedLidSetupControlling
    private let loginItemController: LoginItemControlling

    private var didBootstrap = false
    private var errorClearTask: Task<Void, Never>?

    init(
        stateStore: AppStateStore = AppStateStore(),
        openLidController: OpenLidSleepControlling = OpenLidAssertionController(),
        closedLidController: ClosedLidSleepControlling? = nil,
        closedLidSetupController: ClosedLidSetupControlling? = nil,
        loginItemController: LoginItemControlling = LoginItemController(),
        autoBootstrap: Bool = true
    ) {
        let resolvedSetupController = closedLidSetupController ?? ClosedLidSetupController()
        let resolvedClosedLidController = closedLidController ?? ClosedLidPmsetController(setupController: resolvedSetupController)

        self.stateStore = stateStore
        self.openLidController = openLidController
        self.closedLidController = resolvedClosedLidController
        self.closedLidSetupController = resolvedSetupController
        self.loginItemController = loginItemController
        self.state = stateStore.load()

        if autoBootstrap {
            Task { [weak self] in
                await self?.bootstrapIfNeeded()
            }
        }
    }

    deinit {
        errorClearTask?.cancel()
    }

    var mode: KeepAwakeMode {
        KeepAwakeMode.from(state: state)
    }

    var statusText: String {
        mode.statusText
    }

    var statusDetailText: String {
        mode.statusDetailText
    }

    var menuIconName: String {
        MenuIconCatalog.statusBarAssetName(for: mode)
    }

    var isOpenLidEnabled: Bool {
        state.openLidEnabled
    }

    var isClosedLidToggleOn: Bool {
        state.closedLidEnabledByApp || state.externalClosedLidDetected
    }

    var launchAtLoginEnabled: Bool {
        state.launchAtLoginEnabled
    }

    var closedLidSetupState: ClosedLidSetupState {
        state.closedLidSetupState
    }

    var isClosedLidReady: Bool {
        state.closedLidSetupState.isReady
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else {
            return
        }
        didBootstrap = true

        var loaded = stateStore.load()
        loaded.closedLidEnabledByApp = false
        loaded.externalClosedLidDetected = false
        loaded.closedLidSetupState = .notRegistered
        loaded.transientErrorMessage = nil
        state = loaded

        do {
            try openLidController.setEnabled(loaded.openLidEnabled)
        } catch {
            state.openLidEnabled = false
            persistSafeState()
            setTransientError("Could not enable Full Caffeine: \(error.localizedDescription)")
        }

        do {
            let systemValue = loginItemController.readEnabled()
            if systemValue != loaded.launchAtLoginEnabled {
                try loginItemController.setEnabled(loaded.launchAtLoginEnabled)
            }
        } catch {
            setTransientError("Could not apply launch-at-login setting: \(error.localizedDescription)")
        }

        await refreshClosedLidRuntimeState()
        await runLegacyCleanupIfNeeded()
    }

    func setOpenLidEnabled(_ enabled: Bool) {
        do {
            try openLidController.setEnabled(enabled)
            state.openLidEnabled = enabled
            persistSafeState()
        } catch {
            setTransientError("Full Caffeine update failed: \(error.localizedDescription)")
        }
    }

    func requestClosedLidChange(_ enabled: Bool) {
        Task { [weak self] in
            await self?.setClosedLidEnabled(enabled)
        }
    }

    func requestClosedLidSetup() {
        Task { [weak self] in
            await self?.runClosedLidSetup()
        }
    }

    func openClosedLidApprovalSettings() {
        closedLidSetupController.openSystemSettingsForApproval()
    }

    func setClosedLidEnabled(_ enabled: Bool) async {
        guard !isApplyingClosedLidChange else {
            return
        }

        let previousByApp = state.closedLidEnabledByApp
        let previousExternal = state.externalClosedLidDetected

        isApplyingClosedLidChange = true
        defer {
            isApplyingClosedLidChange = false
        }

        do {
            try await closedLidController.setEnabled(enabled)
            state.closedLidEnabledByApp = enabled
            state.externalClosedLidDetected = enabled
        } catch let ClosedLidControlError.setupRequired(setupState) {
            state.closedLidSetupState = setupState
            state.closedLidEnabledByApp = previousByApp
            state.externalClosedLidDetected = previousExternal
            setTransientError("Closed-Lid setup required: \(setupState.detail)")
        } catch {
            state.closedLidEnabledByApp = previousByApp
            state.externalClosedLidDetected = previousExternal
            setTransientError("Closed-Lid Mode update failed: \(error.localizedDescription)")
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try loginItemController.setEnabled(enabled)
            state.launchAtLoginEnabled = enabled
            persistSafeState()
        } catch {
            setTransientError("Launch-at-login update failed: \(error.localizedDescription)")
        }
    }

    func turnEverythingOff() async {
        setOpenLidEnabled(false)
        if isClosedLidToggleOn {
            await setClosedLidEnabled(false)
        }
    }

    private func runClosedLidSetup() async {
        let setupState = await closedLidSetupController.startSetup()
        state.closedLidSetupState = setupState

        guard setupState.isReady else {
            return
        }

        await refreshClosedLidRuntimeState()
        await runLegacyCleanupIfNeeded()
    }

    private func refreshClosedLidRuntimeState() async {
        let setupState = await closedLidSetupController.refreshStatus()
        state.closedLidSetupState = setupState

        guard setupState.isReady else {
            state.externalClosedLidDetected = false
            state.closedLidEnabledByApp = false
            return
        }

        do {
            let sleepDisabled = try await closedLidController.readSleepDisabled()
            state.externalClosedLidDetected = sleepDisabled
            state.closedLidEnabledByApp = false
        } catch {
            state.externalClosedLidDetected = false
            state.closedLidEnabledByApp = false
            setTransientError("Could not read current sleep policy: \(error.localizedDescription)")
        }
    }

    private func runLegacyCleanupIfNeeded() async {
        guard state.closedLidSetupState.isReady else {
            return
        }
        guard !state.legacyCleanupCompleted else {
            return
        }

        do {
            let report = try await closedLidController.cleanupLegacyArtifacts()
            state.legacyCleanupCompleted = true
            if !report.skippedPaths.isEmpty {
                state.legacyCleanupNotice = "Some legacy files were left untouched for safety."
            } else {
                state.legacyCleanupNotice = nil
            }
            persistSafeState()
        } catch {
            setTransientError("Legacy cleanup failed: \(error.localizedDescription)")
        }
    }

    private func persistSafeState() {
        stateStore.save(state)
    }

    private func setTransientError(_ message: String) {
        state.transientErrorMessage = message
        errorClearTask?.cancel()
        errorClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else {
                return
            }
            self?.state.transientErrorMessage = nil
        }
    }
}
