import Foundation

enum HelperCommandError: Error, LocalizedError {
    case processFailed(command: String, code: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case let .processFailed(command, code, output):
            return "Command failed (\(code)): \(command). \(output)"
        }
    }
}

protocol HelperCommandRunning {
    @discardableResult
    func run(_ launchPath: String, arguments: [String]) throws -> String
}

struct HelperProcessCommandRunner: HelperCommandRunning {
    @discardableResult
    func run(_ launchPath: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let cmd = ([launchPath] + arguments).joined(separator: " ")
            throw HelperCommandError.processFailed(
                command: cmd,
                code: process.terminationStatus,
                output: stderr.isEmpty ? stdout : stderr
            )
        }

        return stdout
    }
}
