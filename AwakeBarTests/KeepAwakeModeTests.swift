import XCTest
@testable import AwakeBar

final class KeepAwakeModeTests: XCTestCase {
    func testModeIsOffWhenNoAwakeMechanismIsActive() {
        let state = AppState()

        XCTAssertEqual(KeepAwakeMode.from(state: state), .off)
    }

    func testModeIsOffWhenOnlyOpenLidAwakeIsEnabled() {
        var state = AppState()
        state.openLidEnabled = true

        XCTAssertEqual(KeepAwakeMode.from(state: state), .off)
    }

    func testModeIsOffWhenOnlyClosedLidAwakeIsEnabledByApp() {
        var state = AppState()
        state.closedLidEnabledByApp = true

        XCTAssertEqual(KeepAwakeMode.from(state: state), .off)
    }

    func testModeIsFullAwakeWhenOpenAndClosedLidAwakeAreEnabled() {
        var state = AppState()
        state.openLidEnabled = true
        state.closedLidEnabledByApp = true

        XCTAssertEqual(KeepAwakeMode.from(state: state), .fullAwake)
    }
}
