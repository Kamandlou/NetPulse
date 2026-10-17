// swift-tools-version: 5.9
import PackageDescription
import Foundation

var testSettings: [SwiftSetting] = []
let cltMacro = "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if FileManager.default.fileExists(atPath: cltMacro) && !FileManager.default.fileExists(atPath: "/Applications/Xcode.app") {
    testSettings.append(.unsafeFlags(["-load-plugin-library", cltMacro]))
}

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
            swiftSettings: testSettings
        )
    ]
)
