import Foundation

@MainActor
protocol OpenLidSleepControlling {
    func setEnabled(_ enabled: Bool) throws
    var isEnabled: Bool { get }
}

@MainActor
protocol ClosedLidSleepControlling {
    func setEnabled(_ enabled: Bool) async throws
    func readSleepDisabled() async throws -> Bool
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
