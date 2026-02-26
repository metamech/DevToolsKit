// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DevToolsKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "DevToolsKit",
            targets: ["DevToolsKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "DevToolsKit",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "DevToolsKitTests",
            dependencies: ["DevToolsKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
