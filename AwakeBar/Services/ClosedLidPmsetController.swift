import Foundation

enum ClosedLidPmsetError: Error, LocalizedError {
    case invalidPmsetOutput

    var errorDescription: String? {
        switch self {
        case .invalidPmsetOutput:
            return "Could not parse pmset output for SleepDisabled value."
        }
    }
}

@MainActor
final class ClosedLidPmsetController: ClosedLidSleepControlling {
    private let privilegedRunner: PrivilegedCommandRunning
    private let shellRunner: ShellCommandRunning

    init(
        privilegedRunner: PrivilegedCommandRunning = AppleScriptPrivilegedCommandRunner(),
        shellRunner: ShellCommandRunning = ProcessShellCommandRunner()
    ) {
        self.privilegedRunner = privilegedRunner
        self.shellRunner = shellRunner
    }

    func setEnabled(_ enabled: Bool) async throws {
        let value = enabled ? "1" : "0"
        try await privilegedRunner.runPrivileged(command: "/usr/bin/pmset -a disablesleep \(value)")
    }

    func readSleepDisabled() async throws -> Bool {
        let output = try shellRunner.run("/usr/bin/pmset", arguments: ["-g"])
        return Self.parseSleepDisabled(output)
    }

    static func parseSleepDisabled(_ output: String) -> Bool {
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("SleepDisabled") else {
                continue
            }

            let parts = trimmed.split { $0 == " " || $0 == "\t" }
            if let value = parts.last {
                return value == "1"
            }
        }

        return false
    }
}
