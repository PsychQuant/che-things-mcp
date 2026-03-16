# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.2] - 2026-03-16

### Fixed
- **`add_project` with area parameter**: Fixed AppleScript error `-10000` when creating a project with an area. Things 3's `make` command does not support `in area "..."` for projects — now uses create-then-move pattern (same as `add_todo`)

---

## [1.6.1] - 2026-01-19

### Added
- **Centralized version management**: New `Version.swift` as single source of truth
- **CLI support**: `--version` / `-v` and `--help` / `-h` command line arguments

### Technical
- `AppVersion.current` replaces hardcoded version strings
- Consistent version across CLI, MCP server registration, and documentation

---

## [1.6.0] - 2026-01-16

### Changed
- **`project` parameter is now required** for `add_todo` and `create_todos_batch`
- Implements **Explicit Null Pattern**: Use empty string `""` to explicitly indicate no project assignment
- This prevents AI from accidentally forgetting to assign tasks to projects

### Technical
- Empty string for `project` is treated as `nil` internally
- Added validation in both `handleAddTodo` and `createTodosBatch`
- See: `docs/AI_ERA_API_DESIGN.md` for the design principle

---

## [1.5.0] - 2026-01-16

### Added
- **`area` parameter for `add_todo`**: To-dos can now be placed directly into an Area without being in a project
- **`area` parameter for `create_todos_batch`**: Batch creation now supports area assignment
- This aligns with the AI_ERA_API_DESIGN principle: consistent API across similar operations

### Changed
- `add_todo` tool now accepts optional `area` parameter (same as `add_project`)
- `create_todos_batch` tool items now accept optional `area` field

### Fixed
- API inconsistency: `add_project` had `area` parameter but `add_todo` didn't

## [1.4.0] - 2026-01-16

### Added
- **11 new tools** for complete Things 3 API coverage (37 → 47 tools)
- Area CRUD operations:
  - `add_area` - Create a new area
  - `update_area` - Update an existing area
  - `delete_area` - Delete an area
- Tag CRUD operations with hierarchical support:
  - `add_tag` - Create a new tag (supports parent tag for hierarchy)
  - `update_tag` - Update tag name or parent
  - `delete_tag` - Delete a tag
- Cancel operations:
  - `cancel_todo` - Cancel a to-do (shows as struck-through)
  - `cancel_project` - Cancel a project (shows as struck-through)
- Edit operations:
  - `edit_todo` - Open to-do in Things 3 edit view
  - `edit_project` - Open project in Things 3 edit view
- Utility:
  - `log_completed_now` - Move completed items to Logbook immediately

### Changed
- `get_tags` now returns parent tag information for hierarchical tags

## [1.3.1] - 2026-01-15

### Fixed
- **activation date handling**: Fixed read-only property issue by using `schedule` command instead of direct property assignment
- **add_todo + list parameter**: Fixed by creating todo first, then moving to target list
- **add_todo + project parameter**: Fixed by creating todo first, then setting project property
- **date formatting**: Improved AppleScript date compatibility for various locales

### Added
- Comprehensive `docs/applescript-reference.md` documenting Things 3 AppleScript API

### Technical Details
- Discovered via AppleScript Dictionary (`sdef /Applications/Things3.app`) that:
  - `activation date` is read-only (`access="r"`)
  - Things 3's `make` command does NOT support `in list id` or `in project` syntax
  - Must use `schedule <todo> for <date>` for scheduling
  - Must create todo first, then move/set project

## [1.2.2] - 2026-01-15

### Changed
- **CLI syntax update**: Updated `claude mcp add` commands with correct `--scope user --transport stdio` syntax
- Documentation improvements

## [1.2.1] - 2026-01-15

### Added
- MCP protocol tests and integration tests
- Updated installation guide to recommend `~/bin/` over cloud-synced folders

### Changed
- Documentation improvements for installation

## [1.2.0] - 2026-01-14

### Changed
- **Performance optimization**: Batch property fetching (29x faster)
- **MCP fix**: Fixed event loop blocking - AppleScript now runs on background thread via DispatchQueue

## [1.1.1] - 2026-01-13

### Changed
- Simplified AppleScript syntax: use `list id` instead of `first list whose source type is`

## [1.1.0] - 2026-01-12

### Fixed
- **Complete i18n support**: Fixed all localization issues for built-in lists (Inbox, Today, Upcoming, etc.) using Things3 internal source types

## [1.0.0] - 2026-01-11

### Added
- **First stable release**: 37 tools with full i18n support
- Fixed localization bug for non-English systems

## [0.4.1] - 2026-01-10

### Fixed
- Delete operations failing on localized Things3 (Chinese, Japanese, etc.)

## [0.4.0] - 2026-01-09

### Added
- Auth token support for URL Scheme operations
- 2 new tools: `set_auth_token`, `check_auth_status`

## [0.3.0] - 2026-01-08

### Added
- 7 new tools: batch operations (5) and checklist support (2)
  - `create_todos_batch`
  - `complete_todos_batch`
  - `delete_todos_batch`
  - `move_todos_batch`
  - `update_todos_batch`
  - `add_checklist_items`
  - `set_checklist_items`

### Changed
- Improved error messages with specific IDs
- Added unit tests

## [0.2.0] - 2026-01-07

### Added
- 13 new tools:
  - Areas & Tags: `get_areas`, `get_tags`
  - Move operations: `move_todo`, `move_project`
  - UI controls: `show_todo`, `show_project`, `show_list`, `show_quick_entry`
  - Utility: `empty_trash`, `get_selected_todos`
  - Advanced queries: `get_todos_in_project`, `get_todos_in_area`, `get_projects_in_area`

## [0.1.0] - 2026-01-06

### Added
- Initial release with 15 tools
- List access: `get_inbox`, `get_today`, `get_upcoming`, `get_anytime`, `get_someday`, `get_logbook`, `get_projects`
- Task operations: `add_todo`, `update_todo`, `complete_todo`, `delete_todo`, `search_todos`
- Project operations: `add_project`, `update_project`, `delete_project`

---

## Tool Count by Version

| Version | Total Tools | New Tools |
|---------|-------------|-----------|
| 1.6.1   | 47          | CLI support (--version, --help) |
| 1.6.0   | 47          | Explicit Null Pattern for project param |
| 1.5.0   | 47          | Area support for add_todo |
| 1.4.0   | 47          | +11 (area, tag, cancel, edit, log) |
| 1.3.1   | 37          | AppleScript integration fixes |
| 1.2.2   | 37          | Documentation update |
| 1.2.1   | 37          | Tests and documentation |
| 1.2.0   | 37          | Performance optimization |
| 1.1.1   | 37          | AppleScript simplification |
| 1.1.0   | 37          | i18n fixes |
| 1.0.0   | 37          | First stable release |
| 0.4.1   | 37          | Localization fix |
| 0.4.0   | 37          | +2 (auth token tools) |
| 0.3.0   | 35          | +7 (batch + checklist) |
| 0.2.0   | 28          | +13 (areas, tags, UI, queries) |
| 0.1.0   | 15          | Initial release |
