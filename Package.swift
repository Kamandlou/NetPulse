// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetPulse",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NetPulse", targets: ["NetPulseApp"]),
        .library(name: "NetPulseCore", targets: ["NetPulseCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NetPulseCore",
            dependencies: [],
            path: "Sources/NetPulseCore"
        ),
        .executableTarget(
            name: "NetPulseApp",
            dependencies: ["NetPulseCore"],
            path: "Sources/NetPulseApp"
        ),
        .testTarget(
            name: "NetPulseTests",
            dependencies: ["NetPulseCore"],
            path: "Tests/NetPulseTests",
            swiftSettings: [
                .unsafeFlags(["-load-plugin-library", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"])
            ]
        )
    ]
)
