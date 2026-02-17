import Foundation

enum KeepAwakeMode: Equatable {
    case off
    case openLid
    case closedLid
    case externalClosedLid

    static func from(state: AppState) -> KeepAwakeMode {
        if state.closedLidEnabledByApp {
            return .closedLid
        }
        if state.externalClosedLidDetected {
            return .externalClosedLid
        }
        if state.openLidEnabled {
            return .openLid
        }
        return .off
    }

    var statusText: String {
        switch self {
        case .off:
            return "Off"
        case .openLid:
            return "Open-Lid Active"
        case .closedLid:
            return "Closed-Lid Active"
        case .externalClosedLid:
            return "External Closed-Lid Active"
        }
    }

    var iconAssetName: String {
        switch self {
        case .off:
            return "AwakeBarStatusOff"
        case .openLid:
            return "AwakeBarStatusOpen"
        case .closedLid, .externalClosedLid:
            return "AwakeBarStatusClosed"
        }
    }
}
