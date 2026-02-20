import Foundation

enum ComputerLockError: LocalizedError {
    case noAvailableCommand
    case commandFailed([String])

    var errorDescription: String? {
        switch self {
        case .noAvailableCommand:
            return "No compatible lock command is available on this macOS version."
        case .commandFailed(let commands):
            let joined = commands.joined(separator: "; ")
            return "Lock command failed (\(joined))."
        }
    }
}

@MainActor
final class ComputerLockController: ComputerLockControlling {
    enum CommandBehavior: Equatable {
        case waitForExit(timeoutNanoseconds: UInt64)
        case launchOnly
    }

    struct CommandAttempt: Equatable {
        let executable: String
        let arguments: [String]
        let behavior: CommandBehavior

        var display: String {
            if arguments.isEmpty {
                return executable
            }
            return "\(executable) \(arguments.joined(separator: " "))"
        }
    }

    enum CommandExecutionResult: Equatable {
        case exited(Int32)
        case launched
    }

    typealias CommandExecutor = (CommandAttempt) async throws -> CommandExecutionResult

    private struct ProcessTimeoutError: LocalizedError {
        let command: String

        var errorDescription: String? {
            "Timed out waiting for lock command (\(command))."
        }
    }

    private final class SendableFinishBox<Value>: @unchecked Sendable {
        let callback: (Result<Value, Error>) -> Void

        init(callback: @escaping (Result<Value, Error>) -> Void) {
            self.callback = callback
        }
    }

    private static let defaultWaitTimeoutNanoseconds: UInt64 = 3_000_000_000

    private let fileManager: FileManager
    private let commandAttempts: [CommandAttempt]
    private let commandExecutor: CommandExecutor

    init(
        fileManager: FileManager = .default,
        commandAttempts: [CommandAttempt] = ComputerLockController.defaultCommandAttempts,
        commandExecutor: @escaping CommandExecutor = ComputerLockController.executeCommand
    ) {
        self.fileManager = fileManager
        self.commandAttempts = commandAttempts
        self.commandExecutor = commandExecutor
    }

    func lockNow() async throws {
        var attempted: [String] = []
        var failed: [String] = []

        for command in commandAttempts {
            guard fileManager.isExecutableFile(atPath: command.executable) else {
                continue
            }

            attempted.append(command.display)
            do {
                let result = try await commandExecutor(command)
                switch result {
                case .launched:
                    return
                case .exited(let status):
                    guard status == 0 else {
                        failed.append("\(command.display): exited with status \(status)")
                        continue
                    }
                    return
                }
            } catch {
                failed.append("\(command.display): \(error.localizedDescription)")
                continue
            }
        }

        guard !attempted.isEmpty else {
            throw ComputerLockError.noAvailableCommand
        }
        throw ComputerLockError.commandFailed(failed.isEmpty ? attempted : failed)
    }

    private static let defaultCommandAttempts: [CommandAttempt] = [
        CommandAttempt(
            executable: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession",
            arguments: ["-suspend"],
            behavior: .waitForExit(timeoutNanoseconds: defaultWaitTimeoutNanoseconds)
        ),
        CommandAttempt(
            executable: "/System/Library/CoreServices/CGSession",
            arguments: ["-suspend"],
            behavior: .waitForExit(timeoutNanoseconds: defaultWaitTimeoutNanoseconds)
        ),
        CommandAttempt(
            executable: "/usr/bin/CGSession",
            arguments: ["-suspend"],
            behavior: .waitForExit(timeoutNanoseconds: defaultWaitTimeoutNanoseconds)
        ),
        CommandAttempt(
            executable: "/System/Library/CoreServices/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine",
            arguments: [],
            behavior: .launchOnly
        )
    ]

    private nonisolated static func executeCommand(_ command: CommandAttempt) async throws -> CommandExecutionResult {
        switch command.behavior {
        case .launchOnly:
            try launchProcess(command.executable, command.arguments)
            return .launched
        case .waitForExit(let timeoutNanoseconds):
            let status = try await runProcessAndWait(
                command.executable,
                command.arguments,
                timeoutNanoseconds: timeoutNanoseconds
            )
            return .exited(status)
        }
    }

    private nonisolated static func launchProcess(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
    }

    private nonisolated static func runProcessAndWait(
        _ executable: String,
        _ arguments: [String],
        timeoutNanoseconds: UInt64
    ) async throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let commandDisplay: String
        if arguments.isEmpty {
            commandDisplay = executable
        } else {
            commandDisplay = "\(executable) \(arguments.joined(separator: " "))"
        }

        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var didFinish = false

            let finish: (Result<Int32, Error>) -> Void = { result in
                lock.lock()
                defer { lock.unlock() }
                guard !didFinish else {
                    return
                }
                didFinish = true
                process.terminationHandler = nil
                continuation.resume(with: result)
            }
            let finishBox = SendableFinishBox(callback: finish)

            process.terminationHandler = { completedProcess in
                finishBox.callback(.success(completedProcess.terminationStatus))
            }

            do {
                try process.run()
            } catch {
                finish(.failure(error))
                return
            }

            guard timeoutNanoseconds > 0 else {
                return
            }

            let timeoutSeconds = Double(timeoutNanoseconds) / 1_000_000_000
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeoutSeconds) {
                if process.isRunning {
                    process.terminate()
                }
                finishBox.callback(.failure(ProcessTimeoutError(command: commandDisplay)))
            }
        }
    }
}
