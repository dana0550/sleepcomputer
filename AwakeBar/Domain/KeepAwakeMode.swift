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

    var statusText: String {
        switch self {
        case .off:
            return "Off"
        case .fullAwake:
            return "Full Awake"
        }
    }

    var statusDetailText: String {
        switch self {
        case .off:
            return "Restores normal macOS sleep behavior."
        case .fullAwake:
            return "Prevents sleep with the lid open and with the lid closed."
        }
    }

    var iconAssetName: String {
        switch self {
        case .off:
            return "AwakeBarStatusOff"
        case .fullAwake:
            return "AwakeBarStatusClosed"
        }
    }
}
