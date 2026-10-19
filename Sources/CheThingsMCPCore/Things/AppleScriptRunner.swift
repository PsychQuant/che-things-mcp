import Foundation

/// Runs AppleScript source with `NSAppleScript` and maps its errors to `ThingsError`.
/// Every tool in `ThingsManager` goes through `run(_:)`.
enum AppleScriptRunner {

    /// Runs `source` on the main thread and returns its result.
    ///
    /// Apple documents `NSAppleScript` as a class that "must be used only from the main thread
    /// of an application" (Threading Programming Guide, Thread Safety Summary). It used to run on
    /// a background queue; in the issue 5 experiment 4 of 5 runs of the same script then stalled
    /// for 120 s or more (2 returned -1712), while every main-thread run finished in 1-4 s. That
    /// is an empirical result on one machine; the mechanism is not fully established (a stall did
    /// not occur on the old build while another script was in flight).
    ///
    /// The main thread is free here: `main.swift` awaits the server at top level, and the stdio
    /// transport does not use the main actor, so protocol messages (`ping`, `tools/list`) are
    /// answered while a script runs. Tool calls, however, run one at a time in arrival order: a
    /// long script delays every later call, writes included (measured: `get_tags` waited 37.6 s
    /// behind a 40.6 s `search_todos`). This is a trade-off against the stalls; see issue 8.
    ///
    /// A host that embeds `CheThingsMCPCore` must keep the main queue serviced (run loop,
    /// `dispatchMain()` or an async top-level `await`); otherwise this never resumes.
    static func run(_ source: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume(with: execute(source).mapError { $0 as Error })
            }
        }
    }

    /// Executes `source` synchronously on the calling thread. Private so that `run(_:)`, which
    /// puts it on the main thread, stays the only way in (issue 5).
    private static func execute(_ source: String) -> Result<String, ThingsError> {
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
