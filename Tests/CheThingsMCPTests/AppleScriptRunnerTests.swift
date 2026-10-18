import Foundation
import XCTest
@testable import CheThingsMCPCore

/// The executor every tool goes through. None of these tests needs Things 3:
/// the scripts below never address another application.
final class AppleScriptRunnerTests: XCTestCase {

    /// AppleScriptObjC lets the script report which thread `NSAppleScript` ran it on.
    private static let reportThread = """
    use framework "Foundation"
    use scripting additions
    return ((current application's NSThread's isMainThread()) as boolean) as text
    """

    // MARK: - Thread

    /// Apple documents NSAppleScript as main-thread only (Threading Programming Guide,
    /// Thread Safety Summary). On a background queue, Apple Events to Things stalled
    /// until the 120 s reply timeout (issue 5). Tool calls arrive on the cooperative
    /// pool, so the caller here is deliberately not the main thread.
    func testScriptsRunOnTheMainThreadWhenCalledFromABackgroundTask() async throws {
        let script = Self.reportThread
        let thread = try await Task.detached { try await AppleScriptRunner.run(script) }.value
        XCTAssertEqual(thread, "true", "NSAppleScript must run on the main thread")
    }

    // MARK: - Result

    func testReturnsTheStringTheScriptReturns() async throws {
        let output = try await AppleScriptRunner.run(#"return "id-1|||Name###""#)
        XCTAssertEqual(output, "id-1|||Name###")
    }

    func testAnEmptyResultIsAnEmptyString() async throws {
        let output = try await AppleScriptRunner.run(#"return """#)
        XCTAssertEqual(output, "")
    }

    // MARK: - Error mapping

    func testErrorMinus1743BecomesAutomationNotAuthorized() async {
        await assertThrows(#"error "Not authorized to send Apple events to Things3." number -1743"#) { error in
            guard case .automationNotAuthorized = error else { return XCTFail("got \(error)") }
        }
    }

    func testApplicationNotRunningBecomesThingsNotInstalled() async {
        await assertThrows(#"error "Application isn't running." number -600"#) { error in
            XCTAssertEqual(error, .thingsNotInstalled)
        }
    }

    func testOtherErrorsKeepTheirMessage() async {
        await assertThrows(#"error "Can't make the list into a record." number -1700"#) { error in
            XCTAssertEqual(error, .scriptError("Can't make the list into a record."))
        }
    }

    private func assertThrows(_ source: String, _ check: (ThingsError) -> Void,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            let output = try await AppleScriptRunner.run(source)
            XCTFail("expected an error, got \(output)", file: file, line: line)
        } catch let error as ThingsError {
            check(error)
        } catch {
            XCTFail("expected a ThingsError, got \(error)", file: file, line: line)
        }
    }
}
