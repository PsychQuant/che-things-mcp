# Things 3 AppleScript Reference

## How to View the AppleScript Dictionary

The definitive source for Things 3 AppleScript syntax is its **AppleScript Dictionary**. Always consult this when developing AppleScript integrations.

### Method 1: Script Editor (GUI)

```bash
open -a "Script Editor"
```
Then: **File > Open Dictionary > Things3**

### Method 2: Command Line Export

```bash
# Export full dictionary as XML
sdef /Applications/Things3.app > things3-applescript-dictionary.xml

# Quick reference - view to do properties
sdef /Applications/Things3.app | grep -A 50 'class name="to do"'

# Quick reference - view schedule command
sdef /Applications/Things3.app | grep -A 20 'command name="schedule"'

# View all list IDs
osascript -e 'tell application "Things3" to get id of every list'
```

---

## Complete Class Reference

### `to do` Class

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `id` | text | r | Unique identifier |
| `name` | text | rw | Name of the to do |
| `notes` | text | rw | Notes/description |
| `creation date` | date | rw | Creation date |
| `modification date` | date | rw | Last modified date |
| `due date` | date | rw | Due date |
| `activation date` | date | **r** | Scheduled date (**READ-ONLY!**) |
| `completion date` | date | rw | Completion date |
| `cancellation date` | date | rw | Cancellation date |
| `status` | status | rw | open/completed/canceled |
| `tag names` | text | rw | Comma-separated tags |
| `project` | project | rw | Parent project |
| `area` | area | rw | Parent area |
| `contact` | contact | rw | Assigned contact |

**Supported Commands:**
- `move` - Move to another list
- `schedule` - Schedule for a date
- `show` - Show in Things UI
- `edit` - Open edit dialog

### `project` Class (inherits from `to do`)

Contains `to do` elements as children.

### `area` Class (inherits from `list`)

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `tag names` | text | rw | Comma-separated tags |
| `collapsed` | boolean | rw | Is area collapsed? |

### `list` Class

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `id` | text | r | Unique identifier |
| `name` | text | rw | List name |

### `tag` Class

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `id` | text | r | Unique identifier |
| `name` | text | rw | Tag name |
| `keyboard shortcut` | text | rw | Keyboard shortcut |
| `parent tag` | tag | rw | Parent tag |

### `status` Enumeration

| Value | Code | Description |
|-------|------|-------------|
| `open` | tdio | To do is open |
| `completed` | tdcm | To do has been completed |
| `canceled` | tdcl | To do has been canceled |

---

## Command Reference

### `schedule` Command

**IMPORTANT:** `activation date` is **read-only**. Use the `schedule` command instead.

```xml
<command name="schedule" code="THGSschd">
    <direct-parameter type="specifier"/>  <!-- the to do -->
    <parameter name="for" type="date" optional="no"/>  <!-- REQUIRED -->
</command>
```

**Usage:**
```applescript
tell application "Things3"
    set myTodo to to do id "abc123"
    schedule myTodo for (current date)
    schedule myTodo for ((current date) + 1 * days)
    schedule myTodo for date "2026-01-20"
end tell
```

**Wrong:**
```applescript
set activation date of myTodo to (current date)  -- FAILS! Read-only property
```

### `move` Command

```xml
<command name="move" code="THGSmvtl">
    <direct-parameter type="specifier"/>  <!-- the to do(s) -->
    <parameter name="to" type="list"/>    <!-- target list -->
</command>
```

**Usage:**
```applescript
tell application "Things3"
    move to do id "abc123" to list id "TMNextListSource"
    move to do id "abc123" to project "My Project"
end tell
```

### `show quick entry panel` Command

```xml
<command name="show quick entry panel" code="THGSsqep">
    <parameter name="with autofill" type="boolean" optional="yes"/>
    <parameter name="with properties" type="item details" optional="yes"/>
</command>
```

**`item details` Record Type:**
- `name` (text)
- `notes` (text)
- `due date` (date)
- `tag names` (text)

### `make` Command (Standard Suite)

```applescript
make new to do with properties {name:"Task", notes:"Notes"} in list id "TMInboxListSource"
make new project with properties {name:"Project"} in area "Work"
```

### `delete` Command (Standard Suite)

```applescript
delete to do id "abc123"
delete project id "xyz789"
```

---

## List IDs (Locale-Independent)

Retrieved via: `osascript -e 'tell application "Things3" to get id of every list'`

| List Name | Internal ID |
|-----------|-------------|
| Inbox | `TMInboxListSource` |
| Today | `TMTodayListSource` |
| Upcoming | `TMCalendarListSource` |
| Anytime | `TMNextListSource` |
| Someday | `TMSomedayListSource` |
| Logbook | `TMLogbookListSource` |

**Usage:**
```applescript
tell application "Things3"
    get to dos of list id "TMTodayListSource"
    move myTodo to list id "TMNextListSource"
end tell
```

---

## Common Pitfalls

### 1. Locale Issues
Never use localized list names like "今天" or "Today" - use `list id` syntax:
```applescript
-- Wrong (depends on language)
get to dos of list "Today"

-- Correct (works in all languages)
get to dos of list id "TMTodayListSource"
```

### 2. Read-Only Properties
Always check `access="r"` vs `access="rw"` in the dictionary:
```applescript
-- activation date is READ-ONLY, use schedule command instead
schedule myTodo for (current date)
```

### 3. Date Parsing
AppleScript date parsing depends on system locale. Always use ISO format:
```applescript
-- Preferred (locale-independent)
set due date of myTodo to date "2026-01-20"

-- May fail on non-English systems
set due date of myTodo to date "January 20, 2026"
```

### 4. Status Values
Use lowercase status names:
```applescript
set status of myTodo to open      -- correct
set status of myTodo to completed -- correct
set status of myTodo to canceled  -- correct
```

---

## Swift Implementation Notes

When implementing AppleScript calls in Swift:

1. **Date Handling**: Use `parseDate()` to handle all localized date formats, then output in `yyyy-MM-dd` format
2. **String Escaping**: Escape `\` and `"` for AppleScript strings
3. **Execution thread**: Run every script through `AppleScriptRunner.run`, which executes `NSAppleScript` on the main thread. Apple lists `NSAppleScript` as main-thread only; running it on a background queue made Apple Events stall until the 120 s timeout (#5). Do not move it back to a background queue to "avoid blocking": scripts are serialized on the main queue instead, see #8.
4. **List References**: Use `getListReference()` helper for locale-independent list access
