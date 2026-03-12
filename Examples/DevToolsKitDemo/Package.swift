// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DevToolsKitDemo",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "DevToolsKitDemo",
            dependencies: [
                .product(name: "DevToolsKit", package: "DevToolsKit"),
                .product(name: "DevToolsKitLogging", package: "DevToolsKit"),
                .product(name: "DevToolsKitMetrics", package: "DevToolsKit"),
                .product(name: "DevToolsKitLicensing", package: "DevToolsKit"),
                .product(name: "DevToolsKitSecurity", package: "DevToolsKit"),
                .product(name: "DevToolsKitGitHub", package: "DevToolsKit"),
                .product(name: "DevToolsKitCodeAnalysis", package: "DevToolsKit"),
                .product(name: "DevToolsKitScreenCapture", package: "DevToolsKit"),
                .product(name: "DevToolsKitIssueCapture", package: "DevToolsKit"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
