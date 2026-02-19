import XCTest
@testable import AwakeBar

final class MenuIconCatalogTests: XCTestCase {
    func testStatusBarMappingMatchesTwoStateModel() {
        XCTAssertEqual(MenuIconCatalog.statusBarAssetName(for: .off), "AwakeBarStatusOff")
        XCTAssertEqual(MenuIconCatalog.statusBarAssetName(for: .fullAwake), "AwakeBarStatusClosed")
    }

    func testStatusBarMappingUsesDistinctAssetsPerMode() {
        let offAsset = MenuIconCatalog.statusBarAssetName(for: .off)
        let onAsset = MenuIconCatalog.statusBarAssetName(for: .fullAwake)

        XCTAssertNotEqual(offAsset, onAsset)
    }
}
