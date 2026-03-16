import Foundation
import AppKit

// MARK: - Data Models

public struct Todo: Codable {
    public let id: String
    public let name: String
    public let notes: String?
    public let status: String  // "open", "completed", "canceled"
    public let tagNames: [String]
    public let dueDate: String?
    public let scheduledDate: String?
    public let completionDate: String?
    public let projectName: String?
    public let areaName: String?

    public init(id: String, name: String, notes: String?, status: String, tagNames: [String], dueDate: String?, scheduledDate: String?, completionDate: String?, projectName: String?, areaName: String?) {
        self.id = id
        self.name = name
        self.notes = notes
        self.status = status
        self.tagNames = tagNames
        self.dueDate = dueDate
        self.scheduledDate = scheduledDate
        self.completionDate = completionDate
        self.projectName = projectName
        self.areaName = areaName
    }
}

public struct Project: Codable {
    public let id: String
    public let name: String
    public let notes: String?
    public let status: String
    public let tagNames: [String]
    public let areaName: String?
    public let todoCount: Int

    public init(id: String, name: String, notes: String?, status: String, tagNames: [String], areaName: String?, todoCount: Int) {
        self.id = id
        self.name = name
        self.notes = notes
        self.status = status
        self.tagNames = tagNames
        self.areaName = areaName
        self.todoCount = todoCount
    }
}

public struct Area: Codable {
    public let id: String
    public let name: String
    public let tagNames: [String]

    public init(id: String, name: String, tagNames: [String]) {
        self.id = id
        self.name = name
        self.tagNames = tagNames
    }
}

public struct Tag: Codable {
    public let id: String
    public let name: String
    public let parentTagName: String?

    public init(id: String, name: String, parentTagName: String? = nil) {
        self.id = id
        self.name = name
        self.parentTagName = parentTagName
    }
}

// MARK: - Errors

public enum ThingsError: Error, LocalizedError {
    case scriptError(String)
    case notFound(String)
    case todoNotFound(id: String)
    case projectNotFound(id: String)
    case areaNotFound(id: String)
    case tagNotFound(name: String)
    case invalidParameter(String)
    case thingsNotInstalled
    case urlSchemeError(String)

    public var errorDescription: String? {
        switch self {
        case .scriptError(let message):
            return "AppleScript error: \(message)"
        case .notFound(let item):
            return "Not found: \(item)"
        case .todoNotFound(let id):
            return "To-do not found with ID: \(id)"
        case .projectNotFound(let id):
            return "Project not found with ID: \(id)"
        case .areaNotFound(let id):
            return "Area not found with ID: \(id)"
        case .tagNotFound(let name):
            return "Tag not found: \(name)"
        case .invalidParameter(let message):
            return "Invalid parameter: \(message)"
        case .thingsNotInstalled:
            return "Things 3 is not installed. Please install it from the Mac App Store."
        case .urlSchemeError(let message):
            return "URL Scheme error: \(message)"
        }
    }
}

// MARK: - ThingsManager Actor

public actor ThingsManager {

    // MARK: - Auth Token

    private var authToken: String?

    public init() {
        // Read auth token from environment variable
        self.authToken = ProcessInfo.processInfo.environment["THINGS3_AUTH_TOKEN"]
    }

    /// Set the auth token at runtime
    public func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    /// Check if auth token is configured
    public func hasAuthToken() -> Bool {
        return authToken != nil && !authToken!.isEmpty
    }

    // MARK: - Localization Helpers

    /// Get the Things3 internal list ID for built-in lists
    /// This avoids localization issues (e.g., "Today" vs "今天")
    /// IDs verified via: osascript -e 'tell application "Things3" to get id of every list'
    private func getListIdForBuiltIn(_ listName: String) -> String? {
        switch listName.lowercased() {
        case "inbox": return "TMInboxListSource"
        case "today": return "TMTodayListSource"
        case "upcoming": return "TMCalendarListSource"    // NOT TMUpcomingListSource!
        case "anytime": return "TMNextListSource"         // NOT TMAnytimeListSource!
        case "someday": return "TMSomedayListSource"
        case "logbook": return "TMLogbookListSource"
        default: return nil
        }
    }

    /// Get AppleScript list reference string (locale-independent for built-in lists)
    private func getListReference(_ listName: String) -> String {
        if let listId = getListIdForBuiltIn(listName) {
            return "list id \"\(listId)\""
        }
        return "list \"\(listName)\""
    }

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - AppleScript Execution

    // IMPORTANT: AppleScript execution MUST run on a background thread to avoid blocking
    // the MCP SDK's async event loop. NSAppleScript.executeAndReturnError is synchronous
    // and will block stdin processing if run on the main thread.

    private func executeAppleScript(_ script: String) async throws -> String {
        // Run AppleScript on a background DispatchQueue to prevent blocking MCP event loop
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                guard let appleScript = NSAppleScript(source: script) else {
                    continuation.resume(throwing: ThingsError.scriptError("Failed to create AppleScript"))
                    return
                }

                let result = appleScript.executeAndReturnError(&error)

                if let error = error {
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    if errorMessage.contains("Application isn't running") || errorMessage.contains("Can't get application") {
                        continuation.resume(throwing: ThingsError.thingsNotInstalled)
                    } else {
                        continuation.resume(throwing: ThingsError.scriptError(errorMessage))
                    }
                    return
                }

                continuation.resume(returning: result.stringValue ?? "")
            }
        }
    }

    private func executeAppleScriptReturningList(_ script: String) async throws -> [String] {
        // Run AppleScript on a background DispatchQueue to prevent blocking MCP event loop
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                guard let appleScript = NSAppleScript(source: script) else {
                    continuation.resume(throwing: ThingsError.scriptError("Failed to create AppleScript"))
                    return
                }

                let result = appleScript.executeAndReturnError(&error)

                if let error = error {
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    continuation.resume(throwing: ThingsError.scriptError(errorMessage))
                    return
                }

                // Parse list result
                var items: [String] = []
                let count = result.numberOfItems
                for i in 1...count {
                    if let item = result.atIndex(i)?.stringValue {
                        items.append(item)
                    }
                }
                continuation.resume(returning: items)
            }
        }
    }

    // MARK: - List Access (Read Operations)

    public func getTodos(from listName: String) async throws -> [Todo] {
        // Use source type for built-in lists to avoid localization issues
        let listRef = getListReference(listName)

        // PERFORMANCE OPTIMIZATION: Use batch property fetching instead of repeat loop
        // This reduces execution time from ~30s to ~1s for 361 items (29x improvement)
        // See: docs/APPLESCRIPT_LOCALIZATION.md for details
        let script = """
        tell application "Things3"
            set todoCount to count of to dos of \(listRef)
            if todoCount = 0 then return ""

            -- Batch fetch all properties (8 Apple Events instead of M×N)
            set allIds to id of to dos of \(listRef)
            set allNames to name of to dos of \(listRef)
            set allNotes to notes of to dos of \(listRef)
            set allStatuses to status of to dos of \(listRef)
            set allTags to tag names of to dos of \(listRef)
            set allDueDates to due date of to dos of \(listRef)
            set allScheduledDates to activation date of to dos of \(listRef)
            set allCompletionDates to completion date of to dos of \(listRef)

            -- project/area need fallback due to potential errors
            set allProjects to {}
            set allAreas to {}
            try
                set allProjects to name of project of to dos of \(listRef)
            on error
                set todoItems to to dos of \(listRef)
                repeat with t in todoItems
                    set projStr to ""
                    try
                        set projStr to name of project of t
                    end try
                    set end of allProjects to projStr
                end repeat
            end try

            try
                set allAreas to name of area of to dos of \(listRef)
            on error
                set todoItems to to dos of \(listRef)
                repeat with t in todoItems
                    set areaStr to ""
                    try
                        set areaStr to name of area of t
                    end try
                    set end of allAreas to areaStr
                end repeat
            end try

            -- Ensure project/area lists have correct length
            if (count of allProjects) < todoCount then
                set todoItems to to dos of \(listRef)
                set allProjects to {}
                repeat with t in todoItems
                    set projStr to ""
                    try
                        set projStr to name of project of t
                    end try
                    set end of allProjects to projStr
                end repeat
            end if

            if (count of allAreas) < todoCount then
                set todoItems to to dos of \(listRef)
                set allAreas to {}
                repeat with t in todoItems
                    set areaStr to ""
                    try
                        set areaStr to name of area of t
                    end try
                    set end of allAreas to areaStr
                end repeat
            end if

            -- Build output (only string concatenation, no Apple Events)
            set output to ""
            repeat with i from 1 to todoCount
                set dueStr to ""
                if item i of allDueDates is not missing value then
                    set dueStr to (item i of allDueDates) as string
                end if

                set schedStr to ""
                if item i of allScheduledDates is not missing value then
                    set schedStr to (item i of allScheduledDates) as string
                end if

                set compStr to ""
                if item i of allCompletionDates is not missing value then
                    set compStr to (item i of allCompletionDates) as string
                end if

                set projStr to ""
                if item i of allProjects is not missing value then
                    set projStr to item i of allProjects as string
                end if

                set areaStr to ""
                if item i of allAreas is not missing value then
                    set areaStr to item i of allAreas as string
                end if

                set output to output & (item i of allIds) & "|||" & (item i of allNames) & "|||" & (item i of allNotes) & "|||" & (item i of allStatuses) & "|||" & (item i of allTags) & "|||" & dueStr & "|||" & schedStr & "|||" & compStr & "|||" & projStr & "|||" & areaStr & "###"
            end repeat

            return output
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseTodosFromOutput(result)
    }

    public func getInbox() async throws -> [Todo] {
        return try await getTodos(from: "Inbox")
    }

    public func getToday() async throws -> [Todo] {
        return try await getTodos(from: "Today")
    }

    public func getUpcoming() async throws -> [Todo] {
        return try await getTodos(from: "Upcoming")
    }

    public func getAnytime() async throws -> [Todo] {
        return try await getTodos(from: "Anytime")
    }

    public func getSomeday() async throws -> [Todo] {
        return try await getTodos(from: "Someday")
    }

    public func getLogbook() async throws -> [Todo] {
        return try await getTodos(from: "Logbook")
    }

    // MARK: - Projects

    public func getProjects() async throws -> [Project] {
        let script = """
        tell application "Things3"
            set output to ""
            repeat with p in projects
                set projId to id of p
                set projName to name of p
                set projNotes to notes of p
                set projStatus to status of p
                set projTags to tag names of p

                set projArea to ""
                try
                    set projArea to name of area of p
                end try

                set projTodoCount to count of to dos of p

                set output to output & projId & "|||" & projName & "|||" & projNotes & "|||" & projStatus & "|||" & projTags & "|||" & projArea & "|||" & projTodoCount & "###"
            end repeat
            return output
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseProjectsFromOutput(result)
    }

    // MARK: - Search

    public func searchTodos(query: String) async throws -> [Todo] {
        // Use Swift-layer filtering for reliable UTF-8/Unicode support
        // AppleScript's "contains" has issues with CJK and special characters
        let allTodos = try await getAllOpenTodos()
        let lowerQuery = query.lowercased()

        return allTodos.filter { todo in
            todo.name.lowercased().contains(lowerQuery) ||
            (todo.notes?.lowercased().contains(lowerQuery) ?? false)
        }
    }

    /// Get all open (non-completed, non-canceled) todos using batch property fetching
    private func getAllOpenTodos() async throws -> [Todo] {
        // Use batch property fetching for performance (same optimization as getTodos)
        let script = """
        tell application "Things3"
            set todoCount to count of (to dos whose status is open)
            if todoCount = 0 then return ""

            -- Batch fetch all properties for open todos
            set allIds to id of (to dos whose status is open)
            set allNames to name of (to dos whose status is open)
            set allNotes to notes of (to dos whose status is open)
            set allStatuses to status of (to dos whose status is open)
            set allTags to tag names of (to dos whose status is open)
            set allDueDates to due date of (to dos whose status is open)
            set allScheduledDates to activation date of (to dos whose status is open)
            set allCompletionDates to completion date of (to dos whose status is open)

            -- project/area need fallback due to potential errors
            set allProjects to {}
            set allAreas to {}
            set todoItems to (to dos whose status is open)
            repeat with t in todoItems
                set projStr to ""
                try
                    set projStr to name of project of t
                end try
                set end of allProjects to projStr

                set areaStr to ""
                try
                    set areaStr to name of area of t
                end try
                set end of allAreas to areaStr
            end repeat

            -- Build output (only string concatenation, no Apple Events)
            set output to ""
            repeat with i from 1 to todoCount
                set dueStr to ""
                if item i of allDueDates is not missing value then
                    set dueStr to (item i of allDueDates) as string
                end if

                set schedStr to ""
                if item i of allScheduledDates is not missing value then
                    set schedStr to (item i of allScheduledDates) as string
                end if

                set compStr to ""
                if item i of allCompletionDates is not missing value then
                    set compStr to (item i of allCompletionDates) as string
                end if

                set projStr to ""
                if item i of allProjects is not missing value then
                    set projStr to item i of allProjects as string
                end if

                set areaStr to ""
                if item i of allAreas is not missing value then
                    set areaStr to item i of allAreas as string
                end if

                set output to output & (item i of allIds) & "|||" & (item i of allNames) & "|||" & (item i of allNotes) & "|||" & (item i of allStatuses) & "|||" & (item i of allTags) & "|||" & dueStr & "|||" & schedStr & "|||" & compStr & "|||" & projStr & "|||" & areaStr & "###"
            end repeat

            return output
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseTodosFromOutput(result)
    }

    // MARK: - Create Operations

    public func addTodo(
        name: String,
        notes: String? = nil,
        dueDate: String? = nil,
        tags: [String]? = nil,
        listName: String? = nil,
        projectName: String? = nil,
        areaName: String? = nil,
        when: String? = nil  // "today", "tomorrow", "evening", "anytime", "someday", or date string
    ) async throws -> Todo {
        // Validate project exists before attempting to create todo
        if let projectName = projectName {
            let checkScript = """
            tell application "Things3"
                try
                    set proj to first project whose name is "\(escapeForAppleScript(projectName))"
                    return "found"
                on error
                    return "not_found"
                end try
            end tell
            """
            let checkResult = try await executeAppleScript(checkScript)
            if checkResult.trimmingCharacters(in: .whitespacesAndNewlines) == "not_found" {
                throw ThingsError.invalidParameter("Project '\(projectName)' not found")
            }
        }

        var properties = "name:\"\(escapeForAppleScript(name))\""

        if let notes = notes {
            properties += ", notes:\"\(escapeForAppleScript(notes))\""
        }

        if let tags = tags, !tags.isEmpty {
            properties += ", tag names:\"\(tags.joined(separator: ", "))\""
        }

        // Determine where to create the todo
        // Note: Things 3's `make` command does NOT support `in project "..."` or `in list id "..."`
        // We must create first, then set project or move to list/area
        var postCreateStatements: [String] = []
        if let projectName = projectName {
            // Set project property after creation
            postCreateStatements.append("set project of newTodo to project \"\(escapeForAppleScript(projectName))\"")
        } else if let areaName = areaName {
            // Move to area (for to-dos not in a project)
            postCreateStatements.append("move newTodo to area \"\(escapeForAppleScript(areaName))\"")
        } else if let listName = listName {
            // For lists, we need to move after creation
            if let listId = getListIdForBuiltIn(listName) {
                // Built-in list: move to list id
                postCreateStatements.append("move newTodo to list id \"\(listId)\"")
            } else {
                // Custom list: try move to list by name
                postCreateStatements.append("move newTodo to list \"\(escapeForAppleScript(listName))\"")
            }
        }

        // Build due date statement with proper date parsing
        let dueDateStatement: String
        if let dueDate = dueDate {
            dueDateStatement = "set due date of newTodo to \(formatDateForAppleScript(dueDate))"
        } else {
            dueDateStatement = ""
        }

        // Build post-create statements
        if let when = when {
            postCreateStatements.append(getWhenStatement("newTodo", when))
        }
        if !dueDateStatement.isEmpty {
            postCreateStatements.append(dueDateStatement)
        }

        let script = """
        tell application "Things3"
            set newTodo to make new to do with properties {\(properties)}
            \(postCreateStatements.joined(separator: "\n            "))
            return id of newTodo
        end tell
        """

        let todoId = try await executeAppleScript(script)

        // Fetch and return the created todo
        return Todo(
            id: todoId.trimmingCharacters(in: .whitespacesAndNewlines),
            name: name,
            notes: notes,
            status: "open",
            tagNames: tags ?? [],
            dueDate: dueDate,
            scheduledDate: nil,
            completionDate: nil,
            projectName: projectName,
            areaName: areaName
        )
    }

    public func addProject(
        name: String,
        notes: String? = nil,
        tags: [String]? = nil,
        areaName: String? = nil,
        when: String? = nil
    ) async throws -> Project {
        var properties = "name:\"\(escapeForAppleScript(name))\""

        if let notes = notes {
            properties += ", notes:\"\(escapeForAppleScript(notes))\""
        }

        if let tags = tags, !tags.isEmpty {
            properties += ", tag names:\"\(tags.joined(separator: ", "))\""
        }

        // Things 3's `make` command does NOT support `in area "..."` for projects.
        // We must create first, then move to area (same pattern as addTodo).
        var postCreateStatements: [String] = []
        if let areaName = areaName {
            postCreateStatements.append("move newProject to area \"\(escapeForAppleScript(areaName))\"")
        }
        if let when = when {
            postCreateStatements.append(getWhenStatement("newProject", when))
        }

        let script = """
        tell application "Things3"
            set newProject to make new project with properties {\(properties)}
            \(postCreateStatements.joined(separator: "\n            "))
            return id of newProject
        end tell
        """

        let projectId = try await executeAppleScript(script)

        return Project(
            id: projectId.trimmingCharacters(in: .whitespacesAndNewlines),
            name: name,
            notes: notes,
            status: "open",
            tagNames: tags ?? [],
            areaName: areaName,
            todoCount: 0
        )
    }

    // MARK: - Update Operations

    public func updateTodo(
        id: String,
        name: String? = nil,
        notes: String? = nil,
        dueDate: String? = nil,
        tags: [String]? = nil,
        when: String? = nil
    ) async throws {
        var updates: [String] = []

        if let name = name {
            updates.append("set name of targetTodo to \"\(escapeForAppleScript(name))\"")
        }
        if let notes = notes {
            updates.append("set notes of targetTodo to \"\(escapeForAppleScript(notes))\"")
        }
        if let tags = tags {
            updates.append("set tag names of targetTodo to \"\(tags.joined(separator: ", "))\"")
        }
        if let dueDate = dueDate {
            updates.append("set due date of targetTodo to \(formatDateForAppleScript(dueDate))")
        }
        if let when = when {
            updates.append(getWhenStatement("targetTodo", when))
        }

        guard !updates.isEmpty else {
            throw ThingsError.invalidParameter("No updates specified")
        }

        let script = """
        tell application "Things3"
            set targetTodo to to do id "\(id)"
            \(updates.joined(separator: "\n            "))
        end tell
        """

        _ = try await executeAppleScript(script)
    }

    public func updateProject(
        id: String,
        name: String? = nil,
        notes: String? = nil,
        tags: [String]? = nil
    ) async throws {
        var updates: [String] = []

        if let name = name {
            updates.append("set name of targetProject to \"\(escapeForAppleScript(name))\"")
        }
        if let notes = notes {
            updates.append("set notes of targetProject to \"\(escapeForAppleScript(notes))\"")
        }
        if let tags = tags {
            updates.append("set tag names of targetProject to \"\(tags.joined(separator: ", "))\"")
        }

        guard !updates.isEmpty else {
            throw ThingsError.invalidParameter("No updates specified")
        }

        let script = """
        tell application "Things3"
            set targetProject to project id "\(id)"
            \(updates.joined(separator: "\n            "))
        end tell
        """

        _ = try await executeAppleScript(script)
    }

    // MARK: - Complete/Delete Operations

    public func completeTodo(id: String, completed: Bool = true) async throws {
        let status = completed ? "completed" : "open"
        let script = """
        tell application "Things3"
            set status of to do id "\(id)" to \(status)
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    public func cancelTodo(id: String, canceled: Bool = true) async throws {
        let status = canceled ? "canceled" : "open"
        let script = """
        tell application "Things3"
            set status of to do id "\(id)" to \(status)
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    public func cancelProject(id: String, canceled: Bool = true) async throws {
        let status = canceled ? "canceled" : "open"
        let script = """
        tell application "Things3"
            set status of project id "\(id)" to \(status)
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    // MARK: - Edit Operations (Open in Things UI)

    public func editTodo(id: String) async throws {
        let script = """
        tell application "Things3"
            edit to do id "\(id)"
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    public func editProject(id: String) async throws {
        let script = """
        tell application "Things3"
            edit project id "\(id)"
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    // MARK: - Log Completed

    public func logCompletedNow() async throws {
        let script = """
        tell application "Things3"
            log completed now
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    public func deleteTodo(id: String) async throws {
        // Use 'delete' command instead of moving to localized "Trash" list
        // This works regardless of Things3 language settings
        let script = """
        tell application "Things3"
            delete to do id "\(id)"
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    public func deleteProject(id: String) async throws {
        // Use 'delete' command instead of moving to localized "Trash" list
        // This works regardless of Things3 language settings
        let script = """
        tell application "Things3"
            delete project id "\(id)"
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    // MARK: - Areas

    public func getAreas() async throws -> [Area] {
        let script = """
        tell application "Things3"
            set output to ""
            repeat with a in areas
                set areaId to id of a
                set areaName to name of a
                set areaTags to tag names of a
                set output to output & areaId & "|||" & areaName & "|||" & areaTags & "###"
            end repeat
            return output
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseAreasFromOutput(result)
    }

    // MARK: - Area Operations

    public func addArea(
        name: String,
        tags: [String]? = nil
    ) async throws -> Area {
        var properties = "name:\"\(escapeForAppleScript(name))\""

        if let tags = tags, !tags.isEmpty {
            properties += ", tag names:\"\(tags.joined(separator: ", "))\""
        }

        let script = """
        tell application "Things3"
            set newArea to make new area with properties {\(properties)}
            return id of newArea
        end tell
        """

        let areaId = try await executeAppleScript(script)

        return Area(
            id: areaId.trimmingCharacters(in: .whitespacesAndNewlines),
            name: name,
            tagNames: tags ?? []
        )
    }

    public func updateArea(
        id: String,
        name: String? = nil,
        tags: [String]? = nil
    ) async throws {
        var updates: [String] = []

        if let name = name {
            updates.append("set name of targetArea to \"\(escapeForAppleScript(name))\"")
        }
        if let tags = tags {
            updates.append("set tag names of targetArea to \"\(tags.joined(separator: ", "))\"")
        }

        guard !updates.isEmpty else {
            throw ThingsError.invalidParameter("No updates specified")
        }

        let script = """
        tell application "Things3"
            set targetArea to area id "\(id)"
            \(updates.joined(separator: "\n            "))
        end tell
        """

        _ = try await executeAppleScript(script)
    }

    public func deleteArea(id: String) async throws {
        // Note: When deleting an area, the area itself is not moved to Trash,
        // but its children (projects and to-dos) will be moved to Trash
        let script = """
        tell application "Things3"
            delete area id "\(id)"
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    // MARK: - Tags

    public func getTags() async throws -> [Tag] {
        let script = """
        tell application "Things3"
            set output to ""
            repeat with t in tags
                set tagId to id of t
                set tagName to name of t
                set parentName to ""
                try
                    set parentName to name of parent tag of t
                end try
                set output to output & tagId & "|||" & tagName & "|||" & parentName & "###"
            end repeat
            return output
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseTagsFromOutput(result)
    }

    // MARK: - Tag Operations

    public func addTag(
        name: String,
        parentTagName: String? = nil
    ) async throws -> Tag {
        var script: String

        if let parentName = parentTagName {
            script = """
            tell application "Things3"
                set parentT to tag "\(escapeForAppleScript(parentName))"
                set newTag to make new tag with properties {name:"\(escapeForAppleScript(name))", parent tag:parentT}
                return id of newTag
            end tell
            """
        } else {
            script = """
            tell application "Things3"
                set newTag to make new tag with properties {name:"\(escapeForAppleScript(name))"}
                return id of newTag
            end tell
            """
        }

        let tagId = try await executeAppleScript(script)

        return Tag(
            id: tagId.trimmingCharacters(in: .whitespacesAndNewlines),
            name: name,
            parentTagName: parentTagName
        )
    }

    public func updateTag(
        id: String,
        name: String? = nil,
        parentTagName: String? = nil
    ) async throws {
        var updates: [String] = []

        if let name = name {
            updates.append("set name of targetTag to \"\(escapeForAppleScript(name))\"")
        }
        if let parentName = parentTagName {
            if parentName.isEmpty {
                // Remove parent tag (make it a top-level tag)
                updates.append("set parent tag of targetTag to missing value")
            } else {
                updates.append("set parent tag of targetTag to tag \"\(escapeForAppleScript(parentName))\"")
            }
        }

        guard !updates.isEmpty else {
            throw ThingsError.invalidParameter("No updates specified")
        }

        let script = """
        tell application "Things3"
            set targetTag to tag id "\(id)"
            \(updates.joined(separator: "\n            "))
        end tell
        """

        _ = try await executeAppleScript(script)
    }

    public func deleteTag(id: String) async throws {
        let script = """
        tell application "Things3"
            delete tag id "\(id)"
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    // MARK: - Move Operations

    public func moveTodo(id: String, toList: String? = nil, toProject: String? = nil) async throws {
        var moveCommand = ""

        if let projectName = toProject {
            moveCommand = "move to do id \"\(id)\" to project \"\(escapeForAppleScript(projectName))\""
        } else if let listName = toList {
            // Use source type for built-in lists to avoid localization issues
            let listRef = getListReference(listName)
            moveCommand = "move to do id \"\(id)\" to \(listRef)"
        } else {
            throw ThingsError.invalidParameter("Either toList or toProject must be specified")
        }

        let script = """
        tell application "Things3"
            \(moveCommand)
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    public func moveProject(id: String, toArea: String) async throws {
        let script = """
        tell application "Things3"
            move project id "\(id)" to area "\(escapeForAppleScript(toArea))"
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    // MARK: - UI Operations

    public func showTodo(id: String) async throws {
        let script = """
        tell application "Things3"
            show to do id "\(id)"
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    public func showProject(id: String) async throws {
        let script = """
        tell application "Things3"
            show project id "\(id)"
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    public func showList(name: String) async throws {
        // Use source type for built-in lists to avoid localization issues
        let listRef = getListReference(name)
        let script = """
        tell application "Things3"
            show \(listRef)
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    public func showQuickEntry(
        name: String? = nil,
        notes: String? = nil,
        when: String? = nil,
        listName: String? = nil
    ) async throws {
        var properties: [String] = []

        if let name = name {
            properties.append("name:\"\(escapeForAppleScript(name))\"")
        }
        if let notes = notes {
            properties.append("notes:\"\(escapeForAppleScript(notes))\"")
        }

        var showCommand = "show quick entry panel"
        if !properties.isEmpty {
            showCommand += " with properties {\(properties.joined(separator: ", "))}"
        }

        let script = """
        tell application "Things3"
            \(showCommand)
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    // MARK: - Utility Operations

    public func emptyTrash() async throws {
        let script = """
        tell application "Things3"
            empty trash
        end tell
        """
        _ = try await executeAppleScript(script)
    }

    public func getSelectedTodos() async throws -> [Todo] {
        let script = """
        tell application "Things3"
            set output to ""
            set selectedItems to selected to dos
            repeat with t in selectedItems
                set todoId to id of t
                set todoName to name of t
                set todoNotes to notes of t
                set todoStatus to status of t
                set todoTags to tag names of t

                set todoDueDate to ""
                try
                    set todoDueDate to due date of t as string
                end try

                set todoScheduledDate to ""
                try
                    set todoScheduledDate to activation date of t as string
                end try

                set todoCompletionDate to ""
                try
                    set todoCompletionDate to completion date of t as string
                end try

                set todoProject to ""
                try
                    set todoProject to name of project of t
                end try

                set todoArea to ""
                try
                    set todoArea to name of area of t
                end try

                set output to output & todoId & "|||" & todoName & "|||" & todoNotes & "|||" & todoStatus & "|||" & todoTags & "|||" & todoDueDate & "|||" & todoScheduledDate & "|||" & todoCompletionDate & "|||" & todoProject & "|||" & todoArea & "###"
            end repeat
            return output
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseTodosFromOutput(result)
    }

    // MARK: - Advanced Queries

    public func getTodosInProject(projectId: String? = nil, projectName: String? = nil) async throws -> [Todo] {
        var projectRef = ""
        if let id = projectId {
            projectRef = "project id \"\(id)\""
        } else if let name = projectName {
            projectRef = "project \"\(escapeForAppleScript(name))\""
        } else {
            throw ThingsError.invalidParameter("Either projectId or projectName must be specified")
        }

        let script = """
        tell application "Things3"
            set output to ""
            set todoItems to to dos of \(projectRef)
            repeat with t in todoItems
                set todoId to id of t
                set todoName to name of t
                set todoNotes to notes of t
                set todoStatus to status of t
                set todoTags to tag names of t

                set todoDueDate to ""
                try
                    set todoDueDate to due date of t as string
                end try

                set todoScheduledDate to ""
                try
                    set todoScheduledDate to activation date of t as string
                end try

                set todoCompletionDate to ""
                try
                    set todoCompletionDate to completion date of t as string
                end try

                set todoProject to ""
                try
                    set todoProject to name of project of t
                end try

                set todoArea to ""
                try
                    set todoArea to name of area of t
                end try

                set output to output & todoId & "|||" & todoName & "|||" & todoNotes & "|||" & todoStatus & "|||" & todoTags & "|||" & todoDueDate & "|||" & todoScheduledDate & "|||" & todoCompletionDate & "|||" & todoProject & "|||" & todoArea & "###"
            end repeat
            return output
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseTodosFromOutput(result)
    }

    public func getTodosInArea(areaId: String? = nil, areaName: String? = nil) async throws -> [Todo] {
        var areaRef = ""
        if let id = areaId {
            areaRef = "area id \"\(id)\""
        } else if let name = areaName {
            areaRef = "area \"\(escapeForAppleScript(name))\""
        } else {
            throw ThingsError.invalidParameter("Either areaId or areaName must be specified")
        }

        let script = """
        tell application "Things3"
            set output to ""
            set todoItems to to dos of \(areaRef)
            repeat with t in todoItems
                set todoId to id of t
                set todoName to name of t
                set todoNotes to notes of t
                set todoStatus to status of t
                set todoTags to tag names of t

                set todoDueDate to ""
                try
                    set todoDueDate to due date of t as string
                end try

                set todoScheduledDate to ""
                try
                    set todoScheduledDate to activation date of t as string
                end try

                set todoCompletionDate to ""
                try
                    set todoCompletionDate to completion date of t as string
                end try

                set todoProject to ""
                try
                    set todoProject to name of project of t
                end try

                set todoArea to ""
                try
                    set todoArea to name of area of t
                end try

                set output to output & todoId & "|||" & todoName & "|||" & todoNotes & "|||" & todoStatus & "|||" & todoTags & "|||" & todoDueDate & "|||" & todoScheduledDate & "|||" & todoCompletionDate & "|||" & todoProject & "|||" & todoArea & "###"
            end repeat
            return output
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseTodosFromOutput(result)
    }

    public func getProjectsInArea(areaId: String? = nil, areaName: String? = nil) async throws -> [Project] {
        var areaRef = ""
        if let id = areaId {
            areaRef = "area id \"\(id)\""
        } else if let name = areaName {
            areaRef = "area \"\(escapeForAppleScript(name))\""
        } else {
            throw ThingsError.invalidParameter("Either areaId or areaName must be specified")
        }

        let script = """
        tell application "Things3"
            set output to ""
            repeat with p in projects of \(areaRef)
                set projId to id of p
                set projName to name of p
                set projNotes to notes of p
                set projStatus to status of p
                set projTags to tag names of p

                set projArea to ""
                try
                    set projArea to name of area of p
                end try

                set projTodoCount to count of to dos of p

                set output to output & projId & "|||" & projName & "|||" & projNotes & "|||" & projStatus & "|||" & projTags & "|||" & projArea & "|||" & projTodoCount & "###"
            end repeat
            return output
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseProjectsFromOutput(result)
    }

    // MARK: - Helper Methods

    private func escapeForAppleScript(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Returns an AppleScript statement to schedule an item
    /// Uses the `schedule <item> for <date>` command (activation date is read-only)
    /// - Parameters:
    ///   - varName: The AppleScript variable name (e.g., "newTodo", "targetTodo")
    ///   - when: The schedule value ("today", "tomorrow", "anytime", "someday", or a date string)
    /// - Returns: Complete AppleScript statement for scheduling
    private func getWhenStatement(_ varName: String, _ when: String) -> String {
        switch when.lowercased() {
        case "today":
            // Schedule for current date
            return "schedule \(varName) for (current date)"
        case "tomorrow":
            // Schedule for tomorrow
            return "schedule \(varName) for ((current date) + 1 * days)"
        case "evening":
            // Note: Things 3 "evening" is a UI concept, schedule for today
            return "schedule \(varName) for (current date)"
        case "anytime":
            // Move to Anytime list (clears schedule)
            return "move \(varName) to \(getListReference("Anytime"))"
        case "someday":
            // Move to Someday list
            return "move \(varName) to \(getListReference("Someday"))"
        default:
            // Try to parse as date and schedule
            if let date = parseDate(when) {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd"
                return "schedule \(varName) for date \"\(formatter.string(from: date))\""
            }
            // Fallback: try original string as date
            return "schedule \(varName) for date \"\(when)\""
        }
    }

    /// Formats a date string for AppleScript's `date "..."` syntax
    /// Parses various date formats and outputs in a locale-independent format
    private func formatDateForAppleScript(_ dateString: String) -> String {
        if let date = parseDate(dateString) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return "date \"\(formatter.string(from: date))\""
        }
        // Fallback: use original string (may fail for non-English locales)
        return "date \"\(dateString)\""
    }

    /// Parse date string using NSDataDetector (locale-independent, supports all system languages)
    private func parseDate(_ string: String) -> Date? {
        // 1. Try ISO8601 format first (most reliable)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        if let date = isoFormatter.date(from: string) {
            return date
        }

        // 2. Try common formats with POSIX locale (for explicit formats like yyyy-MM-dd)
        let commonFormats = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy", "dd/MM/yyyy"]
        for format in commonFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }

        // 3. Try current locale's natural date parsing (handles all localized formats)
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale.current
        for style in [DateFormatter.Style.short, .medium, .long, .full] {
            localFormatter.dateStyle = style
            localFormatter.timeStyle = .none
            if let date = localFormatter.date(from: string) {
                return date
            }
        }

        // 4. Use NSDataDetector as final fallback (intelligent date detection)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(string.startIndex..., in: string)
        if let match = detector.firstMatch(in: string, options: [], range: range),
           let date = match.date {
            return date
        }

        return nil
    }

    private func parseTodosFromOutput(_ output: String) -> [Todo] {
        guard !output.isEmpty else { return [] }

        let todoStrings = output.components(separatedBy: "###").filter { !$0.isEmpty }
        return todoStrings.compactMap { todoString -> Todo? in
            let parts = todoString.components(separatedBy: "|||")
            guard parts.count >= 10 else { return nil }

            return Todo(
                id: parts[0],
                name: parts[1],
                notes: parts[2].isEmpty ? nil : parts[2],
                status: parts[3],
                tagNames: parts[4].isEmpty ? [] : parts[4].components(separatedBy: ", "),
                dueDate: parts[5].isEmpty ? nil : parts[5],
                scheduledDate: parts[6].isEmpty ? nil : parts[6],
                completionDate: parts[7].isEmpty ? nil : parts[7],
                projectName: parts[8].isEmpty ? nil : parts[8],
                areaName: parts[9].isEmpty ? nil : parts[9]
            )
        }
    }

    private func parseProjectsFromOutput(_ output: String) -> [Project] {
        guard !output.isEmpty else { return [] }

        let projectStrings = output.components(separatedBy: "###").filter { !$0.isEmpty }
        return projectStrings.compactMap { projectString -> Project? in
            let parts = projectString.components(separatedBy: "|||")
            guard parts.count >= 7 else { return nil }

            return Project(
                id: parts[0],
                name: parts[1],
                notes: parts[2].isEmpty ? nil : parts[2],
                status: parts[3],
                tagNames: parts[4].isEmpty ? [] : parts[4].components(separatedBy: ", "),
                areaName: parts[5].isEmpty ? nil : parts[5],
                todoCount: Int(parts[6]) ?? 0
            )
        }
    }

    private func parseAreasFromOutput(_ output: String) -> [Area] {
        guard !output.isEmpty else { return [] }

        let areaStrings = output.components(separatedBy: "###").filter { !$0.isEmpty }
        return areaStrings.compactMap { areaString -> Area? in
            let parts = areaString.components(separatedBy: "|||")
            guard parts.count >= 3 else { return nil }

            return Area(
                id: parts[0],
                name: parts[1],
                tagNames: parts[2].isEmpty ? [] : parts[2].components(separatedBy: ", ")
            )
        }
    }

    private func parseTagsFromOutput(_ output: String) -> [Tag] {
        guard !output.isEmpty else { return [] }

        let tagStrings = output.components(separatedBy: "###").filter { !$0.isEmpty }
        return tagStrings.compactMap { tagString -> Tag? in
            let parts = tagString.components(separatedBy: "|||")
            guard parts.count >= 2 else { return nil }

            return Tag(
                id: parts[0],
                name: parts[1],
                parentTagName: parts.count >= 3 && !parts[2].isEmpty ? parts[2] : nil
            )
        }
    }

    // MARK: - Batch Operations

    public struct BatchResult: Codable {
        public let total: Int
        public let succeeded: Int
        public let failed: Int
        public let results: [BatchItemResult]

        public init(total: Int, succeeded: Int, failed: Int, results: [BatchItemResult]) {
            self.total = total
            self.succeeded = succeeded
            self.failed = failed
            self.results = results
        }
    }

    public struct BatchItemResult: Codable {
        public let index: Int
        public let success: Bool
        public let id: String?
        public let error: String?

        public init(index: Int, success: Bool, id: String?, error: String?) {
            self.index = index
            self.success = success
            self.id = id
            self.error = error
        }
    }

    public func createTodosBatch(
        items: [[String: Any]]
    ) async -> BatchResult {
        var results: [BatchItemResult] = []
        var succeeded = 0
        var failed = 0

        for (index, item) in items.enumerated() {
            do {
                let name = item["name"] as? String ?? ""
                guard !name.isEmpty else {
                    throw ThingsError.invalidParameter("name is required at index \(index)")
                }

                // Handle explicit null pattern: empty string means no project
                let projectName: String? = {
                    if let p = item["project"] as? String, !p.isEmpty { return p }
                    return nil
                }()

                let todo = try await addTodo(
                    name: name,
                    notes: item["notes"] as? String,
                    dueDate: item["due_date"] as? String,
                    tags: item["tags"] as? [String],
                    listName: item["list"] as? String,
                    projectName: projectName,
                    areaName: item["area"] as? String,
                    when: item["when"] as? String
                )
                results.append(BatchItemResult(index: index, success: true, id: todo.id, error: nil))
                succeeded += 1
            } catch {
                results.append(BatchItemResult(index: index, success: false, id: nil, error: error.localizedDescription))
                failed += 1
            }
        }

        return BatchResult(total: items.count, succeeded: succeeded, failed: failed, results: results)
    }

    public func completeTodosBatch(ids: [String], completed: Bool = true) async -> BatchResult {
        var results: [BatchItemResult] = []
        var succeeded = 0
        var failed = 0

        for (index, id) in ids.enumerated() {
            do {
                try await completeTodo(id: id, completed: completed)
                results.append(BatchItemResult(index: index, success: true, id: id, error: nil))
                succeeded += 1
            } catch {
                results.append(BatchItemResult(index: index, success: false, id: id, error: error.localizedDescription))
                failed += 1
            }
        }

        return BatchResult(total: ids.count, succeeded: succeeded, failed: failed, results: results)
    }

    public func deleteTodosBatch(ids: [String]) async -> BatchResult {
        var results: [BatchItemResult] = []
        var succeeded = 0
        var failed = 0

        for (index, id) in ids.enumerated() {
            do {
                try await deleteTodo(id: id)
                results.append(BatchItemResult(index: index, success: true, id: id, error: nil))
                succeeded += 1
            } catch {
                results.append(BatchItemResult(index: index, success: false, id: id, error: error.localizedDescription))
                failed += 1
            }
        }

        return BatchResult(total: ids.count, succeeded: succeeded, failed: failed, results: results)
    }

    public func moveTodosBatch(ids: [String], toList: String? = nil, toProject: String? = nil) async -> BatchResult {
        var results: [BatchItemResult] = []
        var succeeded = 0
        var failed = 0

        for (index, id) in ids.enumerated() {
            do {
                try await moveTodo(id: id, toList: toList, toProject: toProject)
                results.append(BatchItemResult(index: index, success: true, id: id, error: nil))
                succeeded += 1
            } catch {
                results.append(BatchItemResult(index: index, success: false, id: id, error: error.localizedDescription))
                failed += 1
            }
        }

        return BatchResult(total: ids.count, succeeded: succeeded, failed: failed, results: results)
    }

    public func updateTodosBatch(updates: [[String: Any]]) async -> BatchResult {
        var results: [BatchItemResult] = []
        var succeeded = 0
        var failed = 0

        for (index, update) in updates.enumerated() {
            do {
                guard let id = update["id"] as? String else {
                    throw ThingsError.invalidParameter("id is required at index \(index)")
                }

                try await updateTodo(
                    id: id,
                    name: update["name"] as? String,
                    notes: update["notes"] as? String,
                    dueDate: update["due_date"] as? String,
                    tags: update["tags"] as? [String],
                    when: update["when"] as? String
                )
                results.append(BatchItemResult(index: index, success: true, id: id, error: nil))
                succeeded += 1
            } catch {
                let id = update["id"] as? String
                results.append(BatchItemResult(index: index, success: false, id: id, error: error.localizedDescription))
                failed += 1
            }
        }

        return BatchResult(total: updates.count, succeeded: succeeded, failed: failed, results: results)
    }

    // MARK: - Checklist Operations (via URL Scheme)

    /// Add checklist items to an existing to-do (appends to existing checklist)
    /// - Note: Due to Things 3 API limitations, this can only ADD items. It cannot read or mark items as complete.
    public func addChecklistItems(todoId: String, items: [String]) throws {
        guard !items.isEmpty else {
            throw ThingsError.invalidParameter("items array cannot be empty")
        }

        let itemsString = items.joined(separator: "\n")
        guard let encodedItems = itemsString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw ThingsError.urlSchemeError("Failed to encode checklist items")
        }

        var urlString = "things:///update?id=\(todoId)&append-checklist-items=\(encodedItems)"

        // Add auth token if configured
        if let token = authToken, !token.isEmpty {
            urlString += "&auth-token=\(token)"
        }

        guard let url = URL(string: urlString) else {
            throw ThingsError.urlSchemeError("Failed to create URL")
        }

        NSWorkspace.shared.open(url)
    }

    /// Set (replace) all checklist items for a to-do
    /// - Warning: This will REPLACE all existing checklist items!
    public func setChecklistItems(todoId: String, items: [String]) throws {
        let itemsString = items.joined(separator: "\n")
        guard let encodedItems = itemsString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw ThingsError.urlSchemeError("Failed to encode checklist items")
        }

        var urlString = "things:///update?id=\(todoId)&checklist-items=\(encodedItems)"

        // Add auth token if configured
        if let token = authToken, !token.isEmpty {
            urlString += "&auth-token=\(token)"
        }

        guard let url = URL(string: urlString) else {
            throw ThingsError.urlSchemeError("Failed to create URL")
        }

        NSWorkspace.shared.open(url)
    }
}
