# Privacy Policy - che-things-mcp

## Overview

che-things-mcp is a local MCP (Model Context Protocol) server that provides task management capabilities through native AppleScript integration with Things 3. This document explains how your data is handled.

## Data Access

This MCP server accesses the following data on your Mac:

- **Tasks (To-dos)**: Read, create, update, delete tasks in Things 3
- **Projects**: Read, create, update, delete projects in Things 3
- **Areas**: Read area information for organization
- **Tags**: Read tag information for categorization
- **Checklists**: Add or replace checklist items (requires auth token)

## Data Storage

**No data is stored** outside of Things 3.

- All task and project data remains in your Things 3 app
- No data is written to external files, databases, or caches
- No data is transmitted to external servers or cloud services
- All operations are performed locally on your Mac via AppleScript

## Data Transmission

**No data is transmitted** to external services.

- che-things-mcp operates entirely offline
- All communication happens locally via MCP protocol (stdin/stdout)
- No network connections are made by this server
- No analytics, telemetry, or usage tracking

## Required Permissions

To function, che-things-mcp requires the following macOS permissions:

### Automation (AppleScript)
- **Purpose**: Control Things 3 application
- **Permission**: Allow automation of Things 3
- **Grant via**: System Settings > Privacy & Security > Automation

On first use, macOS will automatically prompt for this permission.

### Optional: Things 3 Auth Token
- **Purpose**: Enable URL Scheme operations (like checklist management)
- **How to get**: Things 3 → Settings → General → Enable Things URLs → Manage
- **Note**: The auth token is only used for local URL Scheme calls, never transmitted externally

## How to Grant Permissions

1. The first time you use a tool, macOS may prompt for **Automation** permission. If it does not, or a tool fails with "Not authorized to send Apple events", open Things 3 and run `CheThingsMCP --setup` in your terminal app
2. Click "Allow" to enable AppleScript control of Things 3
3. Alternatively, grant permissions manually:
   - Open **System Settings**
   - Navigate to **Privacy & Security** → **Automation**
   - Enable Things 3 access for the MCP server binary or Terminal/iTerm

## How to Revoke Access

If you wish to revoke access:

1. Open **System Settings**
2. Navigate to **Privacy & Security** → **Automation**
3. Disable Things 3 access for the MCP server

Alternatively, you can delete the MCP server binary from your system.

## Third-Party Services

This server does **not** connect to any third-party services:

- No cloud sync services
- No API calls to external servers
- No integration with non-local services
- No data sharing with third parties

## Open Source

che-things-mcp is open source software licensed under the MIT License. You can review the source code to verify these privacy practices:

- Repository: https://github.com/kiki830621/che-things-mcp
- All code is available for inspection
- No hidden functionality
- No obfuscated network calls

## Updates to This Policy

This privacy policy may be updated as the software evolves. Any changes will be documented in the project's CHANGELOG.

## Contact

For questions or concerns about privacy, please open an issue on the project's GitHub repository.

---

*Last updated: 2026-01-15*
*Version: 1.2.2*
