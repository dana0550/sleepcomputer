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

        do {
            if daemonService.status != .enabled {
                try daemonService.register()
            }
        } catch {
            return .unavailable("Could not register privileged helper: \(error.localizedDescription)")
        }

        return await refreshStatus()
    }

    func openSystemSettingsForApproval() {
        openSettings()
    }

    static func isInApplications(_ bundleURL: URL) -> Bool {
        let path = bundleURL.path
        return path.hasPrefix("/Applications/")
            || path == "/Applications"
    }
}
