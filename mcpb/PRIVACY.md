# Privacy Policy for che-things-mcp

**Last Updated: January 14, 2026**

## Overview

che-things-mcp is a local MCP (Model Context Protocol) server that provides Claude with access to your Things 3 task management app. This extension operates entirely on your local machine and does not transmit any data to external servers.

## Data Access

This extension accesses the following data on your Mac:

### Things 3 Data
- **To-do information**: Title, notes, status, due dates, scheduled dates, completion dates
- **Project information**: Project names, notes, status, area assignments
- **Organizational data**: Tags, areas, and list assignments (Inbox, Today, Upcoming, etc.)

## Data Processing

### Local Processing Only
- **All data processing occurs locally** on your Mac
- **No data is transmitted** to Anthropic, the developer, or any third-party servers
- **No data is stored** by this extension beyond the current session

### How Data Flows
1. Claude sends a request to the local MCP server (e.g., "get today's tasks")
2. The MCP server executes AppleScript commands to query Things 3
3. Results are returned to Claude through the local MCP protocol
4. Data never leaves your computer

## Permissions

On first use, macOS will request permission for this extension to control Things 3:

| Permission | Purpose |
|------------|---------|
| **Automation** | Required to send Apple events to Things 3 (it is not the Accessibility permission) |

You can manage these permissions in **System Settings → Privacy & Security → Automation**.

## Data Retention

- This extension **does not store any task or project data**
- All operations are performed in real-time through AppleScript
- No logs, caches, or copies of your data are created by this extension

## Third-Party Services

### Things Cloud
If you use Things Cloud to sync your data across devices:
- Things Cloud synchronization is handled entirely by the Things 3 app
- This extension does not interact with Things Cloud directly
- Synced data is subject to [Cultured Code's Privacy Policy](https://culturedcode.com/things/privacy/)

This extension only accesses task data stored locally in Things 3 on your Mac.

## Security

- The extension runs with the same permissions as the Claude Desktop application
- Communication between Claude and the MCP server uses stdio (standard input/output) on your local machine
- No network connections are made by this extension

## Open Source

This extension is open source. You can review the complete source code at:
https://github.com/kiki830621/che-things-mcp

## Platform & Software Requirements

- **macOS only**: This extension uses AppleScript, which is only available on macOS
- **Things 3 required**: You must have Things 3 installed from the Mac App Store

## Contact

For privacy concerns or questions, please:
- Open an issue on [GitHub](https://github.com/kiki830621/che-things-mcp/issues)
- Contact the developer: [@kiki830621](https://github.com/kiki830621)

## Changes to This Policy

Any changes to this privacy policy will be posted to the GitHub repository and reflected in the "Last Updated" date above.
