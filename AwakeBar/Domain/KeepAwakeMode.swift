import Foundation

enum KeepAwakeMode: Equatable {
    case off
    case fullAwake

    static func from(state: AppState) -> KeepAwakeMode {
        if state.openLidEnabled && state.closedLidEnabledByApp {
            return .fullAwake
        }
        return .off
    }
}
