// swift-tools-version: 6.2
import PackageDescription

// XCFrameworkSmokeTest — exercises the prebuilt DevToolsKit XCFrameworks (release
// config) the way real downstream consumers do. The SPM-source test suite cannot
// catch bugs that only manifest in the compiled XCFramework binary; see #82.
//
// Before running this package, build the XCFrameworks from the local checkout:
//
//   swift Scripts/build-xcframeworks.swift --product DevToolsKit
//   swift Scripts/build-xcframeworks.swift --product DevToolsKitLogging
//
// Then:
//
//   swift test --package-path Examples/XCFrameworkSmokeTest -c release
//
// The release configuration is required — the bug in #82 does not reproduce in
// debug builds.

let package = Package(
    name: "XCFrameworkSmokeTest",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.11.0")
    ],
    targets: [
        .binaryTarget(name: "DevToolsKit", path: "../../Frameworks/DevToolsKit.xcframework"),
        .binaryTarget(
            name: "DevToolsKitLogging",
            path: "../../Frameworks/DevToolsKitLogging.xcframework"
        ),
        .testTarget(
            name: "XCFrameworkSmokeTestTests",
            dependencies: [
                "DevToolsKit",
                "DevToolsKitLogging",
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
