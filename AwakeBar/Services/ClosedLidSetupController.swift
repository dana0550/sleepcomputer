import Foundation
import ServiceManagement

protocol DaemonServiceManaging {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

struct SMAppServiceDaemonService: DaemonServiceManaging {
    private let service: SMAppService

    init(plistName: String) {
        service = SMAppService.daemon(plistName: plistName)
    }

    var status: SMAppService.Status {
        service.status
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}

@MainActor
final class ClosedLidSetupController: ClosedLidSetupControlling {
    private static let initialEnabledWaitAttempts = 3

    private let daemonClient: PrivilegedDaemonControlling
    private let daemonService: DaemonServiceManaging
    private let appBundleURLProvider: () -> URL
    private let retryDelayNanoseconds: UInt64
    private let softRetryAttemptsBeforeRepair: Int
    private let enabledRepairCooldownNanoseconds: UInt64
    private let now: () -> Date
    private let openSettings: () -> Void
    private var lastEnabledRepairAttemptAt: Date?

    init(
        daemonClient: PrivilegedDaemonControlling = PrivilegedDaemonClient(),
        daemonService: DaemonServiceManaging = SMAppServiceDaemonService(plistName: PrivilegedServiceConstants.daemonPlistName),
        appBundleURLProvider: @escaping () -> URL = { Bundle.main.bundleURL },
        retryDelayNanoseconds: UInt64 = 1_000_000_000,
        softRetryAttemptsBeforeRepair: Int = 4,
        enabledRepairCooldownNanoseconds: UInt64 = 60_000_000_000,
        now: @escaping () -> Date = Date.init,
        openSettings: @escaping () -> Void = { SMAppService.openSystemSettingsLoginItems() }
    ) {
        self.daemonClient = daemonClient
        self.daemonService = daemonService
        self.appBundleURLProvider = appBundleURLProvider
        self.retryDelayNanoseconds = retryDelayNanoseconds
        self.softRetryAttemptsBeforeRepair = max(0, softRetryAttemptsBeforeRepair)
        self.enabledRepairCooldownNanoseconds = enabledRepairCooldownNanoseconds
        self.now = now
        self.openSettings = openSettings
    }

    func refreshStatus() async -> ClosedLidSetupState {
        guard Self.isInApplications(appBundleURLProvider()) else {
            return .notInApplications
        }

        switch daemonService.status {
        case .notRegistered:
            return .notRegistered
        case .requiresApproval:
            return .approvalRequired
        case .notFound:
            // On newer macOS builds, `notFound` is returned when no BTM record exists yet.
            // Treat it as setup-required so first-time registration can proceed.
            return .notRegistered
        case .enabled:
            do {
                try await daemonClient.ping()
                return .ready
            } catch {
                return .unavailable(helperUnavailableMessage(error: error))
            }
        @unknown default:
            return .unavailable("Unknown privileged helper status.")
        }
    }

    func startSetup() async -> ClosedLidSetupState {
        guard Self.isInApplications(appBundleURLProvider()) else {
            return .notInApplications
        }

        let currentStatus = daemonService.status
        switch currentStatus {
        case .requiresApproval:
            return .approvalRequired
        case .enabled:
            if await waitForHelperReachable(maxAttempts: totalEnabledWaitAttemptsBeforeRepair) {
                return .ready
            }

            switch daemonService.status {
            case .requiresApproval:
                return .approvalRequired
            case .notRegistered, .notFound:
                return .notRegistered
            case .enabled:
                break
            @unknown default:
                return .unavailable("Unknown privileged helper status.")
            }

            if let remainingSeconds = remainingEnabledRepairCooldownSeconds() {
                return .unavailable(
                    helperUnavailableMessage(
                        error: nil,
                        additional: "Automatic helper re-registration is cooling down (\(remainingSeconds)s remaining). Try again shortly."
                    )
                )
            }

            lastEnabledRepairAttemptAt = now()
            return await repairEnabledButUnreachable()
        case .notRegistered, .notFound:
            break
        @unknown default:
            return .unavailable("Unknown privileged helper status.")
        }

        do {
            try daemonService.register()
        } catch {
            return .unavailable("Could not register privileged helper: \(error.localizedDescription)")
        }

        switch daemonService.status {
        case .requiresApproval:
            return .approvalRequired
        case .notRegistered, .notFound:
            return .unavailable("Privileged helper registration did not persist.")
        default:
            break
        }

        if await waitForHelperReachable(maxAttempts: 4) {
            return .ready
        }

        return .unavailable(helperUnavailableMessage(error: nil))
    }

    private func repairEnabledButUnreachable() async -> ClosedLidSetupState {
        do {
            try daemonService.unregister()
        } catch {
            return .unavailable("Could not reset privileged helper registration: \(error.localizedDescription)")
        }

        do {
            try daemonService.register()
        } catch {
            return .unavailable("Could not re-register privileged helper: \(error.localizedDescription)")
        }

        switch daemonService.status {
        case .requiresApproval:
            return .approvalRequired
        case .notRegistered, .notFound:
            return .unavailable("Privileged helper registration did not persist.")
        default:
            break
        }

        if await waitForHelperReachable(maxAttempts: 4) {
            return .ready
        }

        return .unavailable(helperUnavailableMessage(error: nil))
    }

    func openSystemSettingsForApproval() {
        openSettings()
    }

    static func isInApplications(_ bundleURL: URL) -> Bool {
        bundleURL.path.hasPrefix("/Applications/")
    }

    private func isHelperReachable() async -> Bool {
        (try? await daemonClient.ping()) != nil
    }

    private func waitForHelperReachable(maxAttempts: Int) async -> Bool {
        guard maxAttempts > 0 else {
            return false
        }

        for attempt in 0..<maxAttempts {
            guard daemonService.status == .enabled else {
                return false
            }
            if await isHelperReachable() {
                return true
            }
            if attempt < maxAttempts - 1, retryDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
            }
        }
        return false
    }

    private var totalEnabledWaitAttemptsBeforeRepair: Int {
        Self.initialEnabledWaitAttempts + softRetryAttemptsBeforeRepair
    }

    private func remainingEnabledRepairCooldownSeconds() -> Int? {
        guard enabledRepairCooldownNanoseconds > 0 else {
            return nil
        }
        guard let lastEnabledRepairAttemptAt else {
            return nil
        }

        let cooldownSeconds = Double(enabledRepairCooldownNanoseconds) / 1_000_000_000
        let elapsed = now().timeIntervalSince(lastEnabledRepairAttemptAt)
        guard elapsed < cooldownSeconds else {
            return nil
        }

        return max(1, Int(ceil(cooldownSeconds - elapsed)))
    }

    private func helperUnavailableMessage(error: Error?, additional: String? = nil) -> String {
        var segments = ["Privileged helper is registered but macOS did not launch it."]
        if let error {
            segments.append("Last error: \(error.localizedDescription).")
        }
        if let additional {
            segments.append(additional)
        }
        segments.append("Quit AwakeBar, reinstall it in /Applications, then restart your Mac.")
        segments.append("If it still fails, reset Background Items with 'sfltool resetbtm' and reboot.")
        return segments.joined(separator: " ")
    }
}
