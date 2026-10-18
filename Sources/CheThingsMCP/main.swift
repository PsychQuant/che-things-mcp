import Foundation
import CheThingsMCPCore

// Handle command line arguments
if CommandLine.arguments.contains("--version") || CommandLine.arguments.contains("-v") {
    print(AppVersion.versionString)
    exit(0)
}

if CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h") {
    print(AppVersion.helpMessage)
    exit(0)
}

// macOS Automation (Apple Events) permission helpers. Both exit before the server starts.
if CommandLine.arguments.contains("--setup") {
    exit(AutomationSetup.runSetup())
}

if CommandLine.arguments.contains("--print-tcc-path") {
    exit(AutomationSetup.printStatus())
}

// Entry point
let server = try await CheThingsMCPServer()
try await server.run()
