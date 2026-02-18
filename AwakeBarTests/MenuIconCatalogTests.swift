import XCTest
@testable import AwakeBar

final class MenuIconCatalogTests: XCTestCase {
    func testFullAwakeToggleProvidesDistinctOffAndOnAssets() {
        XCTAssertEqual(MenuIconCatalog.fullAwakeToggleAssetName(isOn: false), "AwakeBarStatusOff")
        XCTAssertEqual(MenuIconCatalog.fullAwakeToggleAssetName(isOn: true), "AwakeBarStatusClosed")
    }

    func testStatusBarMappingMatchesTwoStateModel() {
        XCTAssertEqual(MenuIconCatalog.statusBarAssetName(for: .off), "AwakeBarStatusOff")
        XCTAssertEqual(MenuIconCatalog.statusBarAssetName(for: .fullAwake), "AwakeBarStatusClosed")
    }
}
