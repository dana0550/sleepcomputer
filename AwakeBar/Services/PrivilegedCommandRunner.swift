import Foundation

enum CommandExecutionError: Error, LocalizedError {
    case processFailed(command: String, code: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case let .processFailed(command, code, output):
            return "Command failed (\(code)): \(command). \(output)"
        }
    }
}

protocol ShellCommandRunning {
    @discardableResult
    func run(_ launchPath: String, arguments: [String]) throws -> String
}

struct ProcessShellCommandRunner: ShellCommandRunning {
    @discardableResult
    func run(_ launchPath: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let commandString = ([launchPath] + arguments).joined(separator: " ")
            throw CommandExecutionError.processFailed(
                command: commandString,
                code: process.terminationStatus,
                output: stderr.isEmpty ? stdout : stderr
            )
        }

        return stdout
    }
}

@MainActor
protocol PrivilegedCommandRunning {
    func runPrivileged(command: String) async throws
}

@MainActor
final class AppleScriptPrivilegedCommandRunner: PrivilegedCommandRunning {
    private let shell: ShellCommandRunning

    init(shell: ShellCommandRunning = ProcessShellCommandRunner()) {
        self.shell = shell
    }

    func runPrivileged(command: String) async throws {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "do shell script \"\(escaped)\" with administrator privileges"
        _ = try shell.run("/usr/bin/osascript", arguments: ["-e", script])
    }
}
