import Foundation

/// Runs AppleScript source with `NSAppleScript` and maps its errors to `ThingsError`.
/// Every tool in `ThingsManager` goes through `run(_:)`.
enum AppleScriptRunner {

    /// Runs `source` on the main thread and returns its result.
    ///
    /// Apple documents `NSAppleScript` as a class that "must be used only from the main thread
    /// of an application" (Threading Programming Guide, Thread Safety Summary). It used to run on
    /// a background queue, and Apple Events to Things then stalled until the 120 s reply timeout
    /// in 4 of 5 runs of the same script (issue 5). The main thread is free here: `main.swift`
    /// awaits the server at top level, and the stdio transport does not use the main actor, so
    /// running scripts on the main queue does not block request handling. Scripts are serialized
    /// as a result, which Things does with Apple Events anyway.
    static func run(_ source: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume(with: execute(source).mapError { $0 as Error })
            }
        }
    }

    /// Executes `source` synchronously on the calling thread.
    static func execute(_ source: String) -> Result<String, ThingsError> {
        guard let appleScript = NSAppleScript(source: source) else {
            return .failure(.scriptError("Failed to create AppleScript"))
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            if let authError = ThingsError.authorizationError(
                errorNumber: error[NSAppleScript.errorNumber] as? Int,
                message: errorMessage,
                binaryPath: AutomationSetup.currentBinaryPath()) {
                return .failure(authError)
            }
            if errorMessage.contains("Application isn't running") || errorMessage.contains("Can't get application") {
                return .failure(.thingsNotInstalled)
            }
            return .failure(.scriptError(errorMessage))
        }

        return .success(result.stringValue ?? "")
    }
}
