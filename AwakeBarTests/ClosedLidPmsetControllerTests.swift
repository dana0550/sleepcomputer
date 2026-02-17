import XCTest
@testable import AwakeBar

@MainActor
final class ClosedLidPmsetControllerTests: XCTestCase {
    func testParseSleepDisabledTrue() {
        let output = """
        System-wide power settings:
         SleepDisabled\t\t1
        Currently in use:
         sleep 0
        """

        XCTAssertTrue(ClosedLidPmsetController.parseSleepDisabled(output))
    }

    func testParseSleepDisabledFalse() {
        let output = """
        System-wide power settings:
         SleepDisabled\t\t0
        """

        XCTAssertFalse(ClosedLidPmsetController.parseSleepDisabled(output))
    }

    func testParseSleepDisabledFalseWhenMissing() {
        let output = "System-wide power settings:\n sleep 0"
        XCTAssertFalse(ClosedLidPmsetController.parseSleepDisabled(output))
    }
}
