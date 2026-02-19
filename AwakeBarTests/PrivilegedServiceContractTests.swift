import Foundation
import XCTest
@testable import AwakeBar

final class PrivilegedServiceContractTests: XCTestCase {
    func testHelperCodeSigningIdentifierTracksExecutableName() {
        XCTAssertEqual(
            PrivilegedServiceConstants.helperCodeSigningIdentifier,
            PrivilegedServiceConstants.helperExecutableName
        )
    }

    func testLaunchDaemonPlistMatchesSharedConstants() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistURL = root
            .appendingPathComponent("AwakeBar")
            .appendingPathComponent("LaunchDaemons")
            .appendingPathComponent(PrivilegedServiceConstants.daemonPlistName)

        XCTAssertTrue(FileManager.default.fileExists(atPath: plistURL.path))

        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any]
        )

        XCTAssertEqual(
            plist["Label"] as? String,
            PrivilegedServiceConstants.machServiceName
        )

        XCTAssertEqual(
            plist["BundleProgram"] as? String,
            "Contents/Library/HelperTools/\(PrivilegedServiceConstants.helperExecutableName)"
        )

        let machServices = try XCTUnwrap(plist["MachServices"] as? [String: Any])
        XCTAssertEqual(machServices[PrivilegedServiceConstants.machServiceName] as? Bool, true)
    }
}
