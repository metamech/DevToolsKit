import Foundation

/// Analyzes a working directory to detect tech stack, frameworks, and project structure.
///
/// Uses a single `contentsOfDirectory()` enumeration instead of individual `fileExists()`
/// checks, and caches results per directory with a configurable TTL.
///
/// ```swift
/// let analyzer = ProjectStackAnalyzer()
/// let profile = analyzer.analyze(directory: "/path/to/project")
/// print(profile.languages) // ["Swift", "TypeScript"]
/// ```
///
/// - Since: 0.9.0
public actor ProjectStackAnalyzer {

    /// Known tech stack markers: filename to (language, framework/tool).
    private static let stackMarkers: [(file: String, language: String, framework: String?)] = [
        ("package.json", "JavaScript/TypeScript", "Node.js"),
        ("tsconfig.json", "TypeScript", nil),
        ("pyproject.toml", "Python", nil),
        ("setup.py", "Python", nil),
        ("requirements.txt", "Python", nil),
        ("Pipfile", "Python", "Pipenv"),
        ("go.mod", "Go", nil),
        ("Cargo.toml", "Rust", nil),
        ("Gemfile", "Ruby", nil),
        ("Package.swift", "Swift", "SwiftPM"),
        ("build.gradle", "Java/Kotlin", "Gradle"),
        ("build.gradle.kts", "Kotlin", "Gradle"),
        ("pom.xml", "Java", "Maven"),
        ("mix.exs", "Elixir", nil),
        ("pubspec.yaml", "Dart", "Flutter/Dart"),
        ("composer.json", "PHP", "Composer"),
        ("CMakeLists.txt", "C/C++", "CMake"),
        ("Makefile", "Unknown", "Make"),
        ("Dockerfile", "Unknown", "Docker"),
        ("docker-compose.yml", "Unknown", "Docker Compose"),
        (".github/workflows", "Unknown", "GitHub Actions"),
    ]

    /// File extensions recognized as source code.
    private static let codeExtensions: Set<String> = [
        "swift", "py", "js", "ts", "go", "rs", "rb", "java", "kt",
        "ex", "dart", "php", "c", "cpp", "h", "m",
    ]

    /// Directories to skip during file enumeration.
    private static let skipDirectories: Set<String> = [
        "node_modules", ".git", "build", "DerivedData", ".build",
    ]

    // MARK: - Cache

    private struct CachedProfile {
        let profile: ProjectProfile
        let expiry: Date
    }

    private var cache: [String: CachedProfile] = [:]

    /// The TTL for cached profiles, in seconds.
    public let cacheTTL: TimeInterval

    /// Maximum number of files to sample for line counting.
    public let maxFileSample: Int

    // MARK: - Init

    /// Creates a project stack analyzer.
    ///
    /// - Parameters:
    ///   - cacheTTL: How long cached profiles remain valid, in seconds. Defaults to 300 (5 minutes).
    ///   - maxFileSample: Maximum number of files to read for line counting. Defaults to 500.
    public init(cacheTTL: TimeInterval = 300, maxFileSample: Int = 500) {
        self.cacheTTL = cacheTTL
        self.maxFileSample = maxFileSample
    }

    // MARK: - Analysis

    /// Analyze the project at the given directory.
    ///
    /// Returns a cached result if available and not expired. Otherwise,
    /// enumerates directory contents once and checks membership in a Set.
    ///
    /// - Parameter directory: The path to the project root directory.
    /// - Returns: A ``ProjectProfile`` describing the project's tech stack.
    public func analyze(directory: String) -> ProjectProfile {
        if let cached = cache[directory], cached.expiry > Date() {
            return cached.profile
        }

        let fm = FileManager.default
        var languages: Set<String> = []
        var frameworks: Set<String> = []

        let contents = Set((try? fm.contentsOfDirectory(atPath: directory)) ?? [])

        for marker in Self.stackMarkers {
            let found: Bool
            if marker.file.contains("/") {
                let path = (directory as NSString).appendingPathComponent(marker.file)
                found = fm.fileExists(atPath: path)
            } else {
                found = contents.contains(marker.file)
            }
            if found {
                if marker.language != "Unknown" {
                    languages.insert(marker.language)
                }
                if let fw = marker.framework {
                    frameworks.insert(fw)
                }
            }
        }

        let hasReadme = contents.contains("README.md")
        let hasClaudeMd = contents.contains("CLAUDE.md")
        let hasGit = contents.contains(".git")

        let dirSize = estimateCodebaseSize(directory: directory, fileManager: fm)

        let profile = ProjectProfile(
            directory: directory,
            languages: Array(languages).sorted(),
            frameworks: Array(frameworks).sorted(),
            hasReadme: hasReadme,
            hasClaudeMd: hasClaudeMd,
            hasGit: hasGit,
            estimatedFileCount: dirSize.fileCount,
            estimatedLineCount: dirSize.lineCount
        )

        cache[directory] = CachedProfile(profile: profile, expiry: Date().addingTimeInterval(cacheTTL))

        return profile
    }

    /// Invalidate the cache for a specific directory.
    ///
    /// - Parameter directory: The directory whose cache entry should be removed.
    public func invalidate(directory: String) {
        cache.removeValue(forKey: directory)
    }

    /// Invalidate all cached profiles.
    public func invalidateAll() {
        cache.removeAll()
    }

    // MARK: - Private

    private func estimateCodebaseSize(
        directory: String,
        fileManager fm: FileManager
    ) -> (fileCount: Int, lineCount: Int) {
        var fileCount = 0
        var lineCount = 0

        guard let enumerator = fm.enumerator(atPath: directory) else {
            return (0, 0)
        }

        while let path = enumerator.nextObject() as? String {
            let components = path.components(separatedBy: "/")
            if components.contains(where: { Self.skipDirectories.contains($0) }) {
                continue
            }
            let ext = (path as NSString).pathExtension.lowercased()
            guard Self.codeExtensions.contains(ext) else { continue }

            fileCount += 1
            if fileCount <= maxFileSample {
                let fullPath = (directory as NSString).appendingPathComponent(path)
                if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                    lineCount += content.components(separatedBy: "\n").count
                }
            }
        }

        return (fileCount, lineCount)
    }
}
