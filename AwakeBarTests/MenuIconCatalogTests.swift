import XCTest
@testable import AwakeBar

final class MenuIconCatalogTests: XCTestCase {
    func testOpenRowProvidesExplicitOffAndOnMappings() {
        let pair = MenuIconCatalog.dropdownPair(for: .openLid)

        XCTAssertEqual(pair.offAssetName, "AwakeBarStatusOff")
        XCTAssertEqual(pair.onAssetName, "AwakeBarStatusOpen")
        XCTAssertEqual(pair.assetName(for: false), "AwakeBarStatusOff")
        XCTAssertEqual(pair.assetName(for: true), "AwakeBarStatusOpen")
    }

    func testClosedRowProvidesExplicitOffAndOnMappings() {
        let pair = MenuIconCatalog.dropdownPair(for: .closedLid)

        XCTAssertEqual(pair.offAssetName, "AwakeBarStatusOff")
        XCTAssertEqual(pair.onAssetName, "AwakeBarStatusClosed")
        XCTAssertEqual(pair.assetName(for: false), "AwakeBarStatusOff")
        XCTAssertEqual(pair.assetName(for: true), "AwakeBarStatusClosed")
    }

    func testStatusBarMappingUsesClosedAssetForExternalState() {
        XCTAssertEqual(MenuIconCatalog.statusBarAssetName(for: .off), "AwakeBarStatusOff")
        XCTAssertEqual(MenuIconCatalog.statusBarAssetName(for: .openLid), "AwakeBarStatusOpen")
        XCTAssertEqual(MenuIconCatalog.statusBarAssetName(for: .closedLid), "AwakeBarStatusClosed")
        XCTAssertEqual(MenuIconCatalog.statusBarAssetName(for: .externalClosedLid), "AwakeBarStatusClosed")
    }
}
