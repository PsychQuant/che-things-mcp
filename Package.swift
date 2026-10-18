// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CheThingsMCP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CheThingsMCPCore",
            targets: ["CheThingsMCPCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        // Core library containing ThingsManager, models, and server logic
        .target(
            name: "CheThingsMCPCore",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/CheThingsMCPCore"
        ),
        // Executable entry point
        .executableTarget(
            name: "CheThingsMCP",
            dependencies: ["CheThingsMCPCore"],
            path: "Sources/CheThingsMCP",
            exclude: ["Info.plist", "Entitlements.plist"],
            linkerSettings: [
                // Embed Info.plist into the Mach-O so the binary carries the usage description
                // (NSAppleEventsUsageDescription) that Apple requires of an app that sends Apple
                // events. Whether the dialog shows that text for a command-line tool has not been
                // observed here. The path is relative to the directory `swift build` runs in, so
                // build from the repository root.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/CheThingsMCP/Info.plist"
                ])
            ]
        ),
        // Unit tests
        .testTarget(
            name: "CheThingsMCPTests",
            dependencies: ["CheThingsMCPCore"],
            path: "Tests/CheThingsMCPTests"
        )
    ]
)
