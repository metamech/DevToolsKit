// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DevToolsKit",
    platforms: [
        .macOS(.v26), .iOS(.v26), .tvOS(.v26), .watchOS(.v26), .visionOS(.v26),
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
        .library(
            name: "DevToolsKitSecurity",
            targets: ["DevToolsKitSecurity"]
        ),
        .library(
            name: "DevToolsKitGitHub",
            targets: ["DevToolsKitGitHub"]
        ),
        .library(
            name: "DevToolsKitDiff",
            targets: ["DevToolsKitDiff"]
        ),
        .library(
            name: "DevToolsKitCodeAnalysis",
            targets: ["DevToolsKitCodeAnalysis"]
        ),
        .library(
            name: "DevToolsKitCodeAnalysisSwift",
            targets: ["DevToolsKitCodeAnalysisSwift"]
        ),
        .library(
            name: "DevToolsKitMetricsStore",
            targets: ["DevToolsKitMetricsStore"]
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
        .target(
            name: "DevToolsKitSecurity",
            dependencies: [
                "DevToolsKit",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "DevToolsKitGitHub",
            dependencies: [
                "DevToolsKit",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "DevToolsKitDiff",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "DevToolsKitCodeAnalysis",
            dependencies: ["DevToolsKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "DevToolsKitCodeAnalysisSwift",
            dependencies: ["DevToolsKitCodeAnalysis"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "DevToolsKitMetricsStore",
            dependencies: [
                "DevToolsKitMetrics",
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
        .testTarget(
            name: "DevToolsKitSecurityTests",
            dependencies: ["DevToolsKitSecurity"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "DevToolsKitGitHubTests",
            dependencies: ["DevToolsKitGitHub"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "DevToolsKitDiffTests",
            dependencies: ["DevToolsKitDiff"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "DevToolsKitCodeAnalysisTests",
            dependencies: ["DevToolsKitCodeAnalysis"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "DevToolsKitCodeAnalysisSwiftTests",
            dependencies: ["DevToolsKitCodeAnalysisSwift", "DevToolsKitCodeAnalysis"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "DevToolsKitMetricsStoreTests",
            dependencies: ["DevToolsKitMetricsStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
