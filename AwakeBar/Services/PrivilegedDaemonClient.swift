import Foundation

struct LegacyCleanupReport: Equatable, Sendable {
    var cleanedPaths: [String]
    var skippedPaths: [String]
    var backupDirectory: String
}

enum PrivilegedDaemonClientError: Error, LocalizedError, Equatable {
    case invalidProxy
    case timeout
    case invalidCleanupPayload
    case invalidSleepDisabledResponse

    var errorDescription: String? {
        switch self {
        case .invalidProxy:
            return "Could not connect to the privileged helper service."
        case .timeout:
            return "Privileged helper did not respond in time."
        case .invalidCleanupPayload:
            return "Privileged helper returned an invalid cleanup result."
        case .invalidSleepDisabledResponse:
            return "Privileged helper returned an invalid sleep policy value."
        }
    }
}

private final class SendableFinishBox<Value>: @unchecked Sendable {
    let callback: (Result<Value, Error>) -> Void

    init(callback: @escaping (Result<Value, Error>) -> Void) {
        self.callback = callback
    }
}

protocol PrivilegedDaemonControlling: Sendable {
    func ping() async throws
    func setSleepDisabled(_ disabled: Bool) async throws
    func readSleepDisabled() async throws -> Bool
    func cleanupLegacyArtifacts() async throws -> LegacyCleanupReport
}

final class PrivilegedDaemonClient: PrivilegedDaemonControlling, @unchecked Sendable {
    private static let helperCodeSigningRequirement = CodeSigningRequirementBuilder.requirement(
        for: PrivilegedServiceConstants.helperCodeSigningIdentifier,
        teamID: CodeSigningRequirementBuilder.configuredTeamID()
    )
    private let timeoutNanoseconds: UInt64
    private let pingTimeoutNanoseconds: UInt64
    private let connectionFactory: () -> NSXPCConnection

    init(
        timeoutNanoseconds: UInt64 = 8_000_000_000,
        pingTimeoutNanoseconds: UInt64 = 2_000_000_000,
        connectionFactory: (() -> NSXPCConnection)? = nil
    ) {
        self.timeoutNanoseconds = timeoutNanoseconds
        self.pingTimeoutNanoseconds = pingTimeoutNanoseconds
        self.connectionFactory = connectionFactory ?? Self.makeConnection
    }

    func ping() async throws {
        let _: Void = try await performRequest(timeoutNanoseconds: pingTimeoutNanoseconds) { proxy, finish in
            proxy.ping { isAlive, message in
                if isAlive {
                    finish(.success(()))
                } else {
                    finish(.failure(NSError(domain: "AwakeBarDaemon", code: 1, userInfo: [NSLocalizedDescriptionKey: message ?? "Privileged helper ping failed."])))
                }
            }
        }
    }

    func setSleepDisabled(_ disabled: Bool) async throws {
        let _: Void = try await performRequest { proxy, finish in
            proxy.setSleepDisabled(disabled) { error in
                if let error {
                    finish(.failure(error))
                    return
                }
                finish(.success(()))
            }
        }
    }

    func readSleepDisabled() async throws -> Bool {
        try await performRequest { proxy, finish in
            proxy.readSleepDisabled { value, error in
                if let error {
                    finish(.failure(error))
                    return
                }
                do {
                    finish(.success(try Self.parseSleepDisabledResponse(value)))
                } catch {
                    finish(.failure(error))
                }
            }
        }
    }

    func cleanupLegacyArtifacts() async throws -> LegacyCleanupReport {
        try await performRequest { proxy, finish in
            proxy.cleanupLegacyArtifacts { payload, error in
                if let error {
                    finish(.failure(error))
                    return
                }

                do {
                    let report = try Self.parseCleanupPayload(payload)
                    finish(.success(report))
                } catch {
                    finish(.failure(PrivilegedDaemonClientError.invalidCleanupPayload))
                }
            }
        }
    }

    static func parseCleanupPayload(_ payload: NSDictionary) throws -> LegacyCleanupReport {
        guard
            let cleaned = payload["cleanedPaths"] as? [String],
            let skipped = payload["skippedPaths"] as? [String],
            let backupDirectory = payload["backupDirectory"] as? String
        else {
            throw PrivilegedDaemonClientError.invalidCleanupPayload
        }

        return LegacyCleanupReport(
            cleanedPaths: cleaned,
            skippedPaths: skipped,
            backupDirectory: backupDirectory
        )
    }

    static func parseSleepDisabledResponse(_ value: NSNumber?) throws -> Bool {
        guard let value else {
            throw PrivilegedDaemonClientError.invalidSleepDisabledResponse
        }
        let parsed = value.int64Value
        guard Double(parsed) == value.doubleValue else {
            throw PrivilegedDaemonClientError.invalidSleepDisabledResponse
        }
        guard parsed == 0 || parsed == 1 else {
            throw PrivilegedDaemonClientError.invalidSleepDisabledResponse
        }
        return parsed == 1
    }

    private static func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(
            machServiceName: PrivilegedServiceConstants.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: AwakeBarPrivilegedServiceXPC.self)
        connection.setCodeSigningRequirement(helperCodeSigningRequirement)
        return connection
    }

    private func performRequest<T: Sendable>(
        timeoutNanoseconds requestTimeoutNanoseconds: UInt64? = nil,
        _ call: @escaping (_ proxy: AwakeBarPrivilegedServiceXPC, _ finish: @escaping (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        let connection = connectionFactory()

        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var didFinish = false

            let finish: (Result<T, Error>) -> Void = { result in
                lock.lock()
                defer { lock.unlock() }
                guard !didFinish else {
                    return
                }
                didFinish = true
                connection.invalidationHandler = nil
                connection.interruptionHandler = nil
                connection.invalidate()
                continuation.resume(with: result)
            }

            connection.invalidationHandler = {
                finish(.failure(PrivilegedDaemonClientError.invalidProxy))
            }

            connection.interruptionHandler = {
                finish(.failure(PrivilegedDaemonClientError.invalidProxy))
            }

            connection.activate()

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                finish(.failure(error))
            }) as? AwakeBarPrivilegedServiceXPC else {
                finish(.failure(PrivilegedDaemonClientError.invalidProxy))
                return
            }

            call(proxy, finish)

            let resolvedTimeoutNanoseconds = requestTimeoutNanoseconds ?? timeoutNanoseconds
            let timeoutSeconds = Double(resolvedTimeoutNanoseconds) / 1_000_000_000
            let finishBox = SendableFinishBox(callback: finish)
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeoutSeconds) {
                finishBox.callback(.failure(PrivilegedDaemonClientError.timeout))
            }
        }
    }
}
