import Foundation
import ServiceManagement

@MainActor
final class LoginItemController: LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        let status = service.status

        if enabled {
            if status != .enabled {
                try service.register()
            }
        } else if status == .enabled {
            try service.unregister()
        }
    }

    func readEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}
