import AppKit
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
    private let lidStateMonitor: LidStateMonitoring
    private let computerLockController: ComputerLockControlling
    private let approvalPollingAttempts: Int
    private let approvalPollingIntervalNanoseconds: UInt64

    private var didBootstrap = false
    private var overrideSession: ClosedLidOverrideSession?
    private var errorClearTask: Task<Void, Never>?
    private var setupStatusPollTask: Task<Void, Never>?
    private var setupStatusPollToken = UUID()
    private var pendingRestoreRetryTask: Task<Void, Never>?
    private var isLidMonitorActive = false
    private var lastObservedLidClosedState: Bool?
    private var isLockAttemptInFlight = false

    init(
        stateStore: AppStateStore = AppStateStore(),
        openLidController: OpenLidSleepControlling = OpenLidAssertionController(),
        closedLidController: ClosedLidSleepControlling? = nil,
        closedLidSetupController: ClosedLidSetupControlling? = nil,
        loginItemController: LoginItemControlling = LoginItemController(),
        lidStateMonitor: LidStateMonitoring? = nil,
        computerLockController: ComputerLockControlling? = nil,
        approvalPollingAttempts: Int = 30,
        approvalPollingIntervalNanoseconds: UInt64 = 1_000_000_000,
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
        self.lidStateMonitor = lidStateMonitor ?? IOKitLidStateMonitor()
        self.computerLockController = computerLockController ?? ComputerLockController()
        self.approvalPollingAttempts = max(1, approvalPollingAttempts)
        self.approvalPollingIntervalNanoseconds = approvalPollingIntervalNanoseconds
        self.state = stateStore.load()
        self.overrideSession = stateStore.loadOverrideSession()

        if autoBootstrap {
            Task { [weak self] in
                await self?.bootstrapIfNeeded()
            }
        }
    }

    deinit {
        errorClearTask?.cancel()
        setupStatusPollTask?.cancel()
        pendingRestoreRetryTask?.cancel()
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

    var lockOnLidCloseEnabled: Bool {
        state.lockOnLidCloseEnabled
    }

    var lockOnLidCloseCapability: ComputerLockCapability {
        computerLockController.lockCapability
    }

    var lockOnLidCloseUnavailableReason: String? {
        lockOnLidCloseCapability.unsupportedReason
    }

    var canEnableLockOnLidClose: Bool {
        lockOnLidCloseCapability.isSupported
    }

    var showsLockOnLidCloseSetting: Bool {
        lidStateMonitor.isSupported
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

    var pendingRestoreMessage: String? {
        guard let session = overrideSession, session.pendingRestore else {
            return nil
        }
        if let error = session.lastRestoreError {
            return "Sleep restore is pending: \(error)"
        }
        return "Sleep restore is pending and will retry."
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else {
            return
        }
        didBootstrap = true

        var loaded = stateStore.load()
        loaded.openLidEnabled = false
        loaded.closedLidEnabledByApp = false
        loaded.closedLidSetupState = .notRegistered
        loaded.transientErrorMessage = nil
        let lockCapability = computerLockController.lockCapability
        let shouldNormalizePersistedLockPreference = loaded.lockOnLidCloseEnabled && !lockCapability.isSupported
        if shouldNormalizePersistedLockPreference {
            loaded.lockOnLidCloseEnabled = false
        }
        state = loaded
        persistSafeState()
        if shouldNormalizePersistedLockPreference {
            setTransientError(lockOnLidCloseUnsupportedMessage(reason: lockCapability.unsupportedReason))
        }

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

        if overrideSession != nil {
            switch await restoreOverrideSession(markPendingOnFailure: true) {
            case .success:
                break
            case .failure(let error):
                setTransientError("Could not restore previous sleep settings on launch: \(error.localizedDescription)")
            }
        }

        await refreshClosedLidRuntimeState()
        await runLegacyCleanupIfNeeded()
        updateLidMonitoringSubscription()
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
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.retryPendingRestoreIfNeeded()
            await self.refreshClosedLidRuntimeState(allowDuringTransition: false)
        }
    }

    func openLoginItemsSettingsForApproval() {
        closedLidSetupController.openSystemSettingsForApproval()

        setupStatusPollTask?.cancel()
        let pollToken = UUID()
        setupStatusPollToken = pollToken

        setupStatusPollTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.setupStatusPollToken == pollToken {
                    self.setupStatusPollTask = nil
                }
            }

            for _ in 0..<self.approvalPollingAttempts {
                guard !Task.isCancelled else {
                    return
                }
                await self.refreshClosedLidRuntimeState()
                if self.state.closedLidSetupState.isReady {
                    return
                }
                try? await Task.sleep(nanoseconds: self.approvalPollingIntervalNanoseconds)
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
            await applyFullAwakeEnable(previousOpen: previousOpen, previousByApp: previousByApp)
            return
        }

        await applyFullAwakeDisable(previousOpen: previousOpen, previousByApp: previousByApp)
    }

    private func applyFullAwakeEnable(previousOpen: Bool, previousByApp: Bool) async {
        var capturedSessionThisAttempt = false

        do {
            await awaitPendingRestoreRetryIfNeeded()

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

            capturedSessionThisAttempt = try await ensureOverrideSessionCaptured()
            try openLidController.setEnabled(true)
            state.openLidEnabled = true
            try await closedLidController.setEnabled(true)
            state.closedLidEnabledByApp = true
            markOverrideSessionActiveForManagedState()
            persistSafeState()
        } catch let ClosedLidControlError.setupRequired(setupState) {
            state.closedLidSetupState = setupState
            if case .approvalRequired = setupState {
                closedLidSetupController.openSystemSettingsForApproval()
            }
            let rollbackIssue = await rollbackFailedEnable(
                previousOpen: previousOpen,
                previousByApp: previousByApp,
                capturedSessionThisAttempt: capturedSessionThisAttempt
            )
            let baseMessage = fullAwakeSetupMessage(for: setupState)
            setTransientError(composeErrorMessage(base: baseMessage, rollbackIssue: rollbackIssue))
            persistSafeState()
        } catch {
            let rollbackIssue = await rollbackFailedEnable(
                previousOpen: previousOpen,
                previousByApp: previousByApp,
                capturedSessionThisAttempt: capturedSessionThisAttempt
            )
            let baseMessage = "Could not enable Full Awake: \(error.localizedDescription)"
            setTransientError(composeErrorMessage(base: baseMessage, rollbackIssue: rollbackIssue))
            persistSafeState()
        }
    }

    private func applyFullAwakeDisable(previousOpen: Bool, previousByApp: Bool) async {
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
            if overrideSession != nil {
                switch await restoreOverrideSession(markPendingOnFailure: false) {
                case .success:
                    break
                case .failure(let error):
                    throw error
                }
            } else {
                try await closedLidController.setEnabled(false)
            }
            state.closedLidEnabledByApp = false
            persistSafeState()
        } catch let ClosedLidControlError.setupRequired(setupState) {
            state.closedLidSetupState = setupState
            let rollbackIssue = await rollbackFailedDisable(previousOpen: previousOpen, previousByApp: previousByApp)
            let baseMessage = "Could not restore previous sleep settings: \(fullAwakeSetupMessage(for: setupState))"
            setTransientError(composeErrorMessage(base: baseMessage, rollbackIssue: rollbackIssue))
            persistSafeState()
        } catch {
            let rollbackIssue = await rollbackFailedDisable(previousOpen: previousOpen, previousByApp: previousByApp)
            let baseMessage = "Could not restore previous sleep settings: \(error.localizedDescription)"
            setTransientError(composeErrorMessage(base: baseMessage, rollbackIssue: rollbackIssue))
            persistSafeState()
        }
    }

    private func markOverrideSessionActiveForManagedState() {
        guard var session = overrideSession else {
            return
        }
        session.pendingRestore = false
        session.lastRestoreError = nil
        overrideSession = session
        persistOverrideSession()
    }

    private func rollbackFailedEnable(
        previousOpen: Bool,
        previousByApp: Bool,
        capturedSessionThisAttempt: Bool
    ) async -> String? {
        var issues: [String] = []

        if let rollbackIssue = rollbackOpenLidState(to: previousOpen) {
            issues.append(rollbackIssue)
        }

        if capturedSessionThisAttempt {
            switch await restoreOverrideSession(markPendingOnFailure: false) {
            case .success:
                break
            case .failure(let error):
                issues.append("Could not restore baseline sleep settings: \(error.localizedDescription)")
            }
        } else if state.closedLidEnabledByApp != previousByApp {
            do {
                try await closedLidController.setEnabled(previousByApp)
            } catch {
                issues.append("Closed-lid awake may be inconsistent because rollback failed: \(error.localizedDescription)")
            }
        }

        state.closedLidEnabledByApp = previousByApp
        return issues.isEmpty ? nil : issues.joined(separator: " ")
    }

    private func rollbackFailedDisable(previousOpen: Bool, previousByApp: Bool) async -> String? {
        var issues: [String] = []

        if let rollbackIssue = rollbackOpenLidState(to: previousOpen) {
            issues.append(rollbackIssue)
        }

        if previousByApp {
            do {
                try await closedLidController.setEnabled(true)
            } catch {
                issues.append("Closed-lid awake may be inconsistent because rollback failed: \(error.localizedDescription)")
            }
        }

        state.closedLidEnabledByApp = previousByApp
        return issues.isEmpty ? nil : issues.joined(separator: " ")
    }

    private func beginFullAwakeTransition(to enabled: Bool) -> Bool {
        guard !isApplyingFullAwakeChange else {
            return false
        }
        isApplyingFullAwakeChange = true
        pendingFullAwakeTarget = enabled
        updateLidMonitoringSubscription()
        return true
    }

    private func endFullAwakeTransition() {
        isApplyingFullAwakeChange = false
        pendingFullAwakeTarget = nil
        updateLidMonitoringSubscription()
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

    func setLockOnLidCloseEnabled(_ enabled: Bool) {
        if enabled, !canEnableLockOnLidClose {
            state.lockOnLidCloseEnabled = false
            persistSafeState()
            setTransientError(
                lockOnLidCloseUnsupportedMessage(reason: lockOnLidCloseUnavailableReason)
            )
            updateLidMonitoringSubscription()
            return
        }

        state.lockOnLidCloseEnabled = enabled
        persistSafeState()
        updateLidMonitoringSubscription()
    }

    func requestQuit() {
        NSApplication.shared.terminate(nil)
    }

    func prepareForTermination() async {
        stopLidMonitoring()

        do {
            try openLidController.setEnabled(false)
            state.openLidEnabled = false
        } catch {
            state.openLidEnabled = openLidController.isEnabled
        }

        if overrideSession != nil {
            switch await restoreOverrideSession(markPendingOnFailure: true) {
            case .success:
                state.closedLidEnabledByApp = false
            case .failure:
                state.closedLidEnabledByApp = false
            }
            persistSafeState()
            return
        }

        if state.closedLidEnabledByApp {
            do {
                try await closedLidController.setEnabled(false)
                state.closedLidEnabledByApp = false
            } catch {
                setTransientError("Could not restore previous sleep settings during quit: \(error.localizedDescription)")
            }
        }

        persistSafeState()
    }

    func turnEverythingOff() async {
        await setFullAwakeEnabled(false)
    }

    private func refreshClosedLidRuntimeState(allowDuringTransition: Bool = false) async {
        guard allowDuringTransition || !isApplyingFullAwakeChange else {
            return
        }

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
                        updateLidMonitoringSubscription()
                        return
                    }
                }
            }

            if wasOpenEnabled && !state.openLidEnabled {
                persistSafeState()
            }
            updateLidMonitoringSubscription()
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

        updateLidMonitoringSubscription()
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

    @discardableResult
    private func ensureOverrideSessionCaptured() async throws -> Bool {
        guard overrideSession == nil else {
            return false
        }
        let snapshot = try await closedLidController.captureManagedOverridesBaseline()
        overrideSession = ClosedLidOverrideSession(snapshot: snapshot)
        persistOverrideSession()
        return true
    }

    @discardableResult
    private func restoreOverrideSession(markPendingOnFailure: Bool) async -> Result<Void, Error> {
        guard var session = overrideSession else {
            return .success(())
        }

        session.lastRestoreAttemptAt = Date()
        session.pendingRestore = false
        session.lastRestoreError = nil
        overrideSession = session
        persistOverrideSession()
        let inFlightSession = session

        do {
            try await closedLidController.restoreManagedOverrides(from: session.snapshot)
            if overrideSession == inFlightSession {
                overrideSession = nil
                persistOverrideSession()
            }
            return .success(())
        } catch {
            session.pendingRestore = markPendingOnFailure
            session.lastRestoreError = error.localizedDescription
            session.lastRestoreAttemptAt = Date()
            if overrideSession == inFlightSession {
                overrideSession = session
                persistOverrideSession()
            }
            return .failure(error)
        }
    }

    private func retryPendingRestoreIfNeeded() async {
        guard !isApplyingFullAwakeChange else {
            return
        }
        guard overrideSession?.pendingRestore == true else {
            return
        }
        if let pendingRestoreRetryTask {
            await pendingRestoreRetryTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.pendingRestoreRetryTask = nil
            }

            switch await self.restoreOverrideSession(markPendingOnFailure: true) {
            case .success:
                break
            case .failure(let error):
                self.setTransientError("Could not restore previous sleep settings: \(error.localizedDescription)")
            }
        }

        pendingRestoreRetryTask = task
        await task.value
    }

    private func awaitPendingRestoreRetryIfNeeded() async {
        if let pendingRestoreRetryTask {
            await pendingRestoreRetryTask.value
        }
    }

    private func persistSafeState() {
        stateStore.save(state)
    }

    private func persistOverrideSession() {
        stateStore.saveOverrideSession(overrideSession)
    }

    private var shouldMonitorLidForLocking: Bool {
        state.lockOnLidCloseEnabled &&
        isFullAwakeEnabled &&
        lidStateMonitor.isSupported &&
        canEnableLockOnLidClose &&
        !isApplyingFullAwakeChange
    }

    private func updateLidMonitoringSubscription() {
        if shouldMonitorLidForLocking {
            startLidMonitoringIfNeeded()
        } else {
            stopLidMonitoring()
        }
    }

    private func startLidMonitoringIfNeeded() {
        guard !isLidMonitorActive else {
            return
        }

        do {
            try lidStateMonitor.startMonitoring { [weak self] isClosed in
                self?.handleLidStateChange(isClosed)
            }
            isLidMonitorActive = true
            lastObservedLidClosedState = nil
        } catch {
            stopLidMonitoring()
            setTransientError("Could not monitor lid state: \(error.localizedDescription)")
        }
    }

    private func stopLidMonitoring() {
        lidStateMonitor.stopMonitoring()
        isLidMonitorActive = false
        isLockAttemptInFlight = false
        lastObservedLidClosedState = nil
    }

    private func handleLidStateChange(_ isClosed: Bool) {
        guard shouldMonitorLidForLocking else {
            return
        }
        guard lastObservedLidClosedState != isClosed else {
            return
        }
        lastObservedLidClosedState = isClosed
        guard isClosed else {
            return
        }
        guard !isLockAttemptInFlight else {
            return
        }
        isLockAttemptInFlight = true

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                self.isLockAttemptInFlight = false
            }
            guard self.shouldMonitorLidForLocking else {
                return
            }
            do {
                try await self.computerLockController.lockNow()
            } catch {
                self.setTransientError("Could not lock computer on lid close: \(error.localizedDescription)")
            }
        }
    }

    private func rollbackOpenLidState(to previousOpen: Bool) -> String? {
        do {
            try openLidController.setEnabled(previousOpen)
            state.openLidEnabled = previousOpen
            return nil
        } catch {
            state.openLidEnabled = openLidController.isEnabled
            guard state.openLidEnabled != previousOpen else {
                return nil
            }
            return "Open-lid awake may still be active because rollback failed: \(error.localizedDescription)"
        }
    }

    private func composeErrorMessage(base: String, rollbackIssue: String?) -> String {
        guard let rollbackIssue else {
            return base
        }
        return "\(base) \(rollbackIssue)"
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

    private func lockOnLidCloseUnsupportedMessage(reason: String?) -> String {
        if let reason, !reason.isEmpty {
            return "Lock on lid close is unavailable: \(reason)"
        }
        return "Lock on lid close is unavailable on this macOS version."
    }
}
