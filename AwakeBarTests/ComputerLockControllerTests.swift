import Foundation
import XCTest
@testable import AwakeBar

@MainActor
final class ComputerLockControllerTests: XCTestCase {
    func testLockNowSucceedsOnFirstSuccessfulCommand() async throws {
        let attempts = [
            makeAttempt(executable: "/usr/bin/true")
        ]
        var seenCommands: [String] = []

        let controller = ComputerLockController(
            commandAttempts: attempts,
            commandExecutor: { command in
                seenCommands.append(command.display)
                return .exited(0)
            }
        )

        try await controller.lockNow()
        XCTAssertEqual(seenCommands, [attempts[0].display])
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
                return callIndex == 0 ? .exited(1) : .exited(0)
            }
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
        let controller = ComputerLockController(commandAttempts: attempts)

        let startedAt = Date()
        try await controller.lockNow()
        let elapsed = Date().timeIntervalSince(startedAt)

        XCTAssertLessThan(elapsed, 1.5)
    }

    func testLockNowTreatsLaunchOnlyAsImmediateSuccess() async throws {
        let attempts = [
            makeAttempt(executable: "/usr/bin/true"),
            makeAttempt(executable: "/usr/bin/true", behavior: .launchOnly)
        ]
        var callIndex = 0

        let controller = ComputerLockController(
            commandAttempts: attempts,
            commandExecutor: { command in
                defer { callIndex += 1 }
                if command.behavior == .launchOnly {
                    return .launched
                }
                return .exited(1)
            }
        )

        try await controller.lockNow()
        XCTAssertEqual(callIndex, 2)
    }

    func testLockNowThrowsWhenNoExecutableCommandsAreAvailable() async {
        let attempts = [
            makeAttempt(executable: "/definitely/not/an/executable")
        ]
        let controller = ComputerLockController(commandAttempts: attempts)

        do {
            try await controller.lockNow()
            XCTFail("Expected noAvailableCommand")
        } catch let error as ComputerLockError {
            XCTAssertEqual(error.errorDescription, ComputerLockError.noAvailableCommand.errorDescription)
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
