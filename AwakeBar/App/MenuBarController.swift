import Foundation
import SwiftUI

@MainActor
final class MenuBarController: ObservableObject {
    @Published private(set) var state: AppState
    @Published private(set) var isApplyingFullAwakeChange = false

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

    var isFullAwakeEnabled: Bool {
        mode == .fullAwake
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
        loaded.externalClosedLidDetected = false
        loaded.closedLidSetupState = .notRegistered
        loaded.transientErrorMessage = nil
        state = loaded

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
        }
    }

    func requestFullAwakeChange(_ enabled: Bool) {
        Task { [weak self] in
            await self?.setFullAwakeEnabled(enabled)
        }
    }

    func openLoginItemsSettingsForApproval() {
        closedLidSetupController.openSystemSettingsForApproval()
    }

    func setFullAwakeEnabled(_ enabled: Bool) async {
        guard !isApplyingFullAwakeChange else {
            return
        }

        let previousOpen = state.openLidEnabled
        let previousByApp = state.closedLidEnabledByApp
        let previousExternal = state.externalClosedLidDetected

        isApplyingFullAwakeChange = true
        defer {
            isApplyingFullAwakeChange = false
        }

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
                    state.externalClosedLidDetected = true
                    persistSafeState()
                } catch let ClosedLidControlError.setupRequired(setupState) {
                    state.closedLidSetupState = setupState
                    try? openLidController.setEnabled(previousOpen)
                    state.openLidEnabled = previousOpen
                    state.closedLidEnabledByApp = previousByApp
                    state.externalClosedLidDetected = previousExternal
                    if case .approvalRequired = setupState {
                        closedLidSetupController.openSystemSettingsForApproval()
                    }
                    setTransientError(fullAwakeSetupMessage(for: setupState))
                } catch {
                    try? openLidController.setEnabled(previousOpen)
                    state.openLidEnabled = previousOpen
                    state.closedLidEnabledByApp = previousByApp
                    state.externalClosedLidDetected = previousExternal
                    setTransientError("Could not enable Full Awake: \(error.localizedDescription)")
                }
            } catch {
                try? openLidController.setEnabled(previousOpen)
                state.openLidEnabled = previousOpen
                state.closedLidEnabledByApp = previousByApp
                state.externalClosedLidDetected = previousExternal
                setTransientError("Could not enable Full Awake: \(error.localizedDescription)")
            }
            return
        }

        do {
            try openLidController.setEnabled(false)
            state.openLidEnabled = false
        } catch {
            state.openLidEnabled = previousOpen
            setTransientError("Could not disable open-lid awake: \(error.localizedDescription)")
        }

        do {
            try await closedLidController.setEnabled(false)
            state.closedLidEnabledByApp = false
            state.externalClosedLidDetected = false
        } catch let ClosedLidControlError.setupRequired(setupState) {
            state.closedLidSetupState = setupState
        } catch {
            state.closedLidEnabledByApp = previousByApp
            state.externalClosedLidDetected = previousExternal
            setTransientError("Could not disable closed-lid awake: \(error.localizedDescription)")
        }

        await refreshClosedLidRuntimeState()
        persistSafeState()
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

    private func fullAwakeSetupMessage(for setupState: ClosedLidSetupState) -> String {
        switch setupState {
        case .ready:
            return "Full Awake is ready."
        case .approvalRequired:
            return "Approve AwakeBar in System Settings > Login Items, then toggle Full Awake again."
        case .notInApplications:
            return "Move AwakeBar to /Applications to use Full Awake."
        case .notRegistered:
            return "Full Awake needs one-time helper setup. Try toggling on again."
        case .unavailable(let detail):
            return "Full Awake setup is unavailable: \(detail)"
        }
    }
}
