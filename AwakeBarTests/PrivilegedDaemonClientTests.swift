import XCTest
@testable import AwakeBar

final class PrivilegedDaemonClientTests: XCTestCase {
    func testParseCleanupPayloadReturnsReportForValidPayload() throws {
        let payload: NSDictionary = [
            "cleanedPaths": ["/a", "/b"],
            "skippedPaths": ["/c"],
            "backupDirectory": "/backup"
        ]

        let report = try PrivilegedDaemonClient.parseCleanupPayload(payload)
        XCTAssertEqual(report.cleanedPaths, ["/a", "/b"])
        XCTAssertEqual(report.skippedPaths, ["/c"])
        XCTAssertEqual(report.backupDirectory, "/backup")
    }

    func testParseCleanupPayloadThrowsForInvalidPayload() {
        let payload: NSDictionary = [
            "cleanedPaths": ["/a"],
            "skippedPaths": ["/c"]
        ]

        XCTAssertThrowsError(try PrivilegedDaemonClient.parseCleanupPayload(payload)) { error in
            XCTAssertEqual(error as? PrivilegedDaemonClientError, .invalidCleanupPayload)
        }
    }

    func testCodeSigningRequirementFallsBackToIdentifierWithoutTeamID() {
        let requirement = CodeSigningRequirementBuilder.requirement(
            for: "com.dshakiba.AwakeBar",
            teamID: nil
        )

        XCTAssertEqual(requirement, "identifier \"com.dshakiba.AwakeBar\"")
    }

    func testCodeSigningRequirementIncludesAnchorAndTeamIDWhenPresent() {
        let requirement = CodeSigningRequirementBuilder.requirement(
            for: "com.dshakiba.AwakeBar",
            teamID: "ABCDE12345"
        )

        XCTAssertEqual(
            requirement,
            "anchor apple generic and identifier \"com.dshakiba.AwakeBar\" and certificate leaf[subject.OU] = \"ABCDE12345\""
        )
    }

    func testHelperCodeSigningIdentifierMatchesSignedToolIdentifier() {
        XCTAssertEqual(
            PrivilegedServiceConstants.helperCodeSigningIdentifier,
            "AwakeBarPrivilegedHelper"
        )
    }
}
