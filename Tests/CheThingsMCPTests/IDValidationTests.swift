import XCTest
@testable import CheThingsMCPCore

/// Issue 9: every tool that interpolates an id must refuse a malformed one before a script is
/// built or a URL is opened. The manager gets stand-ins that fail the test if they are reached,
/// so nothing here contacts Things.
final class IDValidationTests: XCTestCase {

    private static let badID = #"x" & y"#
    private static let goodID = "57BMhr9XYnzqypyo1uWFfY"

    private final class Probe: @unchecked Sendable {
        var scripts: [String] = []
        var urls: [URL] = []
    }

    private func makeManager(_ probe: Probe) -> ThingsManager {
        ThingsManager(
            runScript: { script in
                probe.scripts.append(script)
                throw ThingsError.scriptError("stand-in runner reached")
            },
            openURL: { url in probe.urls.append(url) })
    }

    private func assertRejected(
        _ name: String, file: StaticString = #filePath, line: UInt = #line,
        _ call: (ThingsManager) async throws -> Void
    ) async {
        let probe = Probe()
        do {
            try await call(makeManager(probe))
            XCTFail("\(name) accepted a malformed id", file: file, line: line)
        } catch ThingsError.invalidParameter {
            // expected
        } catch {
            XCTFail("\(name) threw \(error) instead of invalidParameter", file: file, line: line)
        }
        XCTAssertTrue(probe.scripts.isEmpty, "\(name) built and ran a script with a malformed id", file: file, line: line)
        XCTAssertTrue(probe.urls.isEmpty, "\(name) opened a URL with a malformed id", file: file, line: line)
    }

    func testEveryIDTakingToolRejectsAMalformedID() async {
        let id = Self.badID
        await assertRejected("updateTodo") { try await $0.updateTodo(id: id, name: "n") }
        await assertRejected("updateProject") { try await $0.updateProject(id: id, name: "n") }
        await assertRejected("completeTodo") { try await $0.completeTodo(id: id) }
        await assertRejected("cancelTodo") { try await $0.cancelTodo(id: id) }
        await assertRejected("cancelProject") { try await $0.cancelProject(id: id) }
        await assertRejected("editTodo") { try await $0.editTodo(id: id) }
        await assertRejected("editProject") { try await $0.editProject(id: id) }
        await assertRejected("deleteTodo") { try await $0.deleteTodo(id: id) }
        await assertRejected("deleteProject") { try await $0.deleteProject(id: id) }
        await assertRejected("updateArea") { try await $0.updateArea(id: id, name: "n") }
        await assertRejected("deleteArea") { try await $0.deleteArea(id: id) }
        await assertRejected("updateTag") { try await $0.updateTag(id: id, name: "n") }
        await assertRejected("deleteTag") { try await $0.deleteTag(id: id) }
        await assertRejected("moveTodo") { try await $0.moveTodo(id: id, toList: "Today") }
        await assertRejected("moveProject") { try await $0.moveProject(id: id, toArea: "a") }
        await assertRejected("showTodo") { try await $0.showTodo(id: id) }
        await assertRejected("showProject") { try await $0.showProject(id: id) }
        await assertRejected("getTodosInProject") { _ = try await $0.getTodosInProject(projectId: id) }
        await assertRejected("getTodosInArea") { _ = try await $0.getTodosInArea(areaId: id) }
        await assertRejected("getProjectsInArea") { _ = try await $0.getProjectsInArea(areaId: id) }
        await assertRejected("addChecklistItems") { try await $0.addChecklistItems(todoId: id, items: ["a"]) }
        await assertRejected("setChecklistItems") { try await $0.setChecklistItems(todoId: id, items: ["a"]) }
    }

    func testChecklistItemsCannotAddURLParameters() async throws {
        // `.urlQueryAllowed` leaves `&` and `=` unencoded, so item text could append parameters.
        let probe = Probe()
        let manager = makeManager(probe)
        try await manager.addChecklistItems(todoId: Self.goodID, items: ["milk&completed=true"])
        try await manager.setChecklistItems(todoId: Self.goodID, items: ["eggs=1&canceled=true"])
        XCTAssertEqual(probe.urls.count, 2)
        for url in probe.urls {
            let names = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.map(\.name) ?? []
            XCTAssertFalse(names.contains("completed") || names.contains("canceled"),
                           "item text became a URL parameter: \(url)")
            XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" })?.value, Self.goodID)
        }
    }
}
