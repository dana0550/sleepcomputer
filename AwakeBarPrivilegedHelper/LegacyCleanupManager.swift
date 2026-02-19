import Foundation

struct LegacyCleanupResult {
    var cleanedPaths: [String]
    var skippedPaths: [String]
    var backupDirectory: String
}

struct LegacyCleanupPolicy {
    var sudoersPaths: [String]
    var pamPath: String
    var backupRootPath: String

    static let production = LegacyCleanupPolicy(
        sudoersPaths: PrivilegedServiceConstants.legacySudoersPaths,
        pamPath: PrivilegedServiceConstants.legacyPamPath,
        backupRootPath: PrivilegedServiceConstants.legacyBackupRoot
    )
}

final class LegacyCleanupManager {
    private let fileManager: FileManager
    private let policy: LegacyCleanupPolicy
    private let nowProvider: () -> Date

    init(
        fileManager: FileManager = .default,
        policy: LegacyCleanupPolicy = .production,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.policy = policy
        self.nowProvider = nowProvider
    }

    func runCleanup() throws -> LegacyCleanupResult {
        let backupDirectory = try createBackupDirectory()

        var cleaned: [String] = []
        var skipped: [String] = []

        for path in policy.sudoersPaths {
            if fileManager.fileExists(atPath: path) {
                try backup(path: path, into: backupDirectory)
                try fileManager.removeItem(atPath: path)
                cleaned.append(path)
            }
        }

        let pamFile = policy.pamPath
        if fileManager.fileExists(atPath: pamFile) {
            try backup(path: pamFile, into: backupDirectory)
            let content = (try? String(contentsOfFile: pamFile, encoding: .utf8)) ?? ""
            if Self.isAwakeBarManagedPamContent(content) {
                try fileManager.removeItem(atPath: pamFile)
                cleaned.append(pamFile)
            } else {
                skipped.append("\(pamFile) (skipped: unmanaged content)")
            }
        }

        return LegacyCleanupResult(
            cleanedPaths: cleaned,
            skippedPaths: skipped,
            backupDirectory: backupDirectory.path
        )
    }

    private func createBackupDirectory() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let stamp = formatter.string(from: nowProvider())

        let root = URL(fileURLWithPath: policy.backupRootPath, isDirectory: true)
        let dir = root.appendingPathComponent(stamp, isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func backup(path: String, into backupDirectory: URL) throws {
        let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let destination = backupDirectory.appendingPathComponent(relative)
        let parent = destination.deletingLastPathComponent()

        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(atPath: path, toPath: destination.path)
    }

    static func isAwakeBarManagedPamContent(_ content: String) -> Bool {
        let legacyComment = "# sudo_local: local config file which survives system update and is included for sudo"

        let lines = content
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines == [PrivilegedServiceConstants.managedPamLine] {
            return true
        }
        if lines == [PrivilegedServiceConstants.managedPamComment, PrivilegedServiceConstants.managedPamLine] {
            return true
        }
        if lines == [legacyComment, PrivilegedServiceConstants.managedPamLine] {
            return true
        }
        return false
    }
}
