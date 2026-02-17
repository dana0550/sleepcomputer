import Foundation

struct AppState: Equatable {
    var openLidEnabled: Bool = false
    var closedLidEnabledByApp: Bool = false
    var externalClosedLidDetected: Bool = false
    var launchAtLoginEnabled: Bool = false
    var transientErrorMessage: String? = nil
}
