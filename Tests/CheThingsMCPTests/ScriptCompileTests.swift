import Foundation
import XCTest
@testable import CheThingsMCPCore

/// Compiles every script the tools generate with `osacompile`. Compiling reads the Things 3
/// scripting dictionary but sends no Apple Event, so it needs no Automation permission; it
/// catches syntax errors in generated source that unit tests cannot see. Skipped unless
/// `CHE_THINGS_COMPILE=1` (each compile takes a few seconds) and Things 3 is installed.
final class ScriptCompileTests: XCTestCase {

    private final class Recorder: @unchecked Sendable { var scripts: [String] = [] }

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CHE_THINGS_COMPILE"] == "1",
                          "set CHE_THINGS_COMPILE=1 to compile generated scripts")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/Applications/Things3.app"),
                          "Things 3 is not installed")
    }

    private func generatedScripts() async -> [String] {
        let recorder = Recorder()
        let manager = ThingsManager(
            runScript: { script in recorder.scripts.append(script); return "" },
            openURL: { _ in })
        let id = "57BMhr9XYnzqypyo1uWFfY"
        let text = #"x" & y \ z|||w###v"#
        // Date fields use parseable values: AppleScript evaluates `date "…"` at compile time, so an
        // unparseable date fails to compile by design (the escaping of such strings is covered by
        // ScriptLiteralTests).
        _ = try? await manager.getInbox()
        _ = try? await manager.getToday()
        _ = try? await manager.getUpcoming()
        _ = try? await manager.getAnytime()
        _ = try? await manager.getSomeday()
        _ = try? await manager.getLogbook()
        _ = try? await manager.getProjects()
        _ = try? await manager.getAreas()
        _ = try? await manager.getTags()
        _ = try? await manager.searchTodos(query: text)
        _ = try? await manager.getSelectedTodos()
        _ = try? await manager.getTodosInProject(projectId: id)
        _ = try? await manager.getTodosInArea(areaName: text)
        _ = try? await manager.getProjectsInArea(areaId: id)
        _ = try? await manager.addTodo(name: text, notes: text, dueDate: "2026-10-19", tags: [text],
                                       listName: text, projectName: text, areaName: text, when: "tomorrow")
        _ = try? await manager.addProject(name: text, notes: text, tags: [text], areaName: text, when: "today")
        try? await manager.updateTodo(id: id, name: text, notes: text, dueDate: "2026-10-19", tags: [text], when: "2026-10-20")
        try? await manager.updateProject(id: id, name: text, notes: text, tags: [text])
        _ = try? await manager.addArea(name: text, tags: [text])
        try? await manager.updateArea(id: id, name: text, tags: [text])
        try? await manager.moveTodo(id: id, toList: text)
        try? await manager.moveTodo(id: id, toProject: text)
        return recorder.scripts
    }

    func testEveryGeneratedScriptCompiles() async throws {
        let scripts = await generatedScripts()
        XCTAssertGreaterThan(scripts.count, 15)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("che-things-compile-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for (index, script) in scripts.enumerated() {
            let source = dir.appendingPathComponent("s\(index).applescript")
            try script.write(to: source, atomically: true, encoding: .utf8)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osacompile")
            process.arguments = ["-o", dir.appendingPathComponent("s\(index).scpt").path, source.path]
            let errors = Pipe()
            process.standardError = errors
            try process.run()
            process.waitUntilExit()
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTAssertEqual(process.terminationStatus, 0, "script \(index) does not compile: \(message)\n\(script)")
        }
    }
}
