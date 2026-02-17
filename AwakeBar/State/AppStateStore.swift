import Foundation

final class AppStateStore {
    private enum Keys {
        static let openLidEnabled = "awakebar.openLidEnabled"
        static let launchAtLoginEnabled = "awakebar.launchAtLoginEnabled"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> AppState {
        AppState(
            openLidEnabled: userDefaults.bool(forKey: Keys.openLidEnabled),
            closedLidEnabledByApp: false,
            externalClosedLidDetected: false,
            launchAtLoginEnabled: userDefaults.bool(forKey: Keys.launchAtLoginEnabled),
            transientErrorMessage: nil
        )
    }

    func save(_ state: AppState) {
        userDefaults.set(state.openLidEnabled, forKey: Keys.openLidEnabled)
        userDefaults.set(state.launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
    }
}
