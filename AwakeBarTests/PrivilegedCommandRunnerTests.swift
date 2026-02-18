import XCTest
@testable import AwakeBar

@MainActor
final class PrivilegedCommandRunnerTests: XCTestCase {
    func testOneTimeSetupUsesStrictSudoersAndBestEffortTouchID() async throws {
        let shell = MockShellCommandRunner(
            results: [
                .failure(MockError()),
                .failure(MockError())
            ]
        )
        let apple = MockAppleScriptRunner()
        let runner = AdaptivePrivilegedCommandRunner(shell: shell, appleScriptRunner: apple)

        try await runner.runPrivileged(command: "/usr/bin/pmset -a disablesleep 1")

        XCTAssertEqual(shell.calls.count, 2)
        XCTAssertEqual(apple.calls.count, 2)

        let setupCall = try XCTUnwrap(apple.calls.first)
        XCTAssertNotNil(setupCall.prompt)
        XCTAssertTrue(setupCall.command.contains("|| exit 1"))
        XCTAssertTrue(setupCall.command.contains("pam_tid.so"))
        XCTAssertTrue(setupCall.command.contains(">/dev/null 2>&1 || true"))
    }

    func testSetupFailureStillFallsBackToCurrentActionPrompt() async throws {
        let shell = MockShellCommandRunner(
            results: [
                .failure(MockError())
            ]
        )
        let apple = MockAppleScriptRunner(failures: [0: MockError()])
        let runner = AdaptivePrivilegedCommandRunner(shell: shell, appleScriptRunner: apple)

        try await runner.runPrivileged(command: "/usr/bin/pmset -a disablesleep 0")

        XCTAssertEqual(shell.calls.count, 1)
        XCTAssertEqual(apple.calls.count, 2)
        XCTAssertNotNil(apple.calls[0].prompt)
        XCTAssertNil(apple.calls[1].prompt)
        XCTAssertEqual(apple.calls[1].command, "/usr/bin/pmset -a disablesleep 0")
    }
}

private final class MockShellCommandRunner: ShellCommandRunning {
    private(set) var calls: [(launchPath: String, arguments: [String])] = []
    private var results: [Result<String, Error>]

    init(results: [Result<String, Error>] = []) {
        self.results = results
    }

    @discardableResult
    func run(_ launchPath: String, arguments: [String]) throws -> String {
        calls.append((launchPath, arguments))
        if !results.isEmpty {
            return try results.removeFirst().get()
        }
        return ""
    }
}

private final class MockAppleScriptRunner: AppleScriptCommandRunning {
    struct Call {
        let command: String
        let prompt: String?
    }

    private(set) var calls: [Call] = []
    private let failures: [Int: Error]

    init(failures: [Int: Error] = [:]) {
        self.failures = failures
    }

    func runPrivileged(command: String, prompt: String?) async throws {
        let index = calls.count
        calls.append(Call(command: command, prompt: prompt))
        if let failure = failures[index] {
            throw failure
        }
    }
}

private struct MockError: Error {}
