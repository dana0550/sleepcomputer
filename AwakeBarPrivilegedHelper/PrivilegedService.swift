import Foundation
import Security

enum SleepDisabledParseError: Error, LocalizedError {
    case keyNotFound
    case valueMissing
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .keyNotFound:
            return "SleepDisabled value was not found in pmset output."
        case .valueMissing:
            return "SleepDisabled value was missing in pmset output."
        case .invalidValue(let value):
            return "SleepDisabled value '\(value)' was not recognized."
        }
    }
}

final class PrivilegedService: NSObject, AwakeBarPrivilegedServiceXPC {
    private let runner: HelperCommandRunning
    private let cleanupManager: LegacyCleanupManager

    init(
        runner: HelperCommandRunning = HelperProcessCommandRunner(),
        cleanupManager: LegacyCleanupManager = LegacyCleanupManager()
    ) {
        self.runner = runner
        self.cleanupManager = cleanupManager
    }

    func ping(_ reply: @escaping (Bool, String?) -> Void) {
        reply(true, nil)
    }

    func setSleepDisabled(_ disabled: Bool, reply: @escaping (NSError?) -> Void) {
        let value = disabled ? "1" : "0"
        do {
            _ = try runner.run("/usr/bin/pmset", arguments: ["-a", "disablesleep", value])
            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    func readSleepDisabled(_ reply: @escaping (NSNumber?, NSError?) -> Void) {
        do {
            let output = try runner.run("/usr/bin/pmset", arguments: ["-g"])
            let value = try Self.parseSleepDisabled(output)
            reply(NSNumber(value: value), nil)
        } catch {
            reply(nil, error as NSError)
        }
    }

    func cleanupLegacyArtifacts(_ reply: @escaping (NSDictionary, NSError?) -> Void) {
        do {
            let result = try cleanupManager.runCleanup()
            let payload: NSDictionary = [
                "cleanedPaths": result.cleanedPaths,
                "skippedPaths": result.skippedPaths,
                "backupDirectory": result.backupDirectory
            ]
            reply(payload, nil)
        } catch {
            reply([:] as NSDictionary, error as NSError)
        }
    }

    static func parseSleepDisabled(_ output: String) throws -> Bool {
        let key = "SleepDisabled"
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix(key) else {
                continue
            }
            let suffixStart = trimmed.index(trimmed.startIndex, offsetBy: key.count)
            let suffix = trimmed[suffixStart...]
            if let firstSuffixChar = suffix.first,
               !firstSuffixChar.isWhitespace,
               firstSuffixChar != ":",
               firstSuffixChar != "=" {
                continue
            }

            var remainder = String(suffix)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if remainder.hasPrefix(":") || remainder.hasPrefix("=") {
                remainder.removeFirst()
                remainder = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard let valueToken = remainder.split(whereSeparator: \.isWhitespace).first else {
                throw SleepDisabledParseError.valueMissing
            }

            switch valueToken {
            case "1":
                return true
            case "0":
                return false
            default:
                throw SleepDisabledParseError.invalidValue(String(valueToken))
            }
        }
        throw SleepDisabledParseError.keyNotFound
    }
}

final class PrivilegedServiceListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = PrivilegedService()
    private let callerValidator = XPCConnectionCallerValidator()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard newConnection.processIdentifier > 0 else {
            return false
        }
        guard newConnection.effectiveUserIdentifier != 0 else {
            return false
        }
        guard callerValidator.validate(connection: newConnection) else {
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(with: AwakeBarPrivilegedServiceXPC.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}

private struct XPCConnectionCallerValidator {
    private let requirement: SecRequirement?

    init() {
        let requirementString = CodeSigningRequirementBuilder.requirement(
            for: PrivilegedServiceConstants.appBundleIdentifier,
            teamID: CodeSigningRequirementBuilder.configuredTeamID()
        )

        var parsedRequirement: SecRequirement?
        let status = SecRequirementCreateWithString(
            requirementString as CFString,
            SecCSFlags(),
            &parsedRequirement
        )

        if status != errSecSuccess {
            requirement = nil
            return
        }
        requirement = parsedRequirement
    }

    func validate(connection: NSXPCConnection) -> Bool {
        guard let requirement else {
            // If the requirement cannot be parsed, fail closed.
            return false
        }

        let attributes: [CFString: Any] = [
            kSecGuestAttributePid: NSNumber(value: connection.processIdentifier)
        ]

        var codeRef: SecCode?
        let copyStatus = SecCodeCopyGuestWithAttributes(
            nil,
            attributes as CFDictionary,
            SecCSFlags(),
            &codeRef
        )
        guard copyStatus == errSecSuccess, let codeRef else {
            return false
        }

        let checkStatus = SecCodeCheckValidity(codeRef, SecCSFlags(), requirement)
        return checkStatus == errSecSuccess
    }
}
