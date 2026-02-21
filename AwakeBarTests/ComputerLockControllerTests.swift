import Foundation
import XCTest
@testable import AwakeBar

@MainActor
final class ComputerLockControllerTests: XCTestCase {
    func testLockCapabilityReportsUnsupportedWhenNoVerifiableCommandIsAvailable() {
        let controller = ComputerLockController(
            commandAttempts: [makeAttempt(executable: "/definitely/not/an/executable")]
        )

        switch controller.lockCapability {
        case .supported:
            XCTFail("Expected unsupported capability")
        case .unsupported(let reason):
            XCTAssertFalse(reason.isEmpty)
        }
    }

    func testLockCapabilityReportsUnsupportedWhenLockStateReaderIsUnavailable() {
        let controller = ComputerLockController(
            commandAttempts: [makeAttempt(executable: "/usr/bin/true")],
            lockStateReader: { nil }
        )

        switch controller.lockCapability {
        case .supported:
            XCTFail("Expected unsupported capability")
        case .unsupported(let reason):
            XCTAssertTrue(reason.contains("verification"))
        }
    }

    func testLockNowThrowsUnsupportedWhenLockStateReaderIsUnavailable() async {
        let attempts = [
            makeAttempt(executable: "/usr/bin/true")
        ]
        var didExecuteCommand = false

        let controller = ComputerLockController(
            commandAttempts: attempts,
            commandExecutor: { _ in
                didExecuteCommand = true
                return 0
            },
            lockStateReader: { nil }
        )

        do {
            try await controller.lockNow()
            XCTFail("Expected unsupportedCapability")
        } catch let error as ComputerLockError {
            switch error {
            case .unsupportedCapability(let reason):
                XCTAssertTrue(reason.contains("verification"))
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(didExecuteCommand)
    }

    func testLockNowSucceedsWhenCommandExitsZeroAndLockStateVerifies() async throws {
        let attempts = [
            makeAttempt(executable: "/usr/bin/true")
        ]
        var seenCommands: [String] = []
        var lockChecks = 0

        let controller = ComputerLockController(
            commandAttempts: attempts,
            commandExecutor: { command in
                seenCommands.append(command.display)
                return 0
            },
            lockStateReader: {
                lockChecks += 1
                return lockChecks >= 2
            },
            lockVerificationTimeoutNanoseconds: 100_000_000,
            lockVerificationPollNanoseconds: 10_000_000
        )

        try await controller.lockNow()
        XCTAssertEqual(seenCommands, [attempts[0].display])
        XCTAssertGreaterThanOrEqual(lockChecks, 2)
    }

    func testLockNowFallsBackAfterNonZeroExit() async throws {
        let attempts = [
            makeAttempt(executable: "/usr/bin/true"),
            makeAttempt(executable: "/usr/bin/true")
        ]
        var callIndex = 0

        let controller = ComputerLockController(
            commandAttempts: attempts,
            commandExecutor: { _ in
                defer { callIndex += 1 }
                return callIndex == 0 ? 1 : 0
            },
            lockStateReader: { true }
        )

        try await controller.lockNow()
        XCTAssertEqual(callIndex, 2)
    }

    func testLockNowFallsBackWhenFirstCommandDoesNotVerifyLockState() async throws {
        let attempts = [
            makeAttempt(executable: "/usr/bin/true"),
            makeAttempt(executable: "/usr/bin/true")
        ]
        var callIndex = 0

        let controller = ComputerLockController(
            commandAttempts: attempts,
            commandExecutor: { _ in
                callIndex += 1
                return 0
            },
            lockStateReader: {
                callIndex >= 2
            },
            lockVerificationTimeoutNanoseconds: 20_000_000,
            lockVerificationPollNanoseconds: 5_000_000
        )

        try await controller.lockNow()
        XCTAssertEqual(callIndex, 2)
    }

    func testLockNowProgressesAfterTimeout() async throws {
        let attempts = [
            makeAttempt(
                executable: "/bin/sleep",
                arguments: ["1"],
                behavior: .waitForExit(timeoutNanoseconds: 50_000_000)
            ),
            makeAttempt(
                executable: "/usr/bin/true",
                behavior: .waitForExit(timeoutNanoseconds: 500_000_000)
            )
        ]
        let controller = ComputerLockController(
            commandAttempts: attempts,
            lockStateReader: { true }
        )

        let startedAt = Date()
        try await controller.lockNow()
        let elapsed = Date().timeIntervalSince(startedAt)

        XCTAssertLessThan(elapsed, 1.5)
    }

    func testLockNowFailsWhenSuccessfulCommandDoesNotVerifyLockState() async {
        let attempts = [
            makeAttempt(executable: "/usr/bin/true")
        ]
        let controller = ComputerLockController(
            commandAttempts: attempts,
            commandExecutor: { _ in 0 },
            lockStateReader: { false },
            lockVerificationTimeoutNanoseconds: 20_000_000,
            lockVerificationPollNanoseconds: 5_000_000
        )

        do {
            try await controller.lockNow()
            XCTFail("Expected commandFailed")
        } catch let error as ComputerLockError {
            switch error {
            case .commandFailed(let failures):
                XCTAssertEqual(failures.count, 1)
                XCTAssertTrue(failures[0].contains("did not verify locked session state"))
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeAttempt(
        executable: String,
        arguments: [String] = [],
        behavior: ComputerLockController.CommandBehavior = .waitForExit(timeoutNanoseconds: 500_000_000)
    ) -> ComputerLockController.CommandAttempt {
        ComputerLockController.CommandAttempt(
            executable: executable,
            arguments: arguments,
            behavior: behavior
        )
    }
}
