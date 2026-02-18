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
        XCTAssertEqual(KeepAwakeMode.off.statusDetailText, "Uses your normal macOS sleep settings.")
        XCTAssertEqual(KeepAwakeMode.openLid.statusDetailText, "Keeps your Mac and display awake while the lid is open.")
        XCTAssertEqual(
            KeepAwakeMode.closedLid.statusDetailText,
            "Disables system sleep, including with lid closed, until you turn it off."
        )
        XCTAssertEqual(
            KeepAwakeMode.externalClosedLid.statusDetailText,
            "System sleep was disabled outside AwakeBar. Turn it off here to restore defaults."
        )
    }
}
