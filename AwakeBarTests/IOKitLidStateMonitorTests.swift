import IOKit.pwr_mgt
import XCTest
@testable import AwakeBar

final class IOKitLidStateMonitorTests: XCTestCase {
    func testDecodeLidClosedStateReturnsTrueForClosedBit() {
        let result = IOKitLidStateMonitor.decodeLidClosedState(
            messageType: IOKitLidStateMonitor.clamshellStateChangeMessage,
            bitmask: UInt(kClamshellStateBit),
            fallbackState: false
        )

        XCTAssertEqual(result, true)
    }

    func testDecodeLidClosedStateReturnsFalseWhenClosedBitMissing() {
        let result = IOKitLidStateMonitor.decodeLidClosedState(
            messageType: IOKitLidStateMonitor.clamshellStateChangeMessage,
            bitmask: 0,
            fallbackState: true
        )

        XCTAssertEqual(result, false)
    }

    func testDecodeLidClosedStateIgnoresNonClamshellMessages() {
        let result = IOKitLidStateMonitor.decodeLidClosedState(
            messageType: natural_t.max,
            bitmask: UInt(kClamshellStateBit),
            fallbackState: true
        )

        XCTAssertNil(result)
    }

    func testDecodeLidClosedStateUsesFallbackForNilBitmask() {
        let openResult = IOKitLidStateMonitor.decodeLidClosedState(
            messageType: IOKitLidStateMonitor.clamshellStateChangeMessage,
            bitmask: nil,
            fallbackState: false
        )
        let closedResult = IOKitLidStateMonitor.decodeLidClosedState(
            messageType: IOKitLidStateMonitor.clamshellStateChangeMessage,
            bitmask: nil,
            fallbackState: true
        )

        XCTAssertEqual(openResult, false)
        XCTAssertEqual(closedResult, true)
    }

    func testDecodeLidClosedStateReturnsNilWhenBitmaskAndFallbackAreNil() {
        let result = IOKitLidStateMonitor.decodeLidClosedState(
            messageType: IOKitLidStateMonitor.clamshellStateChangeMessage,
            bitmask: nil,
            fallbackState: nil
        )

        XCTAssertNil(result)
    }
}
