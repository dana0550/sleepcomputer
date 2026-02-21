import XCTest
@testable import AwakeBar

final class AppStateStoreTests: XCTestCase {
    func testSaveAndLoadPersistsOnlySafeState() {
        let suiteName = "AppStateStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create UserDefaults suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = AppStateStore(userDefaults: defaults)
        let input = AppState(
            openLidEnabled: true,
            closedLidEnabledByApp: true,
            launchAtLoginEnabled: true,
            closedLidSetupState: .ready,
            legacyCleanupCompleted: true,
            transientErrorMessage: "x"
        )

        store.save(input)
        let loaded = store.load()

        XCTAssertFalse(loaded.openLidEnabled)
        XCTAssertTrue(loaded.launchAtLoginEnabled)
        XCTAssertTrue(loaded.legacyCleanupCompleted)
        XCTAssertFalse(loaded.closedLidEnabledByApp)
        XCTAssertEqual(loaded.closedLidSetupState, .notRegistered)
        XCTAssertNil(loaded.transientErrorMessage)
    }

    func testSaveClearsLegacyRestoreIntentKey() {
        let suiteName = "AppStateStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create UserDefaults suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(true, forKey: "awakebar.openLidEnabled")

        let store = AppStateStore(userDefaults: defaults)
        store.save(AppState())

        XCTAssertNil(defaults.object(forKey: "awakebar.openLidEnabled"))
        XCTAssertFalse(store.load().openLidEnabled)
    }

    func testOverrideSessionRoundTrips() {
        let suiteName = "AppStateStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create UserDefaults suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = AppStateStore(userDefaults: defaults)
        let session = ClosedLidOverrideSession(snapshot: ClosedLidOverrideSnapshot(sleepDisabled: true))

        store.saveOverrideSession(session)

        XCTAssertEqual(store.loadOverrideSession(), session)

        store.saveOverrideSession(nil)
        XCTAssertNil(store.loadOverrideSession())
    }

    func testLoadOverrideSessionDropsUnknownSchema() throws {
        let suiteName = "AppStateStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create UserDefaults suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = AppStateStore(userDefaults: defaults)
        var session = ClosedLidOverrideSession(snapshot: ClosedLidOverrideSnapshot(sleepDisabled: true))
        session.schemaVersion = ClosedLidOverrideSession.currentSchemaVersion + 1
        let data = try JSONEncoder().encode(session)
        defaults.set(data, forKey: "awakebar.overrideSession.v1")

        XCTAssertNil(store.loadOverrideSession())
        XCTAssertNil(defaults.object(forKey: "awakebar.overrideSession.v1"))
    }
}
