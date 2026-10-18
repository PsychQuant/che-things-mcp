import ApplicationServices
import Foundation
import XCTest
@testable import CheThingsMCPCore

/// Apple Events (Automation) authorization: classification of the OSStatus
/// returned by `AEDeterminePermissionToAutomateTarget`, and the report printed
/// by `--print-tcc-path`.
///
/// None of these tests can show a TCC dialog: the probe is only ever called
/// with `askUserIfNeeded: false`, and only against a bundle id that is not
/// running.
final class AutomationAuthorizationTests: XCTestCase {

    // MARK: - Classification

    func testClassifyNoErrIsAuthorized() {
        XCTAssertEqual(AutomationStatus.classify(0), .authorized)
    }

    func testClassifyNotPermittedIsDenied() {
        XCTAssertEqual(AutomationStatus.classify(-1743), .denied)
    }

    func testClassifyWouldRequireUserConsentIsNotDetermined() {
        XCTAssertEqual(AutomationStatus.classify(-1744), .notDetermined)
    }

    func testClassifyProcNotFoundIsTargetNotRunning() {
        XCTAssertEqual(AutomationStatus.classify(Int(procNotFound)), .targetNotRunning)
    }

    func testClassifyUnknownStatusIsKeptVerbatim() {
        XCTAssertEqual(AutomationStatus.classify(-9999), .other(-9999))
    }

    /// Pins the literal numbers in the doc comments to what the SDK header
    /// actually defines, so a header change goes RED instead of silently
    /// misclassifying.
    func testSDKConstantsMatchTheDocumentedValues() {
        XCTAssertEqual(Int(errAEEventNotPermitted), -1743)
        XCTAssertEqual(Int(errAEEventWouldRequireUserConsent), -1744)
    }

    // MARK: - Summaries (shown to users)

    func testEverySummaryIsNonEmpty() {
        let all: [AutomationStatus] = [.authorized, .denied, .notDetermined, .targetNotRunning, .other(-1)]
        for status in all {
            XCTAssertFalse(status.summary.isEmpty, "\(status) must have a summary")
        }
    }

    func testTargetNotRunningSummaryDoesNotBlameAuthorization() {
        // procNotFound means the app is not open, which is not a permission problem.
        XCTAssertTrue(AutomationStatus.targetNotRunning.summary.lowercased().contains("not running"))
        XCTAssertFalse(AutomationStatus.targetNotRunning.summary.lowercased().contains("denied"))
    }

    func testOtherSummaryPrintsTheRawNumber() {
        XCTAssertTrue(AutomationStatus.other(-1712).summary.contains("-1712"))
    }

    // MARK: - Probe (never prompts)

    func testProbeAgainstAppThatIsNotRunningNeverReportsAuthorized() {
        let status = AutomationProbe.status(bundleID: "com.example.che-things-mcp.not-running", askUserIfNeeded: false)
        XCTAssertNotEqual(status, .authorized)
    }

    func testThingsBundleIdentifier() {
        XCTAssertEqual(AutomationProbe.thingsBundleID, "com.culturedcode.ThingsMac")
    }

    // MARK: - Report for --print-tcc-path

    func testReportContainsEverythingNeededToDiagnose() {
        let report = AutomationReport.format(
            binaryPath: "/Users/someone/bin/CheThingsMCP",
            bundleIdentifier: "com.checheng.CheThingsMCP",
            osVersion: "26.5.1",
            thingsRunning: true,
            status: .denied)
        XCTAssertTrue(report.contains("/Users/someone/bin/CheThingsMCP"))
        XCTAssertTrue(report.contains("com.checheng.CheThingsMCP"))
        XCTAssertTrue(report.contains("26.5.1"))
        XCTAssertTrue(report.contains("com.culturedcode.ThingsMac"))
        XCTAssertTrue(report.lowercased().contains("denied"))
    }

    func testReportWarnsThatTheResultDependsOnTheCallingContext() {
        let report = AutomationReport.format(
            binaryPath: "/x", bundleIdentifier: "id", osVersion: "1", thingsRunning: true, status: .authorized)
        XCTAssertTrue(
            report.lowercased().contains("context"),
            "the status is read in the caller's context (Terminal vs the MCP host); the report must say so")
    }

    func testReportSaysWhenThingsIsNotRunning() {
        let report = AutomationReport.format(
            binaryPath: "/x", bundleIdentifier: "id", osVersion: "1", thingsRunning: false, status: .targetNotRunning)
        XCTAssertTrue(report.lowercased().contains("not running"))
    }
}
