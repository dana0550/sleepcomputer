import Foundation

enum ManagedOverrideKey: String, Codable, CaseIterable, Sendable {
    case sleepDisabled
}

struct ClosedLidOverrideSnapshot: Codable, Equatable, Sendable {
    var values: [ManagedOverrideKey: Bool]

    init(values: [ManagedOverrideKey: Bool]) {
        self.values = values
    }

    init(sleepDisabled: Bool) {
        self.values = [.sleepDisabled: sleepDisabled]
    }

    subscript(_ key: ManagedOverrideKey) -> Bool? {
        values[key]
    }
}

struct ClosedLidOverrideSession: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var capturedAt: Date
    var snapshot: ClosedLidOverrideSnapshot
    var pendingRestore: Bool
    var lastRestoreError: String?
    var lastRestoreAttemptAt: Date?

    init(
        schemaVersion: Int = ClosedLidOverrideSession.currentSchemaVersion,
        capturedAt: Date = Date(),
        snapshot: ClosedLidOverrideSnapshot,
        pendingRestore: Bool = false,
        lastRestoreError: String? = nil,
        lastRestoreAttemptAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.capturedAt = capturedAt
        self.snapshot = snapshot
        self.pendingRestore = pendingRestore
        self.lastRestoreError = lastRestoreError
        self.lastRestoreAttemptAt = lastRestoreAttemptAt
    }
}
