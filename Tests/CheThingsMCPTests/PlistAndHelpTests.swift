import Foundation
import XCTest
@testable import CheThingsMCPCore

/// Regression guards for the macOS TCC (Automation) work on che-things-mcp.
///
/// The signed binary must carry `com.apple.security.automation.apple-events`
/// and an embedded Info.plist with `NSAppleEventsUsageDescription`, or under
/// Hardened Runtime macOS may refuse to show the authorization dialog at all
/// (observed for Calendar in che-ical-mcp issue 154; for Apple Events this is
/// inferred from Apple's documentation, not yet observed).
///
/// These tests read the same files `codesign --entitlements` and the linker's
/// `-sectcreate __info_plist` consume, so they go RED before a broken artifact
/// can ship.
final class PlistAndHelpTests: XCTestCase {

    private static let appleEventsKey = "com.apple.security.automation.apple-events"

    private func plist(_ relativePath: String) throws -> [String: Any] {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CheThingsMCPTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(relativePath))
        let parsed = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(parsed as? [String: Any], "\(relativePath) root must be a dictionary")
    }

    // MARK: - Entitlements

    func testEntitlementsParse() throws {
        _ = try plist("Sources/CheThingsMCP/Entitlements.plist")
    }

    func testAppleEventsEntitlementIsPresentAndTrue() throws {
        let entitlements = try plist("Sources/CheThingsMCP/Entitlements.plist")
        let value = try XCTUnwrap(
            entitlements[Self.appleEventsKey] as? Bool,
            "\(Self.appleEventsKey) is missing — do not empty this file")
        XCTAssertTrue(value, "\(Self.appleEventsKey) must be <true/>, not <false/>")
    }

    // MARK: - Info.plist

    func testInfoPlistParses() throws {
        _ = try plist("Sources/CheThingsMCP/Info.plist")
    }

    func testInfoPlistHasAUsageDescriptionThatNamesThings() throws {
        let info = try plist("Sources/CheThingsMCP/Info.plist")
        let text = try XCTUnwrap(info["NSAppleEventsUsageDescription"] as? String,
                                 "NSAppleEventsUsageDescription is required for the Automation dialog")
        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains("Things"), "the dialog text should say which app is being controlled")
    }

    func testInfoPlistBundleIdentifier() throws {
        let info = try plist("Sources/CheThingsMCP/Info.plist")
        XCTAssertEqual(info["CFBundleIdentifier"] as? String, "com.checheng.CheThingsMCP")
    }

    func testInfoPlistVersionMatchesTheAppVersion() throws {
        let info = try plist("Sources/CheThingsMCP/Info.plist")
        XCTAssertEqual(
            info["CFBundleVersion"] as? String, AppVersion.current,
            "Info.plist CFBundleVersion must be bumped together with AppVersion.current")
    }

    func testManifestVersionMatchesTheAppVersion() throws {
        let manifest = try jsonObject("mcpb/manifest.json")
        XCTAssertEqual(manifest["version"] as? String, AppVersion.current,
                       "mcpb/manifest.json version must be bumped together with AppVersion.current")
    }

    private func jsonObject(_ relativePath: String) throws -> [String: Any] {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(relativePath))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - --help

    func testHelpNamesTheAutomationPermission() {
        XCTAssertTrue(AppVersion.helpMessage.contains("Automation"))
    }

    func testHelpDoesNotTellUsersToGrantAccessibility() {
        XCTAssertFalse(
            AppVersion.helpMessage.contains("Accessibility permission"),
            "Apple Events need the Automation permission, not Accessibility (issue 1)")
    }

    func testHelpDocumentsTheDiagnosticFlags() {
        XCTAssertTrue(AppVersion.helpMessage.contains("--setup"))
        XCTAssertTrue(AppVersion.helpMessage.contains("--print-tcc-path"))
    }
}
