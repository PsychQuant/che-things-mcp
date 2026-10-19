import Foundation
import XCTest
@testable import CheThingsMCPCore

/// Equivalence checks against a running Things 3. Skipped unless `CHE_THINGS_LIVE=1`,
/// because they read the user's real data and need the Automation permission.
///
/// Each test runs the production script and a reference script — the per-item version
/// these tools used before issue 5 — and requires byte-identical output. The reference is
/// the old behavior, so a bulk rewrite that changes order, separators or the handling of
/// missing values fails here.
final class LiveThingsQueryTests: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CHE_THINGS_LIVE"] == "1",
                          "set CHE_THINGS_LIVE=1 with Things 3 running to run live checks")
    }

    private static let perItemTags = """
    tell application "Things3"
        set output to ""
        repeat with t in tags
            set tagId to id of t
            set tagName to name of t
            set parentName to ""
            try
                set parentName to name of parent tag of t
            end try
            set output to output & tagId & \(AppleScriptText.fieldSeparatorExpression) & tagName & \(AppleScriptText.fieldSeparatorExpression) & parentName & \(AppleScriptText.recordSeparatorExpression)
        end repeat
        return output
    end tell
    """

    private static let perItemAreas = """
    tell application "Things3"
        set output to ""
        repeat with a in areas
            set areaId to id of a
            set areaName to name of a
            set areaTags to tag names of a
            set output to output & areaId & \(AppleScriptText.fieldSeparatorExpression) & areaName & \(AppleScriptText.fieldSeparatorExpression) & areaTags & \(AppleScriptText.recordSeparatorExpression)
        end repeat
        return output
    end tell
    """

    func testTagsScriptMatchesThePerItemReference() async throws {
        let reference = try await AppleScriptRunner.run(Self.perItemTags)
        let production = try await AppleScriptRunner.run(ThingsManager.tagsScript)
        XCTAssertEqual(production, reference)
        // The bulk `name of parent tag of tags` read is the risky part; without a tag that has a
        // parent, the check above passes without exercising it.
        let parentFields = reference.components(separatedBy: AppleScriptText.recordSeparator).compactMap { row -> String? in
            let fields = row.components(separatedBy: AppleScriptText.fieldSeparator)
            return fields.count == 3 ? fields[2] : nil
        }
        XCTAssertTrue(parentFields.contains { !$0.isEmpty },
                      "no tag with a parent in Things 3 — add one (a tag nested under another) so the parent column is exercised")
    }

    func testAreasScriptMatchesThePerItemReference() async throws {
        let reference = try await AppleScriptRunner.run(Self.perItemAreas)
        let production = try await AppleScriptRunner.run(ThingsManager.areasScript)
        XCTAssertFalse(reference.isEmpty, "no areas to compare")
        XCTAssertEqual(production, reference)
    }
}
