import Foundation

struct AppState: Equatable {
    var openLidEnabled: Bool = false
    var closedLidEnabledByApp: Bool = false
    var externalClosedLidDetected: Bool = false
    var launchAtLoginEnabled: Bool = false
    var closedLidSetupState: ClosedLidSetupState = .notRegistered
    var legacyCleanupCompleted: Bool = false
    var legacyCleanupNotice: String? = nil
    var transientErrorMessage: String? = nil
}
