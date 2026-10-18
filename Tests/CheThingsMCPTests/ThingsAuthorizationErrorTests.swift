import Foundation
import XCTest
@testable import CheThingsMCPCore

/// What the user sees when macOS refuses to let this server send Apple events
/// to Things 3. Before this, the user got the raw
/// "AppleScript error: Not authorized to send Apple events to Things3." with no
/// hint where to fix it (issue 1), and `--help` pointed at the wrong permission.
final class ThingsAuthorizationErrorTests: XCTestCase {

    private let binary = "/Users/someone/bin/CheThingsMCP"

    // MARK: - Mapping

    func testErrorNumberMinus1743IsAnAuthorizationError() {
        let error = ThingsError.authorizationError(errorNumber: -1743, message: "anything", binaryPath: binary)
        XCTAssertEqual(error, .automationNotAuthorized(binaryPath: binary))
    }

    func testTheRawMessageAloneIsEnoughWhenThereIsNoNumber() {
        let error = ThingsError.authorizationError(
            errorNumber: nil,
            message: "Not authorized to send Apple events to Things3.",
            binaryPath: binary)
        XCTAssertEqual(error, .automationNotAuthorized(binaryPath: binary))
    }

    func testAnUnrelatedErrorIsNotMapped() {
        XCTAssertNil(ThingsError.authorizationError(errorNumber: -1728, message: "Can't get list \"Inbox\".", binaryPath: binary))
        XCTAssertNil(ThingsError.authorizationError(errorNumber: nil, message: "Unknown error", binaryPath: binary))
    }

    func testTheNumberWinsEvenWhenTheMessageIsLocalized() {
        let error = ThingsError.authorizationError(errorNumber: -1743, message: "未獲授權傳送 Apple 事件給「Things3」。", binaryPath: binary)
        XCTAssertNotNil(error)
    }

    // MARK: - The message

    private var message: String {
        ThingsError.automationNotAuthorized(binaryPath: binary).errorDescription ?? ""
    }

    func testMessageNamesTheTargetApp() {
        XCTAssertTrue(message.contains("Things 3"))
    }

    func testMessageNamesTheBinaryPath() {
        XCTAssertTrue(message.contains(binary))
    }

    func testMessageSaysItIsTheAutomationPermission() {
        XCTAssertTrue(message.contains("Automation"))
        XCTAssertTrue(message.contains("-1743"))
    }

    func testMessagePointsToSystemSettings() {
        XCTAssertTrue(message.contains("System Settings"))
        XCTAssertTrue(message.contains("Privacy & Security"))
    }

    func testMessageMentionsSetupWithTheBinaryPath() {
        XCTAssertTrue(message.contains("\(binary) --setup"))
    }

    func testMessageWarnsThatSetupInTerminalMayNotCoverTheHostApp() {
        // Authorization granted from Terminal is attributed to Terminal, and
        // does not necessarily cover Claude / the editor that launches this server.
        XCTAssertTrue(message.contains("Terminal"))
        XCTAssertTrue(message.lowercased().contains("retry"))
    }

    func testMessageDoesNotSendTheUserToTheAccessibilityPane() {
        // The old --help said "Accessibility permission for AppleScript"; the
        // right pane is Automation. The message may say "not Accessibility"
        // but must never instruct enabling it.
        XCTAssertFalse(message.contains("enable Accessibility"))
    }

    func testTheErrorIsStillALocalizedError() {
        let error: Error = ThingsError.automationNotAuthorized(binaryPath: binary)
        XCTAssertTrue(error is LocalizedError)
    }
}
