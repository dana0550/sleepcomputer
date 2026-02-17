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
}
