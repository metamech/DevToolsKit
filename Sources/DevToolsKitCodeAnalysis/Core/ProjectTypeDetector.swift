import Foundation

// MARK: - Project Type

/// Detected project type and framework.
///
/// > Since: 0.4.0
public enum ProjectType: String, Sendable, Codable, CaseIterable, Equatable {
    // Swift
    case swiftPackage = "swift-package"
    case xcodeProject = "xcode-project"

    // JavaScript/TypeScript
    case nodeJS = "nodejs"
    case react = "react"
    case nextJS = "nextjs"

    // Python
    case python = "python"
    case django = "django"
    case fastAPI = "fastapi"

    // Other languages
    case go = "go"
    case rust = "rust"
    case java = "java"
    case springBoot = "spring-boot"
    case cpp = "cpp"
    case csharp = "csharp"
    case ruby = "ruby"

    // Special cases
    case mixed
    case unknown

    /// Human-readable display name for the project type.
    public var displayName: String {
        switch self {
        case .swiftPackage: return "Swift Package"
        case .xcodeProject: return "Xcode Project"
        case .nodeJS: return "Node.js"
        case .react: return "React"
        case .nextJS: return "Next.js"
        case .python: return "Python"
        case .django: return "Django"
        case .fastAPI: return "FastAPI"
        case .go: return "Go"
        case .rust: return "Rust"
        case .java: return "Java"
        case .springBoot: return "Spring Boot"
        case .cpp: return "C++"
        case .csharp: return "C#/.NET"
        case .ruby: return "Ruby"
        case .mixed: return "Mixed"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Project Detection Result

/// Result of project type detection.
///
/// > Since: 0.4.0
public struct ProjectDetectionResult: Sendable {
    /// Primary detected project type.
    public let primaryType: ProjectType

    /// Confidence score (0.0 to 1.0).
    public let confidence: Double

    /// File or pattern indicators that led to the detection.
    public let indicators: [String]

    /// Detected frameworks (e.g. "React", "Django").
    public let frameworks: [String]

    /// All detected project types (for mixed projects).
    public let detectedTypes: [ProjectType]

    /// Create a project detection result.
    public init(
        primaryType: ProjectType,
        confidence: Double,
        indicators: [String],
        frameworks: [String] = [],
        detectedTypes: [ProjectType] = []
    ) {
        self.primaryType = primaryType
        self.confidence = confidence
        self.indicators = indicators
        self.frameworks = frameworks
        self.detectedTypes = detectedTypes.isEmpty ? [primaryType] : detectedTypes
    }
}

// MARK: - Project Type Detector

/// Detects project type based on marker files and directory structure.
///
/// ```swift
/// let detector = ProjectTypeDetector()
/// let result = try await detector.detect(at: projectURL)
/// print(result.primaryType.displayName)
/// ```
///
/// > Since: 0.4.0
public actor ProjectTypeDetector {
    private let fileManager = FileManager.default

    /// Create a new project type detector.
    public init() {}

    /// Detect the project type at a given directory.
    /// - Parameter directory: The root directory URL to inspect.
    /// - Returns: A ``ProjectDetectionResult`` with the detected type, confidence, and metadata.
    public func detect(at directory: URL) async throws -> ProjectDetectionResult {
        var confidence: Double = 0.0
        var indicators: [String] = []
        var frameworks: [String] = []
        var detectedTypes: [ProjectType] = []

        let markers = try discoverMarkerFiles(at: directory)

        // Swift detection
        if markers.contains("Package.swift") {
            detectedTypes.append(.swiftPackage)
            indicators.append("Package.swift")
            confidence = max(confidence, 0.95)
        } else if markers.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
            detectedTypes.append(.xcodeProject)
            indicators.append("Xcode project")
            confidence = max(confidence, 0.95)
        }

        // Node.js detection
        if markers.contains("package.json") {
            detectedTypes.append(.nodeJS)
            indicators.append("package.json")
            confidence = max(confidence, 0.95)

            if let packageJson = try? readPackageJson(at: directory) {
                if packageJson.hasFramework("next") {
                    detectedTypes.append(.nextJS)
                    frameworks.append("Next.js")
                    confidence = 1.0
                } else if packageJson.hasFramework("react") {
                    detectedTypes.append(.react)
                    frameworks.append("React")
                }

                if packageJson.hasFramework("express") {
                    frameworks.append("Express")
                }
            }
        }

        // Python detection
        if markers.contains("setup.py") || markers.contains("pyproject.toml") || markers.contains("requirements.txt") {
            detectedTypes.append(.python)
            indicators.append("Python project files")
            confidence = max(confidence, 0.95)

            if markers.contains("manage.py") {
                detectedTypes.append(.django)
                frameworks.append("Django")
                confidence = 0.95
            }

            if try await containsFastAPIImports(at: directory) {
                detectedTypes.append(.fastAPI)
                frameworks.append("FastAPI")
                confidence = 0.95
            }
        }

        // Go detection
        if markers.contains("go.mod") {
            detectedTypes.append(.go)
            indicators.append("go.mod")
            confidence = max(confidence, 0.95)
        }

        // Rust detection
        if markers.contains("Cargo.toml") {
            detectedTypes.append(.rust)
            indicators.append("Cargo.toml")
            confidence = max(confidence, 0.95)
        }

        // Java/Maven detection
        if markers.contains("pom.xml") {
            detectedTypes.append(.java)
            indicators.append("pom.xml")
            confidence = max(confidence, 0.95)

            if try await isSpringBootProject(at: directory) {
                detectedTypes.append(.springBoot)
                frameworks.append("Spring Boot")
                confidence = 0.95
            }
        }

        // Gradle detection
        if markers.contains("build.gradle") || markers.contains("build.gradle.kts") {
            detectedTypes.append(.java)
            indicators.append("Gradle build")
            confidence = max(confidence, 0.95)
        }

        // C++ detection
        if markers.contains("CMakeLists.txt") {
            detectedTypes.append(.cpp)
            indicators.append("CMakeLists.txt")
            confidence = max(confidence, 0.95)
        }

        // C#/.NET detection
        if markers.contains(where: { $0.hasSuffix(".csproj") || $0.hasSuffix(".sln") }) {
            detectedTypes.append(.csharp)
            indicators.append("C#/.NET project")
            confidence = max(confidence, 0.95)
        }

        // Ruby detection
        if markers.contains("Gemfile") || markers.contains("Rakefile") {
            detectedTypes.append(.ruby)
            indicators.append("Ruby project")
            confidence = max(confidence, 0.95)
        }

        let primaryType = determinePrimaryType(from: detectedTypes)

        return ProjectDetectionResult(
            primaryType: primaryType,
            confidence: confidence,
            indicators: indicators,
            frameworks: frameworks,
            detectedTypes: detectedTypes
        )
    }

    // MARK: - Helper Methods

    private func discoverMarkerFiles(at directory: URL) throws -> [String] {
        var markers: [String] = []

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        for item in contents {
            markers.append(item.lastPathComponent)
        }

        return markers
    }

    private func determinePrimaryType(from types: [ProjectType]) -> ProjectType {
        if types.isEmpty {
            return .unknown
        }

        if types.count == 1 {
            return types[0]
        }

        if types.contains(.nextJS) {
            return .nextJS
        } else if types.contains(.react) {
            return .react
        } else if types.contains(.django) {
            return .django
        } else if types.contains(.fastAPI) {
            return .fastAPI
        } else if types.contains(.springBoot) {
            return .springBoot
        } else if types.contains(.xcodeProject) {
            return .xcodeProject
        } else if types.contains(.swiftPackage) {
            return .swiftPackage
        } else if types.contains(.cpp) {
            return .cpp
        } else if types.contains(.csharp) {
            return .csharp
        } else if types.contains(.ruby) {
            return .ruby
        } else {
            return .mixed
        }
    }

    // MARK: - Framework Detection

    private func readPackageJson(at directory: URL) throws -> PackageJson? {
        let path = directory.appendingPathComponent("package.json")
        guard fileManager.fileExists(atPath: path.path) else {
            return nil
        }

        let data = try Data(contentsOf: path)
        return try? JSONDecoder().decode(PackageJson.self, from: data)
    }

    private func containsFastAPIImports(at directory: URL) async throws -> Bool {
        let pythonFiles = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "py" }

        for file in pythonFiles.prefix(10) {
            if let content = try? String(contentsOf: file, encoding: .utf8) {
                if content.contains("from fastapi import") || content.contains("import fastapi") {
                    return true
                }
            }
        }

        return false
    }

    private func isSpringBootProject(at directory: URL) async throws -> Bool {
        let pomPath = directory.appendingPathComponent("pom.xml")
        guard let pomContent = try? String(contentsOf: pomPath, encoding: .utf8) else {
            return false
        }

        return pomContent.contains("spring-boot-starter")
    }
}

// MARK: - Package.json Support

private struct PackageJson: Codable, Sendable {
    let name: String?
    let dependencies: [String: String]?
    let devDependencies: [String: String]?

    func hasFramework(_ name: String) -> Bool {
        if let deps = dependencies, deps.keys.contains(where: { $0.lowercased() == name.lowercased() }) {
            return true
        }
        if let devDeps = devDependencies, devDeps.keys.contains(where: { $0.lowercased() == name.lowercased() }) {
            return true
        }
        return false
    }
}
