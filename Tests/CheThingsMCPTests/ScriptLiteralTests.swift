import XCTest
@testable import CheThingsMCPCore

/// Issue 9: free-text values that are not ids — tags, date strings that do not parse, list
/// names that are not built-in lists — must reach the script as escaped string literals. The
/// stand-in runner records the generated script and stops before anything reaches Things.
final class ScriptLiteralTests: XCTestCase {

    private static let id = "57BMhr9XYnzqypyo1uWFfY"
    private static let hostile = #"x" & y \ z"#

    private final class Recorder: @unchecked Sendable { var scripts: [String] = [] }

    private func scripts(_ call: (ThingsManager) async throws -> Void) async -> [String] {
        let recorder = Recorder()
        let manager = ThingsManager(
            runScript: { script in
                recorder.scripts.append(script)
                throw ThingsError.scriptError("stop")
            },
            openURL: { _ in })
        _ = try? await call(manager)
        return recorder.scripts
    }

    private func assertOnlyEscaped(_ scripts: [String], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(scripts.isEmpty, "no script was generated", file: file, line: line)
        let all = scripts.joined(separator: "\n")
        XCTAssertTrue(all.contains(AppleScriptText.literal(Self.hostile)),
                      "value is not present as an escaped literal", file: file, line: line)
        XCTAssertFalse(all.contains(#""\#(Self.hostile)""#),
                       "value is present unescaped", file: file, line: line)
    }

    func testTagsAreEscapedInEveryTool() async {
        let tags = [Self.hostile]
        assertOnlyEscaped(await scripts { _ = try await $0.addTodo(name: "n", tags: tags) })
        assertOnlyEscaped(await scripts { _ = try await $0.addProject(name: "n", tags: tags) })
        assertOnlyEscaped(await scripts { try await $0.updateTodo(id: Self.id, tags: tags) })
        assertOnlyEscaped(await scripts { try await $0.updateProject(id: Self.id, tags: tags) })
        assertOnlyEscaped(await scripts { _ = try await $0.addArea(name: "n", tags: tags) })
        assertOnlyEscaped(await scripts { try await $0.updateArea(id: Self.id, tags: tags) })
    }

    func testUnparsedDateStringsAreEscaped() async {
        assertOnlyEscaped(await scripts { try await $0.updateTodo(id: Self.id, dueDate: Self.hostile) })
        assertOnlyEscaped(await scripts { try await $0.updateTodo(id: Self.id, when: Self.hostile) })
    }

    func testListNamesThatAreNotBuiltInAreEscaped() async {
        assertOnlyEscaped(await scripts { try await $0.moveTodo(id: Self.id, toList: Self.hostile) })
    }
}
