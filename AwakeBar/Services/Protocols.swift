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
}

@MainActor
protocol LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws
    func readEnabled() -> Bool
}
