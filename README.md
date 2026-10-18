# che-things-mcp

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![MCP](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io/)

**Things 3 MCP server** - Native AppleScript integration for comprehensive task management.

---

## Features

- **47 tools** for comprehensive Things 3 management
- **Native AppleScript** integration for reliable data access
- **Universal Binary** supporting both Apple Silicon and Intel Macs
- **Zero dependencies** at runtime - just the binary

---

## Quick Start

### For Claude Desktop

#### Option A: MCPB One-Click Install (Recommended)

Download the latest `.mcpb` file from [Releases](https://github.com/kiki830621/che-things-mcp/releases) and double-click to install.

#### Option B: Manual Configuration

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "che-things-mcp": {
      "command": "/Users/YOUR_USERNAME/bin/CheThingsMCP"
    }
  }
}
```

### For Claude Code (CLI)

```bash
# Create ~/bin if it doesn't exist
mkdir -p ~/bin

# Download the latest release
curl -L https://github.com/kiki830621/che-things-mcp/releases/latest/download/CheThingsMCP -o ~/bin/CheThingsMCP
chmod +x ~/bin/CheThingsMCP

# Add to Claude Code
# --scope user    : available across all projects (stored in ~/.claude.json)
# --transport stdio: local binary execution via stdin/stdout
# --              : separator between claude options and the command
claude mcp add --scope user --transport stdio che-things-mcp -- ~/bin/CheThingsMCP
```

### Build from Source

```bash
git clone https://github.com/kiki830621/che-things-mcp.git
cd che-things-mcp
swift build -c release

# Copy binary to ~/bin
cp .build/release/CheThingsMCP ~/bin/
```

> **💡 Tip:** Always install the binary to a local directory like `~/bin/`. Avoid placing it in cloud-synced folders (Dropbox, iCloud, OneDrive) as file sync operations can cause MCP connection timeouts.

### Permission: Automation (Apple Events)

Things 3 is controlled through Apple Events, so macOS asks for the **Automation** permission (System Settings > Privacy & Security > Automation). This is *not* the Accessibility permission.

If a tool call fails with `Not authorized to send Apple events to Things3`:

1. Open Things 3.
2. Run `~/bin/CheThingsMCP --setup` in **Terminal.app** (not over SSH) and click **Allow**.
3. Open System Settings > Privacy & Security > Automation and check that the app that launches this server (Claude Desktop, Claude Code or your editor) is allowed to control Things 3. A grant given to Terminal does not automatically cover those apps. If there is no entry for the app, make one read-only tool call from it so macOS can ask.
4. `~/bin/CheThingsMCP --print-tcc-path` prints the binary path, bundle identifier and the current status without showing any dialog. It reports the status of the context it runs in (for example Terminal), which is not necessarily the app that launches the server.

Since v1.7.0 the release binary is signed with a Developer ID certificate and notarized, and it carries an embedded Info.plist with the usage description and the `com.apple.security.automation.apple-events` entitlement (see issues #1 and #4).

---

## Authentication

Some operations (like checklist management) require a Things3 auth token.

### Getting your token

1. Open **Things3** → **Settings** (⌘,)
2. Go to **General** → **Enable Things URLs**
3. Click **Manage** and copy your token

### Configuration

**Claude Desktop** (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "che-things-mcp": {
      "command": "/Users/YOUR_USERNAME/bin/CheThingsMCP",
      "env": {
        "THINGS3_AUTH_TOKEN": "your-token-here"
      }
    }
  }
}
```

**Claude Code**:

```bash
claude mcp add --scope user --transport stdio che-things-mcp \
  --env THINGS3_AUTH_TOKEN=your-token \
  -- ~/bin/CheThingsMCP
```

You can also set the token at runtime using the `set_auth_token` tool.

---

## All 47 Tools

<details>
<summary><b>List Access (7)</b></summary>

| Tool | Description |
|------|-------------|
| `get_inbox` | Get all to-dos in the Inbox |
| `get_today` | Get all to-dos scheduled for Today |
| `get_upcoming` | Get all to-dos in the Upcoming list |
| `get_anytime` | Get all to-dos in the Anytime list |
| `get_someday` | Get all to-dos in the Someday list |
| `get_logbook` | Get completed to-dos from the Logbook |
| `get_projects` | Get all projects with details |

</details>

<details>
<summary><b>Task Operations (5)</b></summary>

| Tool | Description |
|------|-------------|
| `add_todo` | Create a new to-do with optional scheduling |
| `update_todo` | Update an existing to-do |
| `complete_todo` | Mark a to-do as completed or incomplete |
| `delete_todo` | Delete a to-do (moves to Trash) |
| `search_todos` | Search for to-dos by name or notes |

</details>

<details>
<summary><b>Project Operations (3)</b></summary>

| Tool | Description |
|------|-------------|
| `add_project` | Create a new project |
| `update_project` | Update an existing project |
| `delete_project` | Delete a project (moves to Trash) |

</details>

<details>
<summary><b>Area Operations (4)</b></summary>

| Tool | Description |
|------|-------------|
| `get_areas` | Get all areas |
| `add_area` | Create a new area |
| `update_area` | Update an existing area |
| `delete_area` | Delete an area |

</details>

<details>
<summary><b>Tag Operations (4)</b></summary>

| Tool | Description |
|------|-------------|
| `get_tags` | Get all tags (includes parent tag info) |
| `add_tag` | Create a new tag with optional parent |
| `update_tag` | Update tag name or parent |
| `delete_tag` | Delete a tag |

> 💡 **Hierarchical Tags**: Tags can be nested using the `parent_tag` parameter. For example, create a "Work" tag, then create "Meetings" with `parent_tag: "Work"` to get "Work → Meetings".

</details>

<details>
<summary><b>Move Operations (2)</b></summary>

| Tool | Description |
|------|-------------|
| `move_todo` | Move a to-do to a different list or project |
| `move_project` | Move a project to a different area |

</details>

<details>
<summary><b>UI Operations (4)</b></summary>

| Tool | Description |
|------|-------------|
| `show_todo` | Show a to-do in the Things 3 app |
| `show_project` | Show a project in the Things 3 app |
| `show_list` | Show a list in the Things 3 app |
| `show_quick_entry` | Open the Quick Entry panel |

</details>

<details>
<summary><b>Cancel Operations (2)</b></summary>

| Tool | Description |
|------|-------------|
| `cancel_todo` | Cancel a to-do (shows as struck-through) |
| `cancel_project` | Cancel a project (shows as struck-through) |

> 💡 **Cancel vs Delete**: Canceled items remain visible but struck-through. Use this for items you decided not to do but want to keep a record of.

</details>

<details>
<summary><b>Edit Operations (2)</b></summary>

| Tool | Description |
|------|-------------|
| `edit_todo` | Open to-do in Things 3 edit view |
| `edit_project` | Open project in Things 3 edit view |

</details>

<details>
<summary><b>Utility Operations (3)</b></summary>

| Tool | Description |
|------|-------------|
| `empty_trash` | Permanently delete all items in Trash |
| `get_selected_todos` | Get currently selected to-dos |
| `log_completed_now` | Move completed items to Logbook immediately |

</details>

<details>
<summary><b>Advanced Queries (3)</b></summary>

| Tool | Description |
|------|-------------|
| `get_todos_in_project` | Get all to-dos in a specific project |
| `get_todos_in_area` | Get all to-dos in a specific area |
| `get_projects_in_area` | Get all projects in a specific area |

</details>

<details>
<summary><b>Batch Operations (5)</b></summary>

| Tool | Description |
|------|-------------|
| `create_todos_batch` | Create multiple to-dos in a single operation |
| `complete_todos_batch` | Mark multiple to-dos as completed |
| `delete_todos_batch` | Delete multiple to-dos |
| `move_todos_batch` | Move multiple to-dos to a different list/project |
| `update_todos_batch` | Update multiple to-dos |

Batch operations return detailed results:
```json
{
  "total": 3,
  "succeeded": 2,
  "failed": 1,
  "results": [
    {"index": 0, "success": true, "id": "ABC123"},
    {"index": 1, "success": true, "id": "DEF456"},
    {"index": 2, "success": false, "error": "To-do not found with ID: XYZ"}
  ]
}
```

</details>

<details>
<summary><b>Checklist Operations (2)</b></summary>

| Tool | Description |
|------|-------------|
| `add_checklist_items` | Add checklist items to an existing to-do |
| `set_checklist_items` | Replace all checklist items in a to-do |

> ⚠️ **API Limitation**: Due to Things 3's AppleScript limitations, checklist operations can only **add** or **replace** items. Reading existing checklist items or marking individual items as complete is not supported.

</details>

<details>
<summary><b>Auth Token (2)</b></summary>

| Tool | Description |
|------|-------------|
| `set_auth_token` | Set the Things3 auth token at runtime |
| `check_auth_status` | Check if auth token is configured |

</details>

---

## Usage Examples

```
"Show me my tasks for today"
"Add a todo called 'Review quarterly report' with due date tomorrow"
"Find all tasks related to 'marketing'"
"Mark the 'Submit expense report' task as done"
"Move task 'Buy groceries' to the Someday list"
"Show me all my areas"
```

---

## Scheduling Options

When creating or updating tasks:

- `today` - Schedule for today
- `tomorrow` - Schedule for tomorrow
- `evening` - Schedule for this evening
- `anytime` - Available anytime (clears scheduling)
- `someday` - Defer indefinitely
- Date string (e.g., `2024-12-25`) - Schedule for specific date

---

## Requirements

- macOS 13.0 (Ventura) or later
- [Things 3](https://culturedcode.com/things/) installed
- Automation permission to control Things 3 (see [Permission: Automation](#permission-automation-apple-events))

---

## Privacy

This extension:
- Runs entirely locally on your Mac
- Does not transmit any data externally
- Only accesses Things 3 data through AppleScript
- See [PRIVACY.md](mcpb/PRIVACY.md) for full details

---

## Version History

| Version | Changes |
|---------|---------|
| v1.7.0 | **Automation permission.** A refused Apple Events call now returns an actionable error naming Things 3, the binary path and the fix, instead of the raw AppleScript message. New `--setup` and `--print-tcc-path`. Release binary is Developer ID signed and notarized, with an embedded Info.plist and the Apple Events entitlement. `--help` now names the Automation permission (it said Accessibility). |
| v1.6.2 | **Bug fix.** Fixed `add_project` failing with AppleScript error when `area` parameter is provided. Uses create-then-move pattern. |
| v1.6.1 | **Version management.** Centralized `Version.swift`, CLI `--version`/`--help` support. |
| v1.6.0 | **MCP SDK 0.11.0 upgrade.** |
| v1.4.0 | **11 new tools (37→47).** Full Area CRUD (`add_area`, `update_area`, `delete_area`), Tag CRUD with hierarchy (`add_tag`, `update_tag`, `delete_tag`), Cancel operations (`cancel_todo`, `cancel_project`), Edit operations (`edit_todo`, `edit_project`), and `log_completed_now`. |
| v1.3.1 | **AppleScript integration fixes.** Fixed `activation date` read-only issue, `add_todo` with list/project parameters. Added `docs/applescript-reference.md`. |
| v1.2.2 | **CLI syntax update.** Updated `claude mcp add` commands with correct `--scope user --transport stdio` syntax. |
| v1.2.1 | **Documentation & tests.** Updated installation guide to recommend `~/bin/` over cloud-synced folders. Added MCP protocol tests and integration tests. |
| v1.2.0 | **Performance optimization & MCP fix.** Batch property fetching (29x faster). Fixed MCP event loop blocking - AppleScript now runs on background thread via DispatchQueue. |
| v1.1.1 | Simplified AppleScript syntax: use `list id` instead of `first list whose source type is`. |
| v1.1.0 | **Complete i18n support.** Fixed all localization issues for built-in lists (Inbox, Today, Upcoming, etc.) using Things3 internal source types. |
| v1.0.0 | **First stable release.** 37 tools with full i18n support. Fixed localization bug for non-English systems. |
| v0.4.1 | Fixed delete operations failing on localized Things3 (Chinese, Japanese, etc.) |
| v0.4.0 | Added auth token support for URL Scheme operations. Added 2 new tools: `set_auth_token`, `check_auth_status`. |
| v0.3.0 | Added 7 new tools: batch operations (5) and checklist support (2). Improved error messages with specific IDs. Added unit tests. |
| v0.2.0 | Added 13 new tools: areas, tags, move operations, UI controls, utility operations, advanced queries |
| v0.1.0 | Initial release with 15 tools |

---

## Release Process (for maintainers)

### Signing & Notarization

Release binaries are signed with a Developer ID Application certificate (Hardened Runtime) and notarized with `notarytool`. On macOS 26 an ad-hoc signed binary cannot create the Automation grant, so the permission dialog may never appear.

**Prerequisites** (one-time):

1. Apple Developer Program enrollment and a Developer ID Application certificate in the login keychain. Check with `security find-identity -p codesigning -v`.
2. A `notarytool` keychain profile, created interactively so the password stays out of shell history:
   ```bash
   xcrun notarytool store-credentials che-things-mcp --apple-id <your-apple-id> --team-id <your-team-id>
   ```
3. Export your identity (the scripts have no defaults, so a fork never sees the maintainer's identity):
   ```bash
   export DEVELOPER_ID='Developer ID Application: <Your Name> (<TeamID>)'
   export NOTARY_PROFILE='che-things-mcp'
   ```

**Per release:**

```bash
make release-signed    # universal build -> sign -> entitlements check -> notarize -> .mcpb
```

`scripts/sign-and-notarize.sh` checks that the **signed** binary carries `com.apple.security.automation.apple-events` as `true` before it submits to Apple, so a wrong entitlements file fails in seconds instead of after the notarization wait.

**Verify the result:**

```bash
codesign -dv --verbose=2 mcpb/server/CheThingsMCP        # flags=0x10000(runtime), TeamIdentifier set
codesign -d --entitlements - mcpb/server/CheThingsMCP    # automation.apple-events = true
spctl -a -vvv -t install mcpb/server/CheThingsMCP        # accepted; source=Notarized Developer ID
```

**Local development:**

```bash
make install           # ad-hoc signed, dev only
make install-signed    # Developer ID + entitlements, NOT notarized, dev only (needs DEVELOPER_ID only)
```

Use `make install-signed` to try the permission flow on your own machine without waiting for notarization.

| Env var | Default | Purpose |
|---------|---------|---------|
| `DEVELOPER_ID` | unset | Signing identity. Unset: the build script skips signing with a warning |
| `NOTARY_PROFILE` | unset | `notarytool` keychain profile; required for `release-signed` |
| `ENTITLEMENTS` | `Sources/CheThingsMCP/Entitlements.plist` | Override the entitlements file |
| `SKIP_CODESIGN` | unset | `1` skips signing even when the certificate is present |
| `REQUIRE_CODESIGN` | unset | `1` fails fast when signing prerequisites are missing (set by `release-signed`) |

**Known limitation, no stapling:** `stapler staple` does not support raw Mach-O binaries, so Gatekeeper checks the notarization online on first launch.

**Upgrade trap:** copying a new binary over one that a running process holds open leaves a stale code-signature cache per inode and the kernel kills the new binary on exec. `make install` and the build script remove the old file first; do the same when installing by hand (`rm -f ~/bin/CheThingsMCP`).

**Troubleshooting:** `xcrun notarytool log <submission-id> --keychain-profile $NOTARY_PROFILE` shows Apple's reason for a rejection; the script prints the submission ID on every run.

---

## Related Projects

- [che-ical-mcp](https://github.com/kiki830621/che-ical-mcp) - MCP server for macOS Calendar & Reminders

---

## License

MIT

## Author

[Che Cheng](https://github.com/kiki830621)
