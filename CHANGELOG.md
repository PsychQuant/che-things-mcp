# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security
- **Tool arguments can no longer change the AppleScript a tool runs** (#9). Ids were inserted into scripts without escaping, and so were tags, date strings that do not parse, and list names that are not built-in lists; a `"` in any of them ended the string literal. Every tool that takes an id now refuses one outside `[A-Za-z0-9-]` (1–64 characters, the shape of a Things id) before building a script, and the other values are escaped. The URL-scheme checklist tools validate the id and encode the item text with a set that also encodes `& = + ? #`, so checklist text cannot add URL parameters.

### Fixed
- Names, notes or tags containing `|||` or `###` no longer shift fields when results are parsed: script output is now separated with control characters (#9).

### Tests
- Tools take an injectable script runner and URL opener, so id validation and escaping are tested without Things. `ScriptCompileTests` (`CHE_THINGS_COMPILE=1`) compiles every generated script with `osacompile`, which needs no Automation permission.

## [1.7.1] - 2026-10-19

### Fixed
- **`get_tags`, `get_areas` and `get_today` no longer stall for minutes** (#5). Every tool ran `NSAppleScript` on a background queue; Apple documents it as main-thread only. In the diagnosis experiment 4 of 5 runs of the same script on a background queue stalled for 120 s or more (2 returned `-1712 AppleEvent timed out`), while every main-thread run finished in 1–4 s. Scripts now run on the main thread. This is an empirical result on one machine; the mechanism is not fully established. Over MCP stdio, measured by several reviewers: `get_tags` 0.08–0.43 s (1.7.0: no answer within 150 s in 3 of 3 runs), `get_areas` 0.11–0.22 s, `get_today` (354 items) 0.9–7.3 s.
- Not fixed here: the six tools that still read one Apple Event per item (#6) stay slow; `search_todos` takes 40–90 s.

### Changed
- **Tool calls now run one at a time.** Scripts execute on the main queue in arrival order, so a long script delays every later tool call, writes included (measured: `get_tags` waited 37.6 s behind a 40.6 s `search_todos`; 1.7.0 answered in 9 s in the same situation). `ping` and `tools/list` are not affected. This is the trade-off for removing the stalls; options are in #8.
- `get_tags` and `get_areas` read each property for the whole collection in one Apple Event instead of one per property per item, and fall back to reading item by item if a bulk read comes back shorter than the id list. Output is unchanged (checked byte for byte against the old scripts on live data).
- Removed the unused `executeAppleScriptReturningList`.

### Tests
- `AppleScriptRunnerTests`: an AppleScriptObjC script reports the thread it runs on; result and error mapping are pinned. No Things 3 needed.
- `LiveThingsQueryTests`: byte-for-byte comparison of the tags and areas scripts with the old per-item scripts, and a check that the data includes a tag with a parent; runs only with `CHE_THINGS_LIVE=1` and Things 3 running.

---

## [1.7.0] - 2026-10-18

Refs #1, #4. Those issues stay open until the permission flow has been verified on a signed build.

### Added
- **`--setup`**: asks macOS for permission to control Things 3. Things 3 must be running; it refuses over SSH because the dialog cannot appear there.
- **`--print-tcc-path`**: prints the binary path, bundle identifier, macOS version and the Automation (Apple Events) status for Things 3, without showing any dialog. The status is read in the context the command runs in, which is not necessarily the app that launches the server.
- **Info.plist embedded in the binary** (`NSAppleEventsUsageDescription`) and **`Entitlements.plist`** (`com.apple.security.automation.apple-events`). Tests pin both files and pin `CFBundleVersion` and `mcpb/manifest.json` to `AppVersion.current`.

### Changed
- **A refused Apple Events call (`-1743`) returns an actionable error** naming Things 3, the binary path and the order of the fix, instead of the raw `AppleScript error: Not authorized to send Apple events to Things3.` The error number is checked first; the English message is only a fallback.
- **`--help` names the Automation permission.** It used to say "Accessibility permission for AppleScript", which pointed users at the wrong pane.
- README: new "Permission: Automation" section and a maintainer "Signing & Notarization" section. The install commands now remove the old binary before copying, to avoid the code-signature cache trap.
- `mcpb/PRIVACY.md` named the Accessibility permission; it now says Automation.

### Distribution
- Release binary signed with Developer ID and the Hardened Runtime, then notarized (`scripts/sign-and-notarize.sh`, `make release-signed`). The script checks that the **signed** binary carries the Apple Events entitlement as `true` before submitting to Apple.
- New `Makefile`: `install` (ad-hoc, dev only) and `install-signed` (Developer ID, not notarized, dev only).
- The build script removes the previous universal binary before `lipo` (inode-cache trap).
- `make release-signed` checks its environment first, then runs the tests, so a missing variable fails at once.
- The build script now builds both architectures in one invocation and locates the product with `--show-bin-path`. The old per-architecture paths (`.build/<arch>-apple-macosx/release`) only held leftovers from earlier toolchains, and under the `swiftbuild` build system both `--arch` values write to the same directory, so building them one after the other would have shipped an old binary under this version number. Every slice is also checked for the current version, the `--print-tcc-path` code and the embedded Info.plist before it is signed.
- `mcpb pack` now gets an explicit output path. Without it the bundle was written to `mcpb/mcpb.mcpb` (hidden by `.gitignore`) while the script reported, and the repository tracked, `mcpb/che-things-mcp.mcpb`, which would have stayed at the previous release. The script also checks that the binary inside the bundle is the one it just verified.
- The signing script ends the run only when notarytool reports `status: Accepted`, and keeps its temporary files in one private directory.
- Known limitation: stapling is skipped because raw Mach-O binaries do not support it. A file with a quarantine attribute (for example a browser download) is checked online by Gatekeeper on first launch; a binary fetched with `curl` is not.

### Notes
- What macOS does when the Apple Events entitlement is missing is inferred from Apple's documentation. It has been observed for Calendar in another project, not yet for Apple Events here.

---

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
