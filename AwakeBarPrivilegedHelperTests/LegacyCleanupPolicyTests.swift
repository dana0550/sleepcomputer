import XCTest

final class LegacyCleanupPolicyTests: XCTestCase {
    private var tempDirectories: [URL] = []

    override func tearDown() {
        let fileManager = FileManager.default
        for directory in tempDirectories {
            try? fileManager.removeItem(at: directory)
        }
        tempDirectories.removeAll()
        super.tearDown()
    }

    func testCleanupBacksUpAndRemovesOwnedSudoersAndManagedPam() throws {
        let fixture = try makeFixture()
        for path in fixture.policy.sudoersPaths {
            try writeFile(path: path, content: "awakebar")
        }
        try writeFile(path: fixture.policy.pamPath, content: PrivilegedServiceConstants.managedPamLine + "\n")

        let manager = LegacyCleanupManager(
            fileManager: .default,
            policy: fixture.policy,
            nowProvider: { fixture.fixedDate }
        )
        let result = try manager.runCleanup()

        XCTAssertEqual(Set(result.cleanedPaths), Set(fixture.policy.sudoersPaths + [fixture.policy.pamPath]))
        XCTAssertTrue(result.skippedPaths.isEmpty)

        for path in fixture.policy.sudoersPaths + [fixture.policy.pamPath] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: path), "Expected removed path: \(path)")
            let backupPath = URL(fileURLWithPath: result.backupDirectory)
                .appendingPathComponent(relativePath(for: path))
                .path
            XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath), "Missing backup: \(backupPath)")
        }
    }

    func testCleanupSkipsUnmanagedPamButStillBacksItUp() throws {
        let fixture = try makeFixture()
        try writeFile(path: fixture.policy.pamPath, content: "auth required pam_unix.so\n")

        let manager = LegacyCleanupManager(
            fileManager: .default,
            policy: fixture.policy,
            nowProvider: { fixture.fixedDate }
        )
        let result = try manager.runCleanup()

        XCTAssertTrue(result.cleanedPaths.isEmpty)
        XCTAssertEqual(result.skippedPaths.count, 1)
        XCTAssertTrue(result.skippedPaths.first?.contains(fixture.policy.pamPath) == true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.policy.pamPath))

        let backupPath = URL(fileURLWithPath: result.backupDirectory)
            .appendingPathComponent(relativePath(for: fixture.policy.pamPath))
            .path
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath))
    }

    func testManagedPamContentMatcherAcceptsKnownAwakeBarPatterns() {
        XCTAssertTrue(LegacyCleanupManager.isAwakeBarManagedPamContent(PrivilegedServiceConstants.managedPamLine))
        XCTAssertTrue(LegacyCleanupManager.isAwakeBarManagedPamContent("""
        \(PrivilegedServiceConstants.managedPamComment)
        \(PrivilegedServiceConstants.managedPamLine)
        """))
        XCTAssertFalse(LegacyCleanupManager.isAwakeBarManagedPamContent("auth required pam_unix.so"))
    }

    private func makeFixture() throws -> (root: URL, policy: LegacyCleanupPolicy, fixedDate: Date) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("awakebar-legacy-cleanup-\(UUID().uuidString)", isDirectory: true)
        tempDirectories.append(root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let policy = LegacyCleanupPolicy(
            sudoersPaths: [
                root.appendingPathComponent("private/etc/sudoers.d/awakebar_pmset").path,
                root.appendingPathComponent("private/etc/sudoers.d/com.awakebar.pmset").path,
                root.appendingPathComponent("private/etc/sudoers.d/awakebar_pmset_tmp").path
            ],
            pamPath: root.appendingPathComponent("etc/pam.d/sudo_local").path,
            backupRootPath: root.appendingPathComponent("backup-root").path
        )

        return (root, policy, Date(timeIntervalSince1970: 1_738_800_000))
    }

    private func writeFile(path: String, content: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func relativePath(for absolutePath: String) -> String {
        absolutePath.hasPrefix("/") ? String(absolutePath.dropFirst()) : absolutePath
    }
}
