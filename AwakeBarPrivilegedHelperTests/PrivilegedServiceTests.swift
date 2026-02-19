import XCTest

@MainActor
final class PrivilegedServiceTests: XCTestCase {
    func testSetSleepDisabledRunsExpectedCommand() {
        let runner = MockRunner()
        let service = PrivilegedService(runner: runner, cleanupManager: LegacyCleanupManager())
        let expectation = expectation(description: "reply")

        service.setSleepDisabled(true) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(runner.calls.count, 1)
        XCTAssertEqual(runner.calls.first?.launchPath, "/usr/bin/pmset")
        XCTAssertEqual(runner.calls.first?.arguments, ["-a", "disablesleep", "1"])
    }

    func testReadSleepDisabledParsesEnabledValue() {
        let runner = MockRunner()
        runner.nextOutput = """
        System-wide power settings:
         SleepDisabled        1
        """
        let service = PrivilegedService(runner: runner, cleanupManager: LegacyCleanupManager())
        let expectation = expectation(description: "reply")

        service.readSleepDisabled { value, error in
            XCTAssertNil(error)
            XCTAssertEqual(value?.boolValue, true)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(runner.calls.count, 1)
    }

    func testReadSleepDisabledReturnsErrorWhenSleepDisabledIsMissing() {
        let runner = MockRunner()
        runner.nextOutput = "System-wide power settings:"
        let service = PrivilegedService(runner: runner, cleanupManager: LegacyCleanupManager())
        let expectation = expectation(description: "reply")

        service.readSleepDisabled { value, error in
            XCTAssertNil(value)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testReadSleepDisabledParsesVariantSeparatorFormat() {
        let runner = MockRunner()
        runner.nextOutput = """
        System-wide power settings:
        SleepDisabled: 0
        """
        let service = PrivilegedService(runner: runner, cleanupManager: LegacyCleanupManager())
        let expectation = expectation(description: "reply")

        service.readSleepDisabled { value, error in
            XCTAssertNil(error)
            XCTAssertEqual(value?.boolValue, false)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testParseSleepDisabledReadsTrailingValue() {
        let enabled = """
        SleepDisabled 1
        """
        let disabled = """
        SleepDisabled\t0
        """

        XCTAssertEqual(try? PrivilegedService.parseSleepDisabled(enabled), true)
        XCTAssertEqual(try? PrivilegedService.parseSleepDisabled(disabled), false)
    }

    func testParseSleepDisabledThrowsForUnknownValue() {
        XCTAssertThrowsError(
            try PrivilegedService.parseSleepDisabled("SleepDisabled maybe")
        )
    }
}

private final class MockRunner: HelperCommandRunning {
    struct Call: Equatable {
        let launchPath: String
        let arguments: [String]
    }

    var nextOutput = ""
    var nextError: Error?
    private(set) var calls: [Call] = []

    func run(_ launchPath: String, arguments: [String]) throws -> String {
        calls.append(Call(launchPath: launchPath, arguments: arguments))
        if let nextError {
            throw nextError
        }
        return nextOutput
    }
}
