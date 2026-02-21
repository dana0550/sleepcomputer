import Foundation
import CoreGraphics

enum ComputerLockError: LocalizedError {
    case unsupportedCapability(String)
    case commandFailed([String])

    var errorDescription: String? {
        switch self {
        case .unsupportedCapability(let reason):
            return reason
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

    typealias CommandExecutor = (CommandAttempt) async throws -> Int32
    typealias LockStateReader = () -> Bool?

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
    private static let defaultVerificationTimeoutNanoseconds: UInt64 = 1_500_000_000
    private static let defaultVerificationPollNanoseconds: UInt64 = 100_000_000
    private static let defaultUnsupportedReason = "No verifiable lock command is available on this macOS version."

    private let fileManager: FileManager
    private let commandAttempts: [CommandAttempt]
    private let commandExecutor: CommandExecutor
    private let lockStateReader: LockStateReader
    private let lockVerificationTimeoutNanoseconds: UInt64
    private let lockVerificationPollNanoseconds: UInt64

    init(
        fileManager: FileManager = .default,
        commandAttempts: [CommandAttempt] = ComputerLockController.defaultCommandAttempts,
        commandExecutor: @escaping CommandExecutor = ComputerLockController.executeCommand,
        lockStateReader: @escaping LockStateReader = ComputerLockController.readSessionLockedState,
        lockVerificationTimeoutNanoseconds: UInt64 = ComputerLockController.defaultVerificationTimeoutNanoseconds,
        lockVerificationPollNanoseconds: UInt64 = ComputerLockController.defaultVerificationPollNanoseconds
    ) {
        self.fileManager = fileManager
        self.commandAttempts = commandAttempts
        self.commandExecutor = commandExecutor
        self.lockStateReader = lockStateReader
        self.lockVerificationTimeoutNanoseconds = lockVerificationTimeoutNanoseconds
        self.lockVerificationPollNanoseconds = lockVerificationPollNanoseconds
    }

    var lockCapability: ComputerLockCapability {
        let hasVerifiableCommand = commandAttempts.contains { attempt in
            fileManager.isExecutableFile(atPath: attempt.executable)
        }
        if hasVerifiableCommand {
            return .supported
        }
        return .unsupported(reason: Self.defaultUnsupportedReason)
    }

    func lockNow() async throws {
        guard case .supported = lockCapability else {
            throw ComputerLockError.unsupportedCapability(
                lockCapability.unsupportedReason ?? Self.defaultUnsupportedReason
            )
        }

        var attempted: [String] = []
        var failed: [String] = []

        for command in commandAttempts {
            guard fileManager.isExecutableFile(atPath: command.executable) else {
                continue
            }

            attempted.append(command.display)
            do {
                let status = try await commandExecutor(command)
                guard status == 0 else {
                    failed.append("\(command.display): exited with status \(status)")
                    continue
                }
                guard await waitForSessionLocked() else {
                    failed.append("\(command.display): did not verify locked session state")
                    continue
                }
                return
            } catch {
                failed.append("\(command.display): \(error.localizedDescription)")
                continue
            }
        }

        guard !attempted.isEmpty else {
            throw ComputerLockError.unsupportedCapability(
                lockCapability.unsupportedReason ?? Self.defaultUnsupportedReason
            )
        }
        throw ComputerLockError.commandFailed(failed.isEmpty ? attempted : failed)
    }

    private func waitForSessionLocked() async -> Bool {
        if lockStateReader() == true {
            return true
        }
        guard lockVerificationTimeoutNanoseconds > 0 else {
            return false
        }

        let deadline = DispatchTime.now().uptimeNanoseconds &+ lockVerificationTimeoutNanoseconds
        let pollInterval = max(lockVerificationPollNanoseconds, 1_000_000)

        while DispatchTime.now().uptimeNanoseconds < deadline {
            let now = DispatchTime.now().uptimeNanoseconds
            let remaining = deadline > now ? deadline - now : 0
            let sleepNanoseconds = min(pollInterval, remaining)
            if sleepNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: sleepNanoseconds)
            }
            if lockStateReader() == true {
                return true
            }
        }

        return false
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
        )
    ]

    private nonisolated static func executeCommand(_ command: CommandAttempt) async throws -> Int32 {
        switch command.behavior {
        case .waitForExit(let timeoutNanoseconds):
            return try await runProcessAndWait(
                command.executable,
                command.arguments,
                timeoutNanoseconds: timeoutNanoseconds
            )
        }
    }

    private nonisolated static func readSessionLockedState() -> Bool? {
        guard let session = CGSessionCopyCurrentDictionary() else {
            return nil
        }
        let dictionary = session as NSDictionary
        guard let locked = dictionary["CGSSessionScreenIsLocked"] as? NSNumber else {
            return nil
        }
        return locked.boolValue
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
                guard process.isRunning else {
                    return
                }
                process.terminate()
                finishBox.callback(.failure(ProcessTimeoutError(command: commandDisplay)))
            }
        }
    }
}
