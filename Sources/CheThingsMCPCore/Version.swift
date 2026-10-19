import Foundation

/// Centralized version management for CheThingsMCP
/// This is the single source of truth for version information
public enum AppVersion {
    /// Current version - update this when releasing new versions
    public static let current = "1.7.1"

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
            -v, --version      Print version information
            -h, --help         Print this help message
            --setup            Ask macOS for permission to control Things 3. Run it once in
                               Terminal.app with Things 3 open.
            --print-tcc-path   Print this binary's path, bundle identifier and the Automation
                               status for Things 3. Never shows a dialog.

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
            - Automation permission to control Things 3
              (System Settings > Privacy & Security > Automation). If a tool call fails with
              "Not authorized to send Apple events", run `CheThingsMCP --setup` once.

        For more information: https://github.com/kiki830621/che-things-mcp
        """
    }
}
