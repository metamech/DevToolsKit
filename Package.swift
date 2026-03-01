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
        ),
        .library(
            name: "DevToolsKitLogging",
            targets: ["DevToolsKitLogging"]
        ),
        .library(
            name: "DevToolsKitLicensing",
            targets: ["DevToolsKitLicensing"]
        ),
        .library(
            name: "DevToolsKitMetrics",
            targets: ["DevToolsKitMetrics"]
        ),
        .library(
            name: "DevToolsKitLicensingSeat",
            targets: ["DevToolsKitLicensingSeat"]
        ),
        .library(
            name: "DevToolsKitLicensingStoreKit",
            targets: ["DevToolsKitLicensingStoreKit"]
        ),
        .library(
            name: "DevToolsKitProcess",
            targets: ["DevToolsKitProcess"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.5.0"),
        .package(url: "https://github.com/licenseseat/licenseseat-swift.git", from: "0.3.1"),
    ],
    targets: [
        .target(
            name: "DevToolsKit",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "DevToolsKitLogging",
            dependencies: [
                "DevToolsKit",
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "DevToolsKitMetrics",
            dependencies: [
                "DevToolsKit",
                .product(name: "Metrics", package: "swift-metrics"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "DevToolsKitLicensing",
            dependencies: [
                "DevToolsKit",
                .product(name: "Metrics", package: "swift-metrics"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "DevToolsKitLicensingSeat",
            dependencies: [
                "DevToolsKitLicensing",
                .product(name: "LicenseSeat", package: "licenseseat-swift"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "DevToolsKitLicensingStoreKit",
            dependencies: [
                "DevToolsKitLicensing",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "DevToolsKitProcess",
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
        ),
        .testTarget(
            name: "DevToolsKitLoggingTests",
            dependencies: ["DevToolsKitLogging"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "DevToolsKitMetricsTests",
            dependencies: ["DevToolsKitMetrics"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "DevToolsKitLicensingTests",
            dependencies: ["DevToolsKitLicensing"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "DevToolsKitProcessTests",
            dependencies: ["DevToolsKitProcess"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
