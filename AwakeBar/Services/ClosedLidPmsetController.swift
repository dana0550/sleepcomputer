import Foundation

enum ClosedLidControlError: Error, LocalizedError {
    case setupRequired(ClosedLidSetupState)

    var errorDescription: String? {
        switch self {
        case .setupRequired(let state):
            return state.detail
        }
    }
}

@MainActor
final class ClosedLidPmsetController: ClosedLidSleepControlling {
    private let daemonClient: PrivilegedDaemonControlling
    private let setupController: ClosedLidSetupControlling

    // Exposed for composition so higher-level wiring can share setup + daemon defaults.
    var setupStateController: ClosedLidSetupControlling {
        setupController
    }

    init(
        daemonClient: PrivilegedDaemonControlling = PrivilegedDaemonClient(),
        setupController: ClosedLidSetupControlling? = nil
    ) {
        self.daemonClient = daemonClient
        self.setupController = setupController ?? ClosedLidSetupController(daemonClient: daemonClient)
    }

    func setEnabled(_ enabled: Bool) async throws {
        let setupState = await setupController.refreshStatus()
        guard setupState.isReady else {
            throw ClosedLidControlError.setupRequired(setupState)
        }

        try await daemonClient.setSleepDisabled(enabled)
    }

    func readSleepDisabled() async throws -> Bool {
        let setupState = await setupController.refreshStatus()
        guard setupState.isReady else {
            throw ClosedLidControlError.setupRequired(setupState)
        }

        return try await daemonClient.readSleepDisabled()
    }

    func captureManagedOverridesBaseline() async throws -> ClosedLidOverrideSnapshot {
        let setupState = await setupController.refreshStatus()
        guard setupState.isReady else {
            throw ClosedLidControlError.setupRequired(setupState)
        }

        let sleepDisabled = try await daemonClient.readSleepDisabled()
        return ClosedLidOverrideSnapshot(sleepDisabled: sleepDisabled)
    }

    func restoreManagedOverrides(from snapshot: ClosedLidOverrideSnapshot) async throws {
        let setupState = await setupController.refreshStatus()
        guard setupState.isReady else {
            throw ClosedLidControlError.setupRequired(setupState)
        }
        guard let sleepDisabled = snapshot[.sleepDisabled] else {
            return
        }

        try await daemonClient.setSleepDisabled(sleepDisabled)
    }

    func cleanupLegacyArtifacts() async throws -> LegacyCleanupReport {
        let setupState = await setupController.refreshStatus()
        guard setupState.isReady else {
            throw ClosedLidControlError.setupRequired(setupState)
        }

        return try await daemonClient.cleanupLegacyArtifacts()
    }
}
