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
    private let daemonClient: PrivilegedDaemonControlling
    private let daemonService: DaemonServiceManaging
    private let appBundleURLProvider: () -> URL
    private let retryDelayNanoseconds: UInt64
    private let openSettings: () -> Void

    init(
        daemonClient: PrivilegedDaemonControlling = PrivilegedDaemonClient(),
        daemonService: DaemonServiceManaging = SMAppServiceDaemonService(plistName: PrivilegedServiceConstants.daemonPlistName),
        appBundleURLProvider: @escaping () -> URL = { Bundle.main.bundleURL },
        retryDelayNanoseconds: UInt64 = 1_000_000_000,
        openSettings: @escaping () -> Void = { SMAppService.openSystemSettingsLoginItems() }
    ) {
        self.daemonClient = daemonClient
        self.daemonService = daemonService
        self.appBundleURLProvider = appBundleURLProvider
        self.retryDelayNanoseconds = retryDelayNanoseconds
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
            return .unavailable("Privileged helper was not found in the app bundle.")
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
        case .notFound:
            return .unavailable("Privileged helper was not found in the app bundle.")
        case .enabled:
            if await waitForHelperReachable(maxAttempts: 3) {
                return .ready
            }
            return .unavailable(helperUnavailableMessage(error: nil))
        case .notRegistered:
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
        case .notFound:
            return .unavailable("Privileged helper was not found in the app bundle.")
        case .notRegistered:
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

    private func helperUnavailableMessage(error: Error?) -> String {
        var segments = ["Privileged helper is registered but macOS did not launch it."]
        if let error {
            segments.append("Last error: \(error.localizedDescription).")
        }
        segments.append("Quit AwakeBar, reinstall it in /Applications, then restart your Mac.")
        segments.append("If it still fails, reset Background Items with 'sfltool resetbtm' and reboot.")
        return segments.joined(separator: " ")
    }
}
