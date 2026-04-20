#!/usr/bin/env swift

/// build-xcframeworks.swift
/// Builds DevToolsKit's SPM products as XCFrameworks and deposits them in Frameworks/.
///
/// Ported from Tenrec-Terminal's Scripts/build-xcframeworks.swift. Key addition:
/// PackageConfig supports a `bundledTransitiveTargets` list, and makeStaticLibrary()
/// collects `.o` files from each named transitive target's build dir in addition to
/// the primary target's. This lets DevToolsKitLicensingSeat.xcframework statically
/// bundle LicenseSeat's object files, making LicenseSeat an internal implementation
/// detail rather than a separately-linked dependency. See issue #74.
///
/// Usage:
///   swift Scripts/build-xcframeworks.swift --all
///   swift Scripts/build-xcframeworks.swift --package DevToolsKit
///   swift Scripts/build-xcframeworks.swift --all --force   # skip manifest check

import Foundation

// ---------------------------------------------------------------------------
// MARK: - Configuration
// ---------------------------------------------------------------------------

struct PackageConfig {
    let name: String
    let url: String
    let version: String
    /// Git tag prefix (e.g. "v" for tags like "v1.11.2"). Empty string if tags have no prefix.
    let tagPrefix: String
    let products: [String]
    /// Reverse-DNS bundle ID prefix used when generating framework Info.plist entries.
    let bundleIDPrefix: String
    /// Whether the package (and all its transitive deps) can be built with
    /// `-enable-library-evolution`. Packages whose deps break under library evolution
    /// (e.g. swift-log's @inlinable constraints) must set this to false.
    let libraryEvolution: Bool
    /// Per-product mapping of additional SPM target build-dirs whose `.o` files should
    /// be archived into the same static library as the primary target. Useful when a
    /// transitive dep should become an internal implementation detail of the
    /// xcframework rather than a separate module consumers must link.
    ///
    /// Example: ["DevToolsKitLicensingSeat": ["LicenseSeat"]] statically bundles
    /// LicenseSeat's object files into DevToolsKitLicensingSeat.xcframework (see #74).
    let bundledTransitiveTargets: [String: [String]]

    var gitTag: String { "\(tagPrefix)\(version)" }

    init(
        name: String,
        url: String,
        version: String,
        tagPrefix: String,
        products: [String],
        bundleIDPrefix: String,
        libraryEvolution: Bool,
        bundledTransitiveTargets: [String: [String]] = [:]
    ) {
        self.name = name
        self.url = url
        self.version = version
        self.tagPrefix = tagPrefix
        self.products = products
        self.bundleIDPrefix = bundleIDPrefix
        self.libraryEvolution = libraryEvolution
        self.bundledTransitiveTargets = bundledTransitiveTargets
    }
}

let allPackages: [PackageConfig] = [
    // DevToolsKit — all products declared in Package.swift. LibraryEvolution is
    // false because swift-log breaks under `-enable-library-evolution` (@inlinable
    // constraints). The xcframework uses .swiftmodule files only, which is fine
    // when consumed by the same Swift toolchain (tracked in manifest).
    //
    // DevToolsKitLicensingSeat statically bundles LicenseSeat's object files so
    // consumers don't need to link a separate LicenseSeat.xcframework (#74). This
    // only works because LicenseSeat is pinned to an exact version in Package.swift
    // and its license (MIT) permits static linking with attribution.
    PackageConfig(
        name: "DevToolsKit",
        url: "https://github.com/metamech/DevToolsKit.git",
        version: "0.13.5",
        tagPrefix: "v",
        products: [
            "DevToolsKit",
            "DevToolsKitLogging",
            "DevToolsKitMetrics",
            "DevToolsKitMetricsStore",
            "DevToolsKitIssueCapture",
            "DevToolsKitScreenCapture",
            "DevToolsKitFeatureFlags",
            "DevToolsKitLicensing",
            "DevToolsKitLicensingSeat",
            "DevToolsKitLicensingStoreKit",
            "DevToolsKitProcess",
            "DevToolsKitSecurity",
            "DevToolsKitGitHub",
            "DevToolsKitDiff",
            "DevToolsKitCodeAnalysis",
            "DevToolsKitCodeAnalysisSwift",
            "DevToolsKitDaemonHealth",
            "DevToolsKitPalette",
        ],
        bundleIDPrefix: "com.github.metamech",
        libraryEvolution: false,
        bundledTransitiveTargets: [
            "DevToolsKitLicensingSeat": ["LicenseSeat"],
        ]
    ),
]

// ---------------------------------------------------------------------------
// MARK: - Paths
// ---------------------------------------------------------------------------

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let repoRoot = scriptURL
    .deletingLastPathComponent()  // Scripts/
    .deletingLastPathComponent()  // repo root

let frameworksDir = repoRoot.appendingPathComponent("Frameworks")
let dSYMsDir = frameworksDir.appendingPathComponent("dSYMs")
let manifestURL = frameworksDir.appendingPathComponent(".manifest.json")

// ---------------------------------------------------------------------------
// MARK: - Argument Parsing
// ---------------------------------------------------------------------------

let args = Array(CommandLine.arguments.dropFirst())

let buildAll = args.contains("--all")
let force = args.contains("--force")

var packageFilter: String? = nil
if let idx = args.firstIndex(of: "--package"), idx + 1 < args.count {
    packageFilter = args[idx + 1]
}

/// Optional single-product filter. When set, only this product is built from the
/// selected package(s). Lets `make frameworks-licensingseat` target one xcframework.
var productFilter: String? = nil
if let idx = args.firstIndex(of: "--product"), idx + 1 < args.count {
    productFilter = args[idx + 1]
}

/// By default the script builds from the local DTK checkout (repoRoot) so that
/// in-progress changes in a worktree are reflected in the produced xcframeworks.
/// Pass `--clone` to restore Tenrec-style behavior: clone the configured tag
/// from the remote URL into a temp dir before building. Useful if you want to
/// verify a tagged release matches the configured version.
let useRemoteClone = args.contains("--clone")

guard buildAll || packageFilter != nil || productFilter != nil else {
    fputs("Usage: swift Scripts/build-xcframeworks.swift [--all | --package <name> | --product <name>] [--force] [--clone]\n", stderr)
    fputs("  --all               Build all configured packages and all their products\n", stderr)
    fputs("  --package <name>    Build every product of a single configured package\n", stderr)
    fputs("  --product <name>    Build a single product (filters within the selected package)\n", stderr)
    fputs("  --force             Skip manifest check and always rebuild\n", stderr)
    fputs("  --clone             Clone the configured tag from the remote instead of using the local checkout\n", stderr)
    exit(1)
}

let selectedPackages: [PackageConfig]
if buildAll {
    selectedPackages = allPackages
} else if let filter = packageFilter {
    guard let found = allPackages.first(where: { $0.name == filter }) else {
        fputs("Unknown package: \(filter)\n", stderr)
        fputs("Available: \(allPackages.map { $0.name }.joined(separator: ", "))\n", stderr)
        exit(1)
    }
    selectedPackages = [found]
} else if let productName = productFilter {
    // Locate whichever package declares this product.
    guard let owning = allPackages.first(where: { $0.products.contains(productName) }) else {
        let allProducts = allPackages.flatMap { $0.products }.sorted().joined(separator: ", ")
        fputs("Unknown product: \(productName)\n", stderr)
        fputs("Available products: \(allProducts)\n", stderr)
        exit(1)
    }
    selectedPackages = [owning]
} else {
    selectedPackages = []
}

// ---------------------------------------------------------------------------
// MARK: - Helpers
// ---------------------------------------------------------------------------

func run(_ launchPath: String, _ arguments: [String], workingDirectory: URL? = nil) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    if let wd = workingDirectory {
        process.currentDirectoryURL = wd
    }
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw BuildError.commandFailed(launchPath, process.terminationStatus)
    }
}

func runCapturing(_ launchPath: String, _ arguments: [String], workingDirectory: URL? = nil) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    if let wd = workingDirectory {
        process.currentDirectoryURL = wd
    }
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()  // suppress stderr
    try process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else {
        throw BuildError.commandFailed(launchPath, process.terminationStatus)
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}

enum BuildError: Error, CustomStringConvertible {
    case commandFailed(String, Int32)
    case missingTool(String)
    case manifestReadFailed(String)
    case cloneFailed(String)
    case buildFailed(String, String)
    case xcframeworkFailed(String)
    case copyFailed(String)
    case missingArtifact(String)

    var description: String {
        switch self {
        case .commandFailed(let cmd, let code): return "Command '\(cmd)' exited with status \(code)"
        case .missingTool(let tool): return "Required tool not found: \(tool)"
        case .manifestReadFailed(let msg): return "Manifest read failed: \(msg)"
        case .cloneFailed(let pkg): return "Failed to clone \(pkg)"
        case .buildFailed(let pkg, let arch): return "swift build failed for \(pkg) [\(arch)]"
        case .xcframeworkFailed(let pkg): return "xcframework creation failed for \(pkg)"
        case .copyFailed(let path): return "Failed to copy to \(path)"
        case .missingArtifact(let path): return "Expected build artifact not found: \(path)"
        }
    }
}

func requireTool(_ name: String) throws -> String {
    let which = try? runCapturing("/usr/bin/which", [name])
    guard let path = which, !path.isEmpty else {
        throw BuildError.missingTool(name)
    }
    return path
}

// ---------------------------------------------------------------------------
// MARK: - Manifest
// ---------------------------------------------------------------------------

struct ManifestEntry: Codable {
    let version: String
    let swift: String
    let built: String
}

typealias Manifest = [String: ManifestEntry]

func readManifest() -> Manifest {
    guard let data = try? Data(contentsOf: manifestURL),
          let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
    else { return [:] }
    return manifest
}

func writeManifest(_ manifest: Manifest) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(manifest)
    try data.write(to: manifestURL, options: .atomic)
}

func swiftVersion() -> String {
    let output = (try? runCapturing("/usr/bin/swift", ["--version"])) ?? ""
    // Match "Swift version X.Y" or "Swift version X.Y.Z" (Apple toolchain omits patch on .0)
    if let range = output.range(of: #"Swift version (\d+\.\d+(?:\.\d+)?)"#, options: .regularExpression) {
        let match = String(output[range])
        return match.replacingOccurrences(of: "Swift version ", with: "")
    }
    return "unknown"
}

func isoTimestamp() -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: Date())
}

// ---------------------------------------------------------------------------
// MARK: - Build Pipeline
// ---------------------------------------------------------------------------

func ensureDirectories() throws {
    let fm = FileManager.default
    try fm.createDirectory(at: frameworksDir, withIntermediateDirectories: true)
    try fm.createDirectory(at: dSYMsDir, withIntermediateDirectories: true)
}

/// Creates a temp directory, runs `body`, then removes the temp directory
/// regardless of whether `body` throws.
func withTempDir<T>(prefix: String, body: (URL) throws -> T) throws -> T {
    let fm = FileManager.default
    let base = URL(fileURLWithPath: NSTemporaryDirectory())
    let tmpDir = base.appendingPathComponent("\(prefix)-\(UUID().uuidString)")
    try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer {
        try? fm.removeItem(at: tmpDir)
    }
    return try body(tmpDir)
}

/// Copies the local DTK checkout into `dst`, skipping build artifacts and git
/// metadata so the per-arch `swift build` runs in a clean `.build/` dir.
///
/// This is the default source for an in-repo build — it reflects in-progress
/// changes in the working tree. Contrast with `clonePackage(...)` which
/// fetches the configured tag from the remote.
func copyWorkingTree(from src: URL, to dst: URL) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: dst, withIntermediateDirectories: true)

    // Use `rsync` for speed and reliable exclude handling. The excludes match
    // the repo's .gitignore entries for build output and editor state.
    let rsyncArgs = [
        "-a",
        "--exclude=.git",
        "--exclude=.build",
        "--exclude=Frameworks",
        "--exclude=.swiftpm",
        "--exclude=.DS_Store",
        "--exclude=DerivedData",
        "--exclude=.claude",
        "\(src.path)/",
        dst.path,
    ]
    try run("/usr/bin/rsync", rsyncArgs)
}

func clonePackage(_ pkg: PackageConfig, into dir: URL) throws {
    print("  Cloning \(pkg.name) @ \(pkg.gitTag)...")
    do {
        try run("/usr/bin/git", [
            "clone",
            "--depth", "1",
            "--branch", pkg.gitTag,
            pkg.url,
            dir.path,
        ])
    } catch {
        throw BuildError.cloneFailed(pkg.name)
    }
}

/// Injects per-target library evolution flags into a cloned Package.swift.
///
/// Strategy: all DevToolsKit targets already have `swiftSettings: [.swiftLanguageMode(.v6)]`.
/// We append `.unsafeFlags(...)` to every such array. This only affects the package's own
/// targets (not transitive deps like swift-log), which is exactly what we need.
func injectLibraryEvolutionSettings(packageSwiftURL: URL, targets: [String]) throws {
    var content = try String(contentsOf: packageSwiftURL, encoding: .utf8)

    // Find all `.swiftLanguageMode(.v6)` occurrences and append library evolution flags after each.
    // This pattern only appears in .target() swiftSettings arrays, never in product declarations.
    let needle = ".swiftLanguageMode(.v6)"
    let replacement = ".swiftLanguageMode(.v6),\n                    .unsafeFlags([\"-enable-library-evolution\", \"-emit-module-interface\"])"
    content = content.replacingOccurrences(of: needle, with: replacement)

    try content.write(to: packageSwiftURL, atomically: true, encoding: .utf8)
}

/// Runs `swift build` for a single architecture.
///
/// Library evolution flags are applied per-target via Package.swift injection (see
/// `injectLibraryEvolutionSettings`), not via global `-Xswiftc` flags. The `libraryEvolution`
/// parameter on PackageConfig controls whether injection is done before building.
///
/// Returns the directory containing the release build products for that arch:
///   `.build/<arch>-apple-macosx/release/`
func buildForArch(
    target: String,
    arch: String,
    sourceDir: URL,
    libraryEvolution: Bool = true
) throws -> URL {
    print("    swift build \(target) [\(arch)]...")
    var args = [
        "build",
        "-c", "release",
        "--arch", arch,
        "--target", target,
    ]
    // When libraryEvolution is true and per-target injection hasn't been done,
    // we still use global flags (for packages with no problematic deps).
    if libraryEvolution {
        args += [
            "-Xswiftc", "-enable-library-evolution",
            "-Xswiftc", "-emit-module-interface",
        ]
    }
    do {
        try run("/usr/bin/swift", args, workingDirectory: sourceDir)
    } catch {
        throw BuildError.buildFailed(target, arch)
    }

    return sourceDir
        .appendingPathComponent(".build")
        .appendingPathComponent("\(arch)-apple-macosx")
        .appendingPathComponent("release")
}

/// Creates a static `.a` library from all `.o` files produced for the primary
/// target plus any named transitive targets whose object files should be
/// archived into the same library.
///
/// Collection rule: for each name in `[primaryTarget] + transitiveTargets`, scan
/// `{buildDir}/{name}.build/` for `*.o` files. All collected objects are fed
/// through a single `libtool -static` invocation via an `xargs` response file
/// (avoids OS argument-length limits).
///
/// Caller is responsible for ensuring each transitive target's `.build/` dir
/// exists — this normally happens for free because SPM builds transitive deps
/// as part of compiling the primary target.
func makeStaticLibrary(
    primaryTarget: String,
    transitiveTargets: [String] = [],
    buildDir: URL,
    outputPath: String
) throws {
    let fm = FileManager.default

    var collectedObjects: [String] = []
    var missingDirs: [String] = []

    for target in [primaryTarget] + transitiveTargets {
        let objectsDir = buildDir.appendingPathComponent("\(target).build")
        guard fm.fileExists(atPath: objectsDir.path) else {
            missingDirs.append(objectsDir.path)
            continue
        }

        // Enumerate recursively — some SPM targets nest `.o` files beneath
        // subdirectories (e.g. module-ID files in a `Modules/` subdir).
        let enumerator = fm.enumerator(
            at: objectsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        guard let enumerator else {
            throw BuildError.missingArtifact(objectsDir.path)
        }
        for case let url as URL in enumerator where url.pathExtension == "o" {
            collectedObjects.append(url.path)
        }
    }

    // Primary target missing is fatal — transitive targets missing are also fatal
    // when the caller explicitly requested them (the whole point is bundling).
    if !missingDirs.isEmpty {
        throw BuildError.missingArtifact(missingDirs.joined(separator: ", "))
    }

    guard !collectedObjects.isEmpty else {
        throw BuildError.missingArtifact("\(buildDir.path)/{\(primaryTarget),\(transitiveTargets.joined(separator: ","))}.build/*.o")
    }

    // Write object paths to a temporary response file to avoid arg-length limits.
    let responseFile = FileManager.default
        .temporaryDirectory
        .appendingPathComponent("libtool-objects-\(UUID().uuidString).txt")
    try collectedObjects.joined(separator: "\n")
        .write(to: responseFile, atomically: true, encoding: .utf8)
    defer { try? fm.removeItem(at: responseFile) }

    // libtool -static reads the response file via xargs (no native @file support).
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xargs")
    process.arguments = ["/usr/bin/libtool", "-static", "-o", outputPath]
    process.standardInput = try FileHandle(forReadingFrom: responseFile)
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw BuildError.commandFailed("libtool", process.terminationStatus)
    }
}

/// Assembles a `.framework` bundle directory suitable for `xcodebuild -create-xcframework`.
///
/// Uses the macOS versioned bundle layout (required by Xcode for non-shallow platforms):
/// ```
/// <Product>.framework/
///   Versions/
///     A/
///       <Product>          — universal (fat) static library
///       Headers/
///       Modules/
///       Resources/
///         Info.plist
///     Current -> A
///   <Product> -> Versions/Current/<Product>
///   Headers -> Versions/Current/Headers
///   Modules -> Versions/Current/Modules
///   Resources -> Versions/Current/Resources
/// ```
func assembleFrameworkBundle(
    product: String,
    bundleIDPrefix: String,
    version: String,
    transitiveTargets: [String],
    archBuildDirs: [(arch: String, buildDir: URL)],
    into outputDir: URL
) throws -> URL {
    let fm = FileManager.default
    let fwDir = outputDir.appendingPathComponent("\(product).framework")
    let versionDir = fwDir.appendingPathComponent("Versions/A")
    let modulesDir = versionDir.appendingPathComponent("Modules")
    let swiftmoduleDir = modulesDir.appendingPathComponent("\(product).swiftmodule")
    let headersDir = versionDir.appendingPathComponent("Headers")
    let resourcesDir = versionDir.appendingPathComponent("Resources")

    try fm.createDirectory(at: swiftmoduleDir, withIntermediateDirectories: true)
    try fm.createDirectory(at: headersDir, withIntermediateDirectories: true)
    try fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

    // ---- Static libraries: one per arch, then lipo into a universal binary ----
    var archLibPaths: [String] = []
    for (arch, buildDir) in archBuildDirs {
        let archLib = outputDir.appendingPathComponent("lib\(product)-\(arch).a").path
        try makeStaticLibrary(
            primaryTarget: product,
            transitiveTargets: transitiveTargets,
            buildDir: buildDir,
            outputPath: archLib
        )
        archLibPaths.append(archLib)
    }

    let frameworkBinary = versionDir.appendingPathComponent(product).path
    if archLibPaths.count == 1 {
        try fm.copyItem(atPath: archLibPaths[0], toPath: frameworkBinary)
    } else {
        // Combine into a universal (fat) binary
        var lipoArgs = ["-create"]
        lipoArgs += archLibPaths
        lipoArgs += ["-output", frameworkBinary]
        try run("/usr/bin/lipo", lipoArgs)
    }

    // ---- Swift module artifacts (one set per arch) ----
    // Include both the primary product and any bundled transitive modules, so
    // callers that `@_exported import <Transitive>` in the product resolve
    // against module files located in the same .framework/Modules tree.
    let moduleTargets = [product] + transitiveTargets
    for (arch, buildDir) in archBuildDirs {
        let triple = "\(arch)-apple-macos"
        let modulesSrc = buildDir.appendingPathComponent("Modules")

        for moduleName in moduleTargets {
            let dstDir = modulesDir.appendingPathComponent("\(moduleName).swiftmodule")
            try fm.createDirectory(at: dstDir, withIntermediateDirectories: true)

            let buildSrc = buildDir.appendingPathComponent("\(moduleName).build")

            func copyIfExists(_ src: URL, _ dstName: String) {
                let dst = dstDir.appendingPathComponent(dstName)
                if fm.fileExists(atPath: src.path) {
                    // Remove stale entry from a previous arch copy attempt.
                    if fm.fileExists(atPath: dst.path) {
                        try? fm.removeItem(at: dst)
                    }
                    try? fm.copyItem(at: src, to: dst)
                }
            }

            copyIfExists(modulesSrc.appendingPathComponent("\(moduleName).swiftmodule"), "\(triple).swiftmodule")
            copyIfExists(modulesSrc.appendingPathComponent("\(moduleName).swiftdoc"), "\(triple).swiftdoc")
            // .swiftinterface files land in different places depending on how library
            // evolution was enabled: global -Xswiftc → <module>.build/, per-target
            // swiftSettings → Modules/. Check both locations.
            for dir in [buildSrc, modulesSrc] {
                copyIfExists(dir.appendingPathComponent("\(moduleName).swiftinterface"), "\(triple).swiftinterface")
                copyIfExists(dir.appendingPathComponent("\(moduleName).private.swiftinterface"), "\(triple).private.swiftinterface")
            }
        }
    }

    // Validate that at least one module artifact was produced for the primary product.
    // With library evolution: .swiftinterface files are required.
    // Without library evolution: .swiftmodule files suffice (same-toolchain use only).
    let swiftmoduleContents = (try? fm.contentsOfDirectory(atPath: swiftmoduleDir.path)) ?? []
    let hasModuleArtifact = swiftmoduleContents.contains {
        $0.hasSuffix(".swiftinterface") || $0.hasSuffix(".swiftmodule")
    }
    guard hasModuleArtifact else {
        throw BuildError.missingArtifact("*.swiftinterface or *.swiftmodule inside \(swiftmoduleDir.path)")
    }

    // ---- ObjC bridging header ----
    // Use the first arch's generated header (content is arch-independent for pure Swift)
    if let (firstArch, firstBuildDir) = archBuildDirs.first {
        let generatedHeader = firstBuildDir
            .appendingPathComponent("\(product).build")
            .appendingPathComponent("include")
            .appendingPathComponent("\(product)-Swift.h")
        if fm.fileExists(atPath: generatedHeader.path) {
            try fm.copyItem(
                at: generatedHeader,
                to: headersDir.appendingPathComponent("\(product)-Swift.h")
            )
        }
        _ = firstArch  // suppress unused warning
    }

    // ---- module.modulemap ----
    let modulemap = """
    framework module \(product) {
        umbrella header "\(product)-Swift.h"
        export *
        module * { export * }
    }
    """
    try modulemap.write(
        to: modulesDir.appendingPathComponent("module.modulemap"),
        atomically: true, encoding: .utf8
    )

    // ---- Info.plist (in Resources/ for versioned layout) ----
    let infoPlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleExecutable</key><string>\(product)</string>
        <key>CFBundleIdentifier</key><string>\(bundleIDPrefix).\(product)</string>
        <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
        <key>CFBundleName</key><string>\(product)</string>
        <key>CFBundlePackageType</key><string>FMWK</string>
        <key>CFBundleShortVersionString</key><string>\(version)</string>
        <key>CFBundleVersion</key><string>1</string>
        <key>MinimumOSVersion</key><string>13.0</string>
    </dict>
    </plist>
    """
    try infoPlist.write(
        to: resourcesDir.appendingPathComponent("Info.plist"),
        atomically: true, encoding: .utf8
    )

    // ---- Versioned bundle symlinks ----
    let versionsDir = fwDir.appendingPathComponent("Versions")
    try fm.createSymbolicLink(
        atPath: versionsDir.appendingPathComponent("Current").path,
        withDestinationPath: "A"
    )
    // Top-level symlinks into Versions/Current/
    for name in [product, "Headers", "Modules", "Resources"] {
        try fm.createSymbolicLink(
            atPath: fwDir.appendingPathComponent(name).path,
            withDestinationPath: "Versions/Current/\(name)"
        )
    }

    return fwDir
}

/// Creates the final `<product>.xcframework` in `frameworksDir` from a pre-assembled
/// `.framework` bundle.
///
/// When `libraryEvolution` is `false`, passes `-allow-internal-distribution` to
/// `xcodebuild -create-xcframework`. This permits bundles that contain only
/// `.swiftmodule` files (no `.swiftinterface`) — appropriate for xcframeworks
/// consumed in-repo only and not redistributed publicly.
func buildXCFramework(
    product: String,
    frameworkBundle: URL,
    libraryEvolution: Bool
) throws -> URL {
    let outputPath = frameworksDir.appendingPathComponent("\(product).xcframework").path

    // Remove any stale xcframework
    let fm = FileManager.default
    if fm.fileExists(atPath: outputPath) {
        try fm.removeItem(atPath: outputPath)
    }

    print("    Creating \(product).xcframework...")
    var xcfArgs = [
        "-create-xcframework",
        "-framework", frameworkBundle.path,
        "-output", outputPath,
    ]
    if !libraryEvolution {
        xcfArgs.append("-allow-internal-distribution")
    }
    do {
        try run("/usr/bin/xcodebuild", xcfArgs)
    } catch {
        throw BuildError.xcframeworkFailed(product)
    }

    return URL(fileURLWithPath: outputPath)
}

// ---------------------------------------------------------------------------
// MARK: - Per-Package Build
// ---------------------------------------------------------------------------

func buildPackage(
    _ pkg: PackageConfig,
    productFilter: String?,
    manifest: inout Manifest,
    swift toolchainVersion: String
) throws {
    print("")
    print("Building \(pkg.name) \(pkg.version)...")

    // Decide which products to build this invocation.
    let productsToBuild: [String]
    if let filter = productFilter {
        guard pkg.products.contains(filter) else {
            fputs("Package \(pkg.name) does not declare product \(filter)\n", stderr)
            fputs("Available: \(pkg.products.joined(separator: ", "))\n", stderr)
            throw BuildError.missingArtifact(filter)
        }
        productsToBuild = [filter]
    } else {
        productsToBuild = pkg.products
    }

    // Manifest check — only skip when rebuilding the full product list unchanged.
    // A single-product filter always forces a rebuild for that product.
    if productFilter == nil, !force, let entry = manifest[pkg.name] {
        if entry.version == pkg.version && entry.swift == toolchainVersion {
            print("  Skipping \(pkg.name) — already built with Swift \(toolchainVersion) (use --force to rebuild).")
            return
        }
    }

    try withTempDir(prefix: pkg.name) { tmpDir in
        let assembliesDir = tmpDir.appendingPathComponent("assemblies")
        try FileManager.default.createDirectory(at: assembliesDir, withIntermediateDirectories: true)

        // Source strategy:
        // - Local mode (default): copy the repoRoot working tree into a scratch
        //   dir so we can safely inject library-evolution flags and run
        //   `swift build` without polluting the working `.build/` directory.
        //   Skips `.git`, `.build`, and `Frameworks` to keep the copy lean.
        // - Clone mode (--clone): mirror Tenrec's behavior — shallow-clone the
        //   configured tag into the scratch dir.
        let sourceDir = tmpDir.appendingPathComponent("source")
        if useRemoteClone {
            try clonePackage(pkg, into: sourceDir)
        } else {
            print("  Using local checkout at \(repoRoot.path) (pass --clone to use the remote \(pkg.gitTag) tag instead)")
            try copyWorkingTree(from: repoRoot, to: sourceDir)
        }

        // For packages that can't use global library evolution flags (transitive deps
        // like swift-log break), inject per-target swiftSettings into the Package.swift.
        if !pkg.libraryEvolution {
            let packageSwiftURL = sourceDir.appendingPathComponent("Package.swift")
            try injectLibraryEvolutionSettings(
                packageSwiftURL: packageSwiftURL,
                targets: pkg.products
            )
        }

        // Build each product
        for product in productsToBuild {
            print("  Product: \(product)")

            let transitives = pkg.bundledTransitiveTargets[product] ?? []
            if !transitives.isEmpty {
                print("    Bundling transitive targets: \(transitives.joined(separator: ", "))")
            }

            // Build for each architecture
            var archBuildDirs: [(arch: String, buildDir: URL)] = []
            for arch in ["arm64", "x86_64"] {
                let buildDir = try buildForArch(
                    target: product,
                    arch: arch,
                    sourceDir: sourceDir,
                    libraryEvolution: pkg.libraryEvolution
                )
                archBuildDirs.append((arch: arch, buildDir: buildDir))
            }

            // Assemble framework bundle (fat binary + all arch module artifacts)
            let productAssemblyDir = assembliesDir.appendingPathComponent(product)
            try FileManager.default.createDirectory(at: productAssemblyDir, withIntermediateDirectories: true)
            let frameworkBundle = try assembleFrameworkBundle(
                product: product,
                bundleIDPrefix: pkg.bundleIDPrefix,
                version: pkg.version,
                transitiveTargets: transitives,
                archBuildDirs: archBuildDirs,
                into: productAssemblyDir
            )

            // Create xcframework
            _ = try buildXCFramework(
                product: product,
                frameworkBundle: frameworkBundle,
                libraryEvolution: pkg.libraryEvolution
            )

            print("    \(product).xcframework written to Frameworks/")
        }
    }

    // Only update manifest for full-package runs; a single-product rebuild
    // mustn't let the manifest claim the rest of the package is fresh.
    if productFilter == nil {
        manifest[pkg.name] = ManifestEntry(
            version: pkg.version,
            swift: toolchainVersion,
            built: isoTimestamp()
        )
    }

    print("  \(pkg.name) done.")
}

// ---------------------------------------------------------------------------
// MARK: - Main
// ---------------------------------------------------------------------------

do {
    // Verify required tools
    _ = try requireTool("git")
    _ = try requireTool("xcodebuild")
    _ = try requireTool("lipo")

    try ensureDirectories()

    let toolchainVersion = swiftVersion()
    print("Swift toolchain: \(toolchainVersion)")
    print("Frameworks output: \(frameworksDir.path)")
    print("")

    var manifest = readManifest()

    var hadError = false
    for pkg in selectedPackages {
        do {
            try buildPackage(
                pkg,
                productFilter: productFilter,
                manifest: &manifest,
                swift: toolchainVersion
            )
        } catch {
            fputs("ERROR building \(pkg.name): \(error)\n", stderr)
            hadError = true
        }
    }

    // Write manifest even on partial success (records what did complete)
    try? writeManifest(manifest)

    if hadError {
        fputs("\nOne or more packages failed to build. See errors above.\n", stderr)
        exit(1)
    }

    print("")
    print("All requested frameworks built successfully.")
    exit(0)

} catch {
    fputs("Fatal: \(error)\n", stderr)
    exit(1)
}
