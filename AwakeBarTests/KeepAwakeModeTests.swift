import XCTest
@testable import AwakeBar

final class KeepAwakeModeTests: XCTestCase {
    func testModeIsOffWhenNoAwakeMechanismIsActive() {
        let state = AppState()

        XCTAssertEqual(KeepAwakeMode.from(state: state), .off)
    }

    func testModeIsFullAwakeWhenOpenLidAwakeIsEnabled() {
        var state = AppState()
        state.openLidEnabled = true

        XCTAssertEqual(KeepAwakeMode.from(state: state), .fullAwake)
    }

    func testModeIsFullAwakeWhenClosedLidAwakeIsEnabledByApp() {
        var state = AppState()
        state.closedLidEnabledByApp = true

        XCTAssertEqual(KeepAwakeMode.from(state: state), .fullAwake)
    }

    func testModeIsOffWhenOnlyExternalClosedLidAwakeIsDetected() {
        var state = AppState()
        state.externalClosedLidDetected = true

        XCTAssertEqual(KeepAwakeMode.from(state: state), .off)
    }

    func testStatusTextAndDetailAreHumanReadable() {
        XCTAssertEqual(KeepAwakeMode.off.statusText, "Off")
        XCTAssertEqual(KeepAwakeMode.off.statusDetailText, "Restores normal macOS sleep behavior.")

        XCTAssertEqual(KeepAwakeMode.fullAwake.statusText, "Full Awake")
        XCTAssertEqual(
            KeepAwakeMode.fullAwake.statusDetailText,
            "Prevents sleep with the lid open and with the lid closed."
        )
    }

    func testIconAssetNameMapsEachMode() {
        XCTAssertEqual(KeepAwakeMode.off.iconAssetName, "AwakeBarStatusOff")
        XCTAssertEqual(KeepAwakeMode.fullAwake.iconAssetName, "AwakeBarStatusClosed")
    }
}
