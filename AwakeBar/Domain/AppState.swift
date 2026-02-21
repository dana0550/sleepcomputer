import Foundation

struct AppState: Equatable {
    var openLidEnabled: Bool = false
    var closedLidEnabledByApp: Bool = false
    var launchAtLoginEnabled: Bool = false
    var closedLidSetupState: ClosedLidSetupState = .notRegistered
    var legacyCleanupCompleted: Bool = false
    var transientErrorMessage: String? = nil
}
