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
    private let openSettings: () -> Void

    init(
        daemonClient: PrivilegedDaemonControlling = PrivilegedDaemonClient(),
        daemonService: DaemonServiceManaging = SMAppServiceDaemonService(plistName: PrivilegedServiceConstants.daemonPlistName),
        appBundleURLProvider: @escaping () -> URL = { Bundle.main.bundleURL },
        openSettings: @escaping () -> Void = { SMAppService.openSystemSettingsLoginItems() }
    ) {
        self.daemonClient = daemonClient
        self.daemonService = daemonService
        self.appBundleURLProvider = appBundleURLProvider
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
                if try await daemonClient.ping() {
                    return .ready
                }
                return .unavailable("Privileged helper did not respond to ping.")
            } catch {
                return .unavailable("Privileged helper is registered but unavailable: \(error.localizedDescription)")
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
            if await waitForHelperReachable(maxAttempts: 2) {
                return .ready
            }

            // Repair stale registrations where service is marked enabled but XPC is unreachable.
            _ = try? daemonService.unregister()
            _ = try? daemonService.register()

            if await waitForHelperReachable(maxAttempts: 3) {
                return .ready
            }

            return await refreshStatus()
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

        if await waitForHelperReachable(maxAttempts: 3) {
            return .ready
        }

        // One repair pass handles delayed launchd propagation after first-time registration.
        _ = try? daemonService.unregister()
        _ = try? daemonService.register()

        if await waitForHelperReachable(maxAttempts: 3) {
            return .ready
        }

        return await refreshStatus()
    }

    func openSystemSettingsForApproval() {
        openSettings()
    }

    static func isInApplications(_ bundleURL: URL) -> Bool {
        bundleURL.path.hasPrefix("/Applications/")
    }

    private func isHelperReachable() async -> Bool {
        (try? await daemonClient.ping()) == true
    }

    private func waitForHelperReachable(maxAttempts: Int) async -> Bool {
        guard maxAttempts > 0 else {
            return false
        }

        for attempt in 0..<maxAttempts {
            if await isHelperReachable() {
                return true
            }
            if attempt < maxAttempts - 1 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        return false
    }
}
