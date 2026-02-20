import Foundation

enum ComputerLockError: LocalizedError {
    case noAvailableCommand
    case commandFailed([String])

    var errorDescription: String? {
        switch self {
        case .noAvailableCommand:
            return "No compatible lock command is available on this macOS version."
        case .commandFailed(let commands):
            let joined = commands.joined(separator: ", ")
            return "Lock command failed (\(joined))."
        }
    }
}

@MainActor
final class ComputerLockController: ComputerLockControlling {
    private struct CommandAttempt {
        let executable: String
        let arguments: [String]

        var display: String {
            if arguments.isEmpty {
                return executable
            }
            return "\(executable) \(arguments.joined(separator: " "))"
        }
    }

    private let fileManager: FileManager
    private let processRunner: (String, [String]) async throws -> Int32

    init(
        fileManager: FileManager = .default,
        processRunner: @escaping (String, [String]) async throws -> Int32 = ComputerLockController.runProcess
    ) {
        self.fileManager = fileManager
        self.processRunner = processRunner
    }

    func lockNow() async throws {
        var attempted: [String] = []

        for command in commandAttempts {
            guard fileManager.isExecutableFile(atPath: command.executable) else {
                continue
            }

            attempted.append(command.display)
            do {
                let status = try await processRunner(command.executable, command.arguments)
                if status == 0 {
                    return
                }
            } catch {
                continue
            }
        }

        guard !attempted.isEmpty else {
            throw ComputerLockError.noAvailableCommand
        }
        throw ComputerLockError.commandFailed(attempted)
    }

    private var commandAttempts: [CommandAttempt] {
        [
            CommandAttempt(
                executable: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession",
                arguments: ["-suspend"]
            ),
            CommandAttempt(
                executable: "/System/Library/CoreServices/CGSession",
                arguments: ["-suspend"]
            ),
            CommandAttempt(
                executable: "/usr/bin/CGSession",
                arguments: ["-suspend"]
            ),
            CommandAttempt(
                executable: "/System/Library/CoreServices/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine",
                arguments: []
            )
        ]
    }

    private nonisolated static func runProcess(_ executable: String, _ arguments: [String]) async throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { completedProcess in
                continuation.resume(returning: completedProcess.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}
