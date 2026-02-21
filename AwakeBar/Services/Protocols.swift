import Foundation

enum ComputerLockCapability: Equatable {
    case supported
    case unsupported(reason: String)

    var isSupported: Bool {
        if case .supported = self {
            return true
        }
        return false
    }

    var unsupportedReason: String? {
        if case .unsupported(let reason) = self {
            return reason
        }
        return nil
    }
}

@MainActor
protocol OpenLidSleepControlling {
    func setEnabled(_ enabled: Bool) throws
    var isEnabled: Bool { get }
}

@MainActor
protocol ClosedLidSleepControlling {
    func setEnabled(_ enabled: Bool) async throws
    func readSleepDisabled() async throws -> Bool
    func captureManagedOverridesBaseline() async throws -> ClosedLidOverrideSnapshot
    func restoreManagedOverrides(from snapshot: ClosedLidOverrideSnapshot) async throws
    func cleanupLegacyArtifacts() async throws -> LegacyCleanupReport
}

@MainActor
protocol ClosedLidSetupControlling {
    func refreshStatus() async -> ClosedLidSetupState
    func startSetup() async -> ClosedLidSetupState
    func openSystemSettingsForApproval()
}

@MainActor
protocol LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws
    func readEnabled() -> Bool
}

@MainActor
protocol LidStateMonitoring {
    var isSupported: Bool { get }
    func startMonitoring(onLidStateChange: @escaping (Bool) -> Void) throws
    func stopMonitoring()
}

@MainActor
protocol ComputerLockControlling {
    var lockCapability: ComputerLockCapability { get }
    func lockNow() async throws
}
