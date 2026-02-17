import XCTest
@testable import AwakeBar

final class KeepAwakeModeTests: XCTestCase {
    func testModePrefersClosedLid() {
        var state = AppState()
        state.openLidEnabled = true
        state.externalClosedLidDetected = true
        state.closedLidEnabledByApp = true

        XCTAssertEqual(KeepAwakeMode.from(state: state), .closedLid)
    }

    func testModeUsesExternalWhenDetected() {
        var state = AppState()
        state.openLidEnabled = true
        state.externalClosedLidDetected = true

        XCTAssertEqual(KeepAwakeMode.from(state: state), .externalClosedLid)
    }

    func testModeUsesOpenLid() {
        var state = AppState()
        state.openLidEnabled = true

        XCTAssertEqual(KeepAwakeMode.from(state: state), .openLid)
    }

    func testStatusDetailTextIsHumanReadable() {
        XCTAssertEqual(KeepAwakeMode.off.statusDetailText, "Normal macOS sleep behavior is active.")
        XCTAssertEqual(KeepAwakeMode.openLid.statusDetailText, "Keeps your Mac awake while the lid is open.")
        XCTAssertEqual(KeepAwakeMode.closedLid.statusDetailText, "Sleep is disabled system-wide until you turn this off.")
        XCTAssertEqual(
            KeepAwakeMode.externalClosedLid.statusDetailText,
            "Sleep is disabled outside this app. Toggle off to restore default behavior."
        )
    }
}
