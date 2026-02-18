import Foundation

enum PrivilegedServiceConstants {
    static let machServiceName = "com.dshakiba.AwakeBar.PrivilegedHelper"
    static let daemonPlistName = "com.dshakiba.AwakeBar.PrivilegedHelper.plist"
    static let helperExecutableName = "AwakeBarPrivilegedHelper"
    static let helperBundleIdentifier = "com.dshakiba.AwakeBar.PrivilegedHelper"
    static let appBundleIdentifier = "com.dshakiba.AwakeBar"

    static let legacyBackupRoot = "/Library/Application Support/AwakeBar/legacy-backup"
    static let legacySudoersPaths = [
        "/private/etc/sudoers.d/awakebar_pmset",
        "/private/etc/sudoers.d/com.awakebar.pmset",
        "/private/etc/sudoers.d/awakebar_pmset_tmp"
    ]
    static let legacyPamPath = "/etc/pam.d/sudo_local"

    static let managedPamComment = "# AwakeBar managed Touch ID fallback"
    static let managedPamLine = "auth       sufficient     pam_tid.so"
}

enum CodeSigningRequirementBuilder {
    static func requirement(for bundleIdentifier: String, teamID: String?) -> String {
        let trimmedTeam = (teamID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTeam.isEmpty {
            return "anchor apple generic and identifier \"\(bundleIdentifier)\""
        }
        return "anchor apple generic and identifier \"\(bundleIdentifier)\" and certificate leaf[subject.OU] = \"\(trimmedTeam)\""
    }

    static func configuredTeamID(from bundle: Bundle = .main) -> String? {
        guard let raw = bundle.object(forInfoDictionaryKey: "AwakeBarTeamID") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
