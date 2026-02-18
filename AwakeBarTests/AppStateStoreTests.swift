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
            externalClosedLidDetected: true,
            launchAtLoginEnabled: true,
            closedLidSetupState: .ready,
            legacyCleanupCompleted: true,
            legacyCleanupNotice: "x",
            transientErrorMessage: "x"
        )

        store.save(input)
        let loaded = store.load()

        XCTAssertTrue(loaded.openLidEnabled)
        XCTAssertTrue(loaded.launchAtLoginEnabled)
        XCTAssertTrue(loaded.legacyCleanupCompleted)
        XCTAssertFalse(loaded.closedLidEnabledByApp)
        XCTAssertFalse(loaded.externalClosedLidDetected)
        XCTAssertEqual(loaded.closedLidSetupState, .notRegistered)
        XCTAssertNil(loaded.legacyCleanupNotice)
        XCTAssertNil(loaded.transientErrorMessage)
    }
}
