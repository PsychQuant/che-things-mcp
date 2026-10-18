import AppKit
import Foundation

// MARK: - Status

/// Whether macOS lets this process send Apple events to a target app
/// (the "Automation" permission under System Settings > Privacy & Security).
///
/// This is *not* the Accessibility permission; the old `--help` text pointed
/// users at the wrong pane.
public enum AutomationStatus: Equatable, Sendable {
    case authorized
    /// `errAEEventNotPermitted` (-1743): the user, or a stale grant, refuses.
    case denied
    /// `errAEEventWouldRequireUserConsent` (-1744): macOS has not asked yet and
    /// the caller asked it not to prompt.
    case notDetermined
    /// `procNotFound`: the target app is not running. Not a permission problem.
    case targetNotRunning
    case other(Int)

    /// Maps the `OSStatus` returned by `AEDeterminePermissionToAutomateTarget`.
    /// The constants come from the SDK header, not from literals; a test pins
    /// their numeric values.
    public static func classify(_ osStatus: Int) -> AutomationStatus {
        if osStatus == 0 { return .authorized }
        if osStatus == Int(errAEEventNotPermitted) { return .denied }
        if osStatus == Int(errAEEventWouldRequireUserConsent) { return .notDetermined }
        if osStatus == Int(procNotFound) { return .targetNotRunning }
        return .other(osStatus)
    }

    public var summary: String {
        switch self {
        case .authorized:
            return "authorized: this process may send Apple events to Things 3"
        case .denied:
            return "denied (-1743, errAEEventNotPermitted): macOS refuses Apple events to Things 3 from this context"
        case .notDetermined:
            return "not determined (-1744): macOS has not asked yet; run --setup to be prompted"
        case .targetNotRunning:
            return "target app is not running: open Things 3 first (this is not a permission problem)"
        case .other(let status):
            return "unexpected status \(status): please report it with the output of --print-tcc-path"
        }
    }
}

// MARK: - Probe

/// Thin wrapper over `AEDeterminePermissionToAutomateTarget`.
public enum AutomationProbe {
    public static let thingsBundleID = "com.culturedcode.ThingsMac"

    public static func isRunning(bundleID: String = thingsBundleID) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    /// Asks macOS about the permission for `bundleID`.
    ///
    /// With `askUserIfNeeded: false` this never shows a dialog. With `true` it
    /// can block until the user answers, so it must not run on the main thread
    /// (see the SDK header comment on `AEDeterminePermissionToAutomateTarget`).
    /// The target must be running, otherwise the result is `.targetNotRunning`.
    public static func status(bundleID: String = thingsBundleID, askUserIfNeeded: Bool) -> AutomationStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let descriptor = target.aeDesc else { return .other(-1) }
        let osStatus = AEDeterminePermissionToAutomateTarget(
            descriptor, AEEventClass(typeWildCard), AEEventID(typeWildCard), askUserIfNeeded)
        return AutomationStatus.classify(Int(osStatus))
    }
}

// MARK: - Report

/// The text printed by `--print-tcc-path`.
public enum AutomationReport {
    public static func format(
        binaryPath: String,
        bundleIdentifier: String?,
        osVersion: String,
        thingsRunning: Bool,
        status: AutomationStatus
    ) -> String {
        """
        CheThingsMCP Automation (Apple Events) status
          binary:             \(binaryPath)
          bundle identifier:  \(bundleIdentifier ?? "(none embedded)")
          macOS:              \(osVersion)
          target app:         Things 3 (\(AutomationProbe.thingsBundleID)), \(thingsRunning ? "running" : "not running")
          status:             \(status.summary)

        NOTE: this status is read in the context this command runs in (for example Terminal),
        which is not necessarily the app that launches the MCP server (Claude Desktop, Claude Code,
        your editor). A grant given to Terminal does not automatically cover those apps, so
        "authorized" here can still be "denied" there. To be sure, make a real read-only tool call
        from the MCP client.
        """
    }
}

// MARK: - Setup and status commands

/// Implementation of `--setup` and `--print-tcc-path`.
public enum AutomationSetup {

    /// The real path of the running binary (symlinks resolved), for messages.
    public static func currentBinaryPath() -> String {
        let raw = Bundle.main.executablePath ?? CommandLine.arguments.first ?? "CheThingsMCP"
        return URL(fileURLWithPath: raw).resolvingSymlinksInPath().path
    }

    private static func osVersionString() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    /// `--print-tcc-path`. Never prompts.
    public static func printStatus() -> Int32 {
        let running = AutomationProbe.isRunning()
        let status = AutomationProbe.status(askUserIfNeeded: false)
        print(AutomationReport.format(
            binaryPath: currentBinaryPath(),
            bundleIdentifier: Bundle.main.bundleIdentifier,
            osVersion: osVersionString(),
            thingsRunning: running,
            status: status))
        return 0
    }

    /// `--setup`: asks macOS for permission to control Things 3.
    /// Returns the process exit code (0 = authorized).
    public static func runSetup() -> Int32 {
        let env = ProcessInfo.processInfo.environment
        if env["SSH_CONNECTION"] != nil || env["SSH_TTY"] != nil {
            fputs("""
            Cannot show the macOS permission dialog over SSH.
            Run this command in Terminal.app on the Mac itself.

            """, stderr)
            return 2
        }

        guard AutomationProbe.isRunning() else {
            fputs("""
            Things 3 is not running. Open Things 3, then run --setup again.
            (macOS can only ask about an app that is running.)

            """, stderr)
            return 1
        }

        if AutomationProbe.status(askUserIfNeeded: false) == .authorized {
            print("Already authorized: this context may send Apple events to Things 3.")
            printContextNote()
            return 0
        }

        print("Asking macOS for permission to control Things 3. Click Allow in the dialog.")

        // Must not run on the main thread: it blocks until the user answers.
        var result: AutomationStatus = .notDetermined
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            result = AutomationProbe.status(askUserIfNeeded: true)
            done.signal()
        }
        done.wait()

        print("Result: \(result.summary)")
        if result == .authorized {
            printContextNote()
            return 0
        }
        print("""

        Not authorized. Open System Settings > Privacy & Security > Automation and enable
        Things 3 for the entry that appears, then run --print-tcc-path to check again.
        """)
        return 1
    }

    private static func printContextNote() {
        print("""

        This grant belongs to the app that ran this command (for example Terminal). If the MCP
        server is launched by another app (Claude Desktop, Claude Code, your editor), make a
        read-only tool call from that app so macOS can ask about it as well.
        """)
    }
}
