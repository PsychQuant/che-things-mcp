import Foundation

/// Centralized version management for CheThingsMCP
/// This is the single source of truth for version information
public enum AppVersion {
    /// Current version - update this when releasing new versions
    public static let current = "1.6.2"

    /// Application name (used in MCP server registration)
    public static let name = "che-things-mcp"

    /// Display name for human-readable output
    public static let displayName = "Things 3 MCP Server"

    /// Version string for --version output
    public static var versionString: String {
        "CheThingsMCP \(current)"
    }

    /// Help message for --help output
    public static var helpMessage: String {
        """
        \(displayName) v\(current)

        An MCP (Model Context Protocol) server for Things 3 task management.

        USAGE:
            CheThingsMCP [OPTIONS]

        OPTIONS:
            -v, --version    Print version information
            -h, --help       Print this help message

        DESCRIPTION:
            This MCP server provides 47 tools for managing Things 3:
            - Task CRUD operations (add, update, complete, delete, search)
            - Project and Area management
            - Tag management with hierarchy support
            - Batch operations for efficiency
            - Checklist management
            - UI control (show, quick entry)

        INSTALLATION:
            claude mcp add --scope user che-things-mcp -- ~/bin/CheThingsMCP

        REQUIREMENTS:
            - macOS 13.0+
            - Things 3 app installed
            - Accessibility permission for AppleScript

        For more information: https://github.com/kiki830621/che-things-mcp
        """
    }
}
