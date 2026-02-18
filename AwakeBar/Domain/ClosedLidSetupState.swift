import Foundation

enum ClosedLidSetupState: Equatable {
    case notInApplications
    case notRegistered
    case approvalRequired
    case ready
    case unavailable(String)

    var isReady: Bool {
        if case .ready = self {
            return true
        }
        return false
    }

    var title: String {
        switch self {
        case .notInApplications:
            return "Move AwakeBar to /Applications"
        case .notRegistered:
            return "Enable Closed-Lid Control"
        case .approvalRequired:
            return "Approval Required"
        case .ready:
            return "Closed-Lid Control Ready"
        case .unavailable:
            return "Closed-Lid Control Unavailable"
        }
    }

    var detail: String {
        switch self {
        case .notInApplications:
            return "Install AwakeBar in /Applications to enable privileged closed-lid control."
        case .notRegistered:
            return "Run one-time setup to register the privileged helper."
        case .approvalRequired:
            return "Approve the helper in System Settings > Login Items."
        case .ready:
            return "Closed-lid commands are available."
        case .unavailable(let message):
            return message
        }
    }
}
