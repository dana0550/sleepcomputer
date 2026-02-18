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
protocol AppleScriptCommandRunning {
    func runPrivileged(command: String, prompt: String?) async throws
}

enum PrivilegedSetupError: Error, LocalizedError {
    case unsupportedUserName

    var errorDescription: String? {
        switch self {
        case .unsupportedUserName:
            return "Your macOS account name contains unsupported characters for secure sudo setup."
        }
    }
}

@MainActor
final class AppleScriptPrivilegedCommandRunner: PrivilegedCommandRunning, AppleScriptCommandRunning {
    private let shell: ShellCommandRunning

    init(shell: ShellCommandRunning = ProcessShellCommandRunner()) {
        self.shell = shell
    }

    func runPrivileged(command: String) async throws {
        try await runPrivileged(command: command, prompt: nil)
    }

    func runPrivileged(command: String, prompt: String?) async throws {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script: String
        if let prompt, !prompt.isEmpty {
            let escapedPrompt = prompt
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            script = "do shell script \"\(escaped)\" with administrator privileges with prompt \"\(escapedPrompt)\""
        } else {
            script = "do shell script \"\(escaped)\" with administrator privileges"
        }

        _ = try shell.run("/usr/bin/osascript", arguments: ["-e", script])
    }
}

@MainActor
final class AdaptivePrivilegedCommandRunner: PrivilegedCommandRunning {
    private let shell: ShellCommandRunning
    private let appleScriptRunner: AppleScriptCommandRunning
    private var didAttemptPasswordlessSetup = false

    init(
        shell: ShellCommandRunning = ProcessShellCommandRunner(),
        appleScriptRunner: AppleScriptCommandRunning? = nil
    ) {
        self.shell = shell
        self.appleScriptRunner = appleScriptRunner ?? AppleScriptPrivilegedCommandRunner(shell: shell)
    }

    func runPrivileged(command: String) async throws {
        if try runPasswordlessSudo(command: command) {
            return
        }

        if !didAttemptPasswordlessSetup {
            didAttemptPasswordlessSetup = true
            do {
                try await installPasswordlessPmsetRule()
                if try runPasswordlessSudo(command: command) {
                    return
                }
            } catch {
                if isUserCancelled(error) {
                    throw error
                }
            }
        }

        try await appleScriptRunner.runPrivileged(command: command, prompt: nil)
    }

    private func runPasswordlessSudo(command: String) throws -> Bool {
        do {
            _ = try shell.run(
                "/usr/bin/sudo",
                arguments: ["-n", "/bin/sh", "-c", command]
            )
            return true
        } catch {
            return false
        }
    }

    private func installPasswordlessPmsetRule() async throws {
        let userName = NSUserName()
        guard isSafeUserName(userName) else {
            throw PrivilegedSetupError.unsupportedUserName
        }

        let sudoersDir = "/private/etc/sudoers.d"
        let tempFile = "\(sudoersDir)/.com.awakebar.pmset.tmp"
        let finalFile = "\(sudoersDir)/com.awakebar.pmset"
        let ruleLine = "\(userName) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"

        let setupCommand = """
        /bin/mkdir -p \(sudoersDir) && \
        /usr/bin/printf '%s\\n' '\(ruleLine)' > \(tempFile) && \
        /usr/sbin/chown root:wheel \(tempFile) && \
        /bin/chmod 440 \(tempFile) && \
        /usr/sbin/visudo -cf \(tempFile) && \
        /bin/mv \(tempFile) \(finalFile)
        """

        try await appleScriptRunner.runPrivileged(
            command: setupCommand,
            prompt: "AwakeBar needs one-time admin setup so Closed Lid can run without repeated password prompts."
        )
    }

    private func isSafeUserName(_ userName: String) -> Bool {
        guard !userName.isEmpty else {
            return false
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        return userName.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func isUserCancelled(_ error: Error) -> Bool {
        guard case let CommandExecutionError.processFailed(_, _, output) = error else {
            return false
        }
        return output.localizedCaseInsensitiveContains("user canceled")
            || output.localizedCaseInsensitiveContains("cancelled")
    }
}
