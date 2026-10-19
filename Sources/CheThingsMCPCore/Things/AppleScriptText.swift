import Foundation

/// Text that goes into AppleScript source. Every caller-controlled value passes through here
/// before it is interpolated into a script (issue 9): free text is escaped into a string
/// literal, ids are validated against the Things id character set.
enum AppleScriptText {

    /// Escapes `value` for use inside an AppleScript string literal. Only `"` can end a
    /// literal and `\` is the escape character, so these two are the whole set; a line break
    /// inside a literal is legal AppleScript.
    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// `value` as a quoted, escaped AppleScript string literal.
    static func literal(_ value: String) -> String {
        "\"" + escape(value) + "\""
    }

    /// Returns `id` unchanged if it has the shape of a Things id, otherwise throws.
    ///
    /// Things ids observed on current data are 22 alphanumeric characters; older data may use
    /// UUID-style ids with hyphens. Anything else is refused before a script is built, so an id
    /// can never end the literal it is placed in. The error names the rule, not the value: the
    /// value is caller-controlled.
    static func validatedID(_ id: String) throws -> String {
        let allowed = id.unicodeScalars.allSatisfy {
            ("a"..."z").contains($0) || ("A"..."Z").contains($0) || ("0"..."9").contains($0) || $0 == "-"
        }
        guard (1...64).contains(id.count), allowed else {
            throw ThingsError.invalidParameter(
                "id must be 1–64 characters of A–Z, a–z, 0–9 or '-' (a Things id)")
        }
        return id
    }

    /// Separates fields of one record in script output. A control character, so no name,
    /// note or tag can contain it (`|||` could; issue 9).
    static let fieldSeparator = "\u{1F}"
    /// Separates records in script output.
    static let recordSeparator = "\u{1E}"
    /// AppleScript expression producing `fieldSeparator`.
    static let fieldSeparatorExpression = "(character id 31)"
    /// AppleScript expression producing `recordSeparator`.
    static let recordSeparatorExpression = "(character id 30)"
}
