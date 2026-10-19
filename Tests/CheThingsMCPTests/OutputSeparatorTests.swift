import XCTest
@testable import CheThingsMCPCore

/// Issue 9: script output used `|||` between fields and `###` between records, so a name, note
/// or tag containing either shifted fields. The stand-in runner returns output built with the
/// shared separators and the parsers must read text containing the old sequences verbatim.
final class OutputSeparatorTests: XCTestCase {

    private static let f = AppleScriptText.fieldSeparator
    private static let r = AppleScriptText.recordSeparator
    private static let tricky = "a|||b###c"

    private func manager(returning output: String) -> ThingsManager {
        ThingsManager(runScript: { _ in output }, openURL: { _ in })
    }

    private static func record(_ fields: [String]) -> String {
        fields.joined(separator: f) + r
    }

    func testTodosKeepNamesNotesAndTagsWithOldSeparators() async throws {
        let output = Self.record(["ID1", Self.tricky, "note " + Self.tricky, "open", "t|||1, t###2",
                                  "", "", "", "Proj|||X", "Area###Y"])
            + Self.record(["ID2", "second", "", "completed", "", "", "", "", "", ""])
        let todos = try await manager(returning: output).getSelectedTodos()
        XCTAssertEqual(todos.count, 2)
        XCTAssertEqual(todos[0].name, Self.tricky)
        XCTAssertEqual(todos[0].notes, "note " + Self.tricky)
        XCTAssertEqual(todos[0].tagNames, ["t|||1", "t###2"])
        XCTAssertEqual(todos[0].projectName, "Proj|||X")
        XCTAssertEqual(todos[0].areaName, "Area###Y")
        XCTAssertEqual(todos[1].name, "second")
    }

    func testProjectsKeepNamesWithOldSeparators() async throws {
        let output = Self.record(["P1", Self.tricky, "", "open", "", "Area|||1", "3"])
        let projects = try await manager(returning: output).getProjects()
        XCTAssertEqual(projects.map(\.name), [Self.tricky])
        XCTAssertEqual(projects.first?.areaName, "Area|||1")
        XCTAssertEqual(projects.first?.todoCount, 3)
    }

    func testAreasAndTagsKeepNamesWithOldSeparators() async throws {
        let areas = try await manager(returning: Self.record(["A1", Self.tricky, "x###y"])).getAreas()
        XCTAssertEqual(areas.map(\.name), [Self.tricky])
        XCTAssertEqual(areas.first?.tagNames, ["x###y"])

        let tags = try await manager(returning: Self.record(["T1", Self.tricky, "Parent|||P"])).getTags()
        XCTAssertEqual(tags.map(\.name), [Self.tricky])
        XCTAssertEqual(tags.first?.parentTagName, "Parent|||P")
    }

    func testScriptsEmitTheSharedSeparatorsNotTheOldOnes() {
        for script in [ThingsManager.tagsScript, ThingsManager.areasScript] {
            XCTAssertTrue(script.contains(AppleScriptText.fieldSeparatorExpression))
            XCTAssertTrue(script.contains(AppleScriptText.recordSeparatorExpression))
            XCTAssertFalse(script.contains("\"|||\"") || script.contains("\"###\""))
        }
    }
}
