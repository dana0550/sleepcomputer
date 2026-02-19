import Foundation
import SwiftUI

@MainActor
final class MenuBarController: ObservableObject {
    @Published private(set) var state: AppState
    @Published private(set) var isApplyingFullAwakeChange = false
    @Published private(set) var pendingFullAwakeTarget: Bool?

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
        let resolvedClosedLidController: ClosedLidSleepControlling
        let resolvedSetupController: ClosedLidSetupControlling

        if let explicitClosedLidController = closedLidController {
            resolvedClosedLidController = explicitClosedLidController
            resolvedSetupController = closedLidSetupController ?? ClosedLidSetupController()
        } else if let explicitSetupController = closedLidSetupController {
            resolvedSetupController = explicitSetupController
            resolvedClosedLidController = ClosedLidPmsetController(setupController: explicitSetupController)
        } else {
            let defaultClosedLidController = ClosedLidPmsetController()
            resolvedClosedLidController = defaultClosedLidController
            resolvedSetupController = defaultClosedLidController.setupStateController
        }

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

    var menuIconName: String {
        let displayMode: KeepAwakeMode = fullAwakeSwitchIsOn ? .fullAwake : .off
        return MenuIconCatalog.statusBarAssetName(for: displayMode)
    }

    var isFullAwakeEnabled: Bool {
        mode == .fullAwake
    }

    var fullAwakeSwitchIsOn: Bool {
        pendingFullAwakeTarget ?? isFullAwakeEnabled
    }

    var launchAtLoginEnabled: Bool {
        state.launchAtLoginEnabled
    }

    var closedLidSetupState: ClosedLidSetupState {
        state.closedLidSetupState
    }

    var fullAwakeBlockedMessage: String? {
        guard !state.closedLidSetupState.isReady else {
            return nil
        }
        return fullAwakeSetupMessage(for: state.closedLidSetupState)
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else {
            return
        }
        didBootstrap = true

        var loaded = stateStore.load()
        let shouldRestoreFullAwake = loaded.openLidEnabled
        loaded.openLidEnabled = false
        loaded.closedLidEnabledByApp = false
        loaded.closedLidSetupState = .notRegistered
        loaded.transientErrorMessage = nil
        state = loaded
        persistSafeState()

        do {
            try openLidController.setEnabled(false)
        } catch {
            state.openLidEnabled = false
            persistSafeState()
            setTransientError("Could not restore default sleep: \(error.localizedDescription)")
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

        if shouldRestoreFullAwake {
            await setFullAwakeEnabled(true)
        } else {
            // Reconcile system policy with persisted OFF intent on launch.
            await setFullAwakeEnabled(false)
        }
    }

    func requestFullAwakeChange(_ enabled: Bool) {
        guard beginFullAwakeTransition(to: enabled) else {
            return
        }

        Task { @MainActor [self] in
            defer {
                endFullAwakeTransition()
            }
            await applyFullAwakeChange(enabled)
        }
    }

    func refreshSetupState() {
        Task { [weak self] in
            await self?.refreshClosedLidRuntimeState()
        }
    }

    func openLoginItemsSettingsForApproval() {
        closedLidSetupController.openSystemSettingsForApproval()

        Task { [weak self] in
            guard let self else { return }
            for _ in 0..<30 {
                await self.refreshClosedLidRuntimeState()
                if self.state.closedLidSetupState.isReady {
                    return
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func setFullAwakeEnabled(_ enabled: Bool) async {
        guard beginFullAwakeTransition(to: enabled) else {
            return
        }
        defer {
            endFullAwakeTransition()
        }
        await applyFullAwakeChange(enabled)
    }

    private func applyFullAwakeChange(_ enabled: Bool) async {
        let previousOpen = state.openLidEnabled
        let previousByApp = state.closedLidEnabledByApp

        if enabled {
            do {
                if !state.closedLidSetupState.isReady {
                    let setupState = await closedLidSetupController.startSetup()
                    state.closedLidSetupState = setupState

                    guard setupState.isReady else {
                        if case .approvalRequired = setupState {
                            closedLidSetupController.openSystemSettingsForApproval()
                        }
                        setTransientError(fullAwakeSetupMessage(for: setupState))
                        return
                    }
                }

                try openLidController.setEnabled(true)
                state.openLidEnabled = true

                do {
                    try await closedLidController.setEnabled(true)
                    state.closedLidEnabledByApp = true
                    persistSafeState()
                } catch let ClosedLidControlError.setupRequired(setupState) {
                    state.closedLidSetupState = setupState
                    try? openLidController.setEnabled(previousOpen)
                    state.openLidEnabled = previousOpen
                    state.closedLidEnabledByApp = previousByApp
                    if case .approvalRequired = setupState {
                        closedLidSetupController.openSystemSettingsForApproval()
                    }
                    setTransientError(fullAwakeSetupMessage(for: setupState))
                } catch {
                    try? openLidController.setEnabled(previousOpen)
                    state.openLidEnabled = previousOpen
                    state.closedLidEnabledByApp = previousByApp
                    setTransientError("Could not enable Full Awake: \(error.localizedDescription)")
                }
            } catch {
                try? openLidController.setEnabled(previousOpen)
                state.openLidEnabled = previousOpen
                state.closedLidEnabledByApp = previousByApp
                setTransientError("Could not enable Full Awake: \(error.localizedDescription)")
            }
            return
        }

        do {
            try openLidController.setEnabled(false)
            state.openLidEnabled = false
        } catch {
            state.openLidEnabled = openLidController.isEnabled
            setTransientError("Could not disable open-lid awake: \(error.localizedDescription)")
            if state.openLidEnabled {
                persistSafeState()
                return
            }
        }

        do {
            try await closedLidController.setEnabled(false)
            state.closedLidEnabledByApp = false
        } catch let ClosedLidControlError.setupRequired(setupState) {
            state.closedLidSetupState = setupState
        } catch {
            state.closedLidEnabledByApp = previousByApp
            setTransientError("Could not disable closed-lid awake: \(error.localizedDescription)")
        }

        await refreshClosedLidRuntimeState()
        persistSafeState()
    }

    private func beginFullAwakeTransition(to enabled: Bool) -> Bool {
        guard !isApplyingFullAwakeChange else {
            return false
        }
        isApplyingFullAwakeChange = true
        pendingFullAwakeTarget = enabled
        return true
    }

    private func endFullAwakeTransition() {
        isApplyingFullAwakeChange = false
        pendingFullAwakeTarget = nil
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
        await setFullAwakeEnabled(false)
    }

    private func refreshClosedLidRuntimeState() async {
        let setupState = await closedLidSetupController.refreshStatus()
        state.closedLidSetupState = setupState

        guard setupState.isReady else {
            let wasOpenEnabled = state.openLidEnabled
            state.closedLidEnabledByApp = false

            if state.openLidEnabled {
                do {
                    try openLidController.setEnabled(false)
                    state.openLidEnabled = false
                } catch {
                    state.openLidEnabled = openLidController.isEnabled
                    setTransientError("Could not restore default sleep while helper is unavailable: \(error.localizedDescription)")
                    if state.openLidEnabled {
                        return
                    }
                }
            }

            if wasOpenEnabled && !state.openLidEnabled {
                persistSafeState()
            }
            return
        }

        do {
            let sleepDisabled = try await closedLidController.readSleepDisabled()
            if !sleepDisabled {
                state.closedLidEnabledByApp = false
            }
        } catch {
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
            _ = try await closedLidController.cleanupLegacyArtifacts()
            state.legacyCleanupCompleted = true
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

    private func fullAwakeSetupMessage(for setupState: ClosedLidSetupState) -> String {
        switch setupState {
        case .ready:
            return "Ready."
        case .approvalRequired:
            return "Approve helper in Login Items."
        case .notInApplications:
            return "Move app to /Applications."
        case .notRegistered:
            return "Finish one-time setup."
        case .unavailable(let detail):
            return "Helper unavailable: \(detail)"
        }
    }
}
