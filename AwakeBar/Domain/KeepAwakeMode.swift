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
            return "Normal Sleep"
        case .openLid:
            return "Stay Awake (Lid Open)"
        case .closedLid:
            return "Stay Awake (Lid Closed)"
        case .externalClosedLid:
            return "Stay Awake (External)"
        }
    }

    var statusDetailText: String {
        switch self {
        case .off:
            return "Uses your normal macOS sleep settings."
        case .openLid:
            return "Keeps your Mac and display awake while the lid is open."
        case .closedLid:
            return "Disables system sleep, including with lid closed, until you turn it off."
        case .externalClosedLid:
            return "System sleep was disabled outside AwakeBar. Turn it off here to restore defaults."
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
