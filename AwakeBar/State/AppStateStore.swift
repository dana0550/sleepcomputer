import Foundation

final class AppStateStore {
    private enum Keys {
        static let legacyOpenLidEnabled = "awakebar.openLidEnabled"
        static let legacyLockOnLidCloseEnabled = "awakebar.lockOnLidCloseEnabled"
        static let launchAtLoginEnabled = "awakebar.launchAtLoginEnabled"
        static let legacyCleanupCompleted = "awakebar.legacyCleanupCompleted"
        static let overrideSession = "awakebar.overrideSession.v1"
    }

    private let userDefaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> AppState {
        AppState(
            openLidEnabled: false,
            closedLidEnabledByApp: false,
            launchAtLoginEnabled: userDefaults.bool(forKey: Keys.launchAtLoginEnabled),
            closedLidSetupState: .notRegistered,
            legacyCleanupCompleted: userDefaults.bool(forKey: Keys.legacyCleanupCompleted),
            transientErrorMessage: nil
        )
    }

    func save(_ state: AppState) {
        userDefaults.removeObject(forKey: Keys.legacyOpenLidEnabled)
        userDefaults.removeObject(forKey: Keys.legacyLockOnLidCloseEnabled)
        userDefaults.set(state.launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
        userDefaults.set(state.legacyCleanupCompleted, forKey: Keys.legacyCleanupCompleted)
    }

    func loadOverrideSession() -> ClosedLidOverrideSession? {
        guard let data = userDefaults.data(forKey: Keys.overrideSession) else {
            return nil
        }
        guard let session = try? decoder.decode(ClosedLidOverrideSession.self, from: data) else {
            userDefaults.removeObject(forKey: Keys.overrideSession)
            return nil
        }
        guard session.schemaVersion == ClosedLidOverrideSession.currentSchemaVersion else {
            userDefaults.removeObject(forKey: Keys.overrideSession)
            return nil
        }
        return session
    }

    func saveOverrideSession(_ session: ClosedLidOverrideSession?) {
        guard let session else {
            userDefaults.removeObject(forKey: Keys.overrideSession)
            return
        }
        guard let data = try? encoder.encode(session) else {
            return
        }
        userDefaults.set(data, forKey: Keys.overrideSession)
    }
}
