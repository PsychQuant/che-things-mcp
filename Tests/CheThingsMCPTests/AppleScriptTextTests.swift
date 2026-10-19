import XCTest
@testable import CheThingsMCPCore

/// Issue 9: values that enter AppleScript source must be escaped or validated.
final class AppleScriptTextTests: XCTestCase {

    func testEscapeHandlesBackslashBeforeQuote() {
        // Backslash first, or the backslash added for a quote would itself be doubled.
        XCTAssertEqual(AppleScriptText.escape(#"a"b\c"#), #"a\"b\\c"#)
    }

    func testLiteralIsQuotedAndEscaped() {
        XCTAssertEqual(AppleScriptText.literal(#"say "hi""#), #""say \"hi\"""#)
        XCTAssertEqual(AppleScriptText.literal(""), #""""#)
    }

    func testValidatedIDAcceptsThingsIDForms() throws {
        // Observed form (22 alphanumerics) and UUID-style ids from older data.
        XCTAssertEqual(try AppleScriptText.validatedID("57BMhr9XYnzqypyo1uWFfY"), "57BMhr9XYnzqypyo1uWFfY")
        XCTAssertEqual(try AppleScriptText.validatedID("5A1C3B2D-0E4F-4A6B-9C8D-112233445566"),
                       "5A1C3B2D-0E4F-4A6B-9C8D-112233445566")
    }

    func testValidatedIDRejectsAnythingThatCouldLeaveTheLiteral() {
        let rejected = ["", "a\"b", "a\\b", "a b", "a&b", "a\nb", "a'b", String(repeating: "a", count: 65), "é"]
        for value in rejected {
            XCTAssertThrowsError(try AppleScriptText.validatedID(value), "accepted \(value.debugDescription)") { error in
                guard case ThingsError.invalidParameter = error else {
                    return XCTFail("expected invalidParameter for \(value.debugDescription), got \(error)")
                }
            }
        }
    }

    func testValidatedIDErrorDoesNotEchoTheValue() {
        // The rejected value is caller-controlled; the message names the rule, not the input.
        XCTAssertThrowsError(try AppleScriptText.validatedID("x\" & do something")) { error in
            XCTAssertFalse(error.localizedDescription.contains("do something"))
        }
    }

    func testSeparatorsAreControlCharactersThatScriptsAndParsersAgreeOn() {
        XCTAssertEqual(AppleScriptText.fieldSeparator, "\u{1F}")
        XCTAssertEqual(AppleScriptText.recordSeparator, "\u{1E}")
        XCTAssertEqual(AppleScriptText.fieldSeparatorExpression, "(character id 31)")
        XCTAssertEqual(AppleScriptText.recordSeparatorExpression, "(character id 30)")
    }
}
