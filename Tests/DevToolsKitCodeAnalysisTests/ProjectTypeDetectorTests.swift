import Foundation
import Testing
@testable import DevToolsKitCodeAnalysis

@Suite("Project Type Detector")
struct ProjectTypeDetectorTests {

    // MARK: - Setup

    private func makeTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtoolskit-project-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanup(_ tempDir: URL) {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Swift Project Detection

    @Test("Detects Swift package from Package.swift")
    func detectSwiftPackage() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let packageSwift = tempDir.appendingPathComponent("Package.swift")
        try "// swift-tools-version: 6.0".write(to: packageSwift, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .swiftPackage)
        #expect(result.confidence > 0.9)
        #expect(result.indicators.contains("Package.swift"))
    }

    @Test("Detects Xcode project from .xcodeproj")
    func detectXcodeProject() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let xcodeproj = tempDir.appendingPathComponent("MyApp.xcodeproj")
        try FileManager.default.createDirectory(at: xcodeproj, withIntermediateDirectories: true)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .xcodeProject)
        #expect(result.confidence > 0.9)
    }

    // MARK: - Node.js Project Detection

    @Test("Detects Node.js from package.json")
    func detectNodeJS() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let packageJson = """
        {
          "name": "my-app",
          "dependencies": {}
        }
        """
        let packagePath = tempDir.appendingPathComponent("package.json")
        try packageJson.write(to: packagePath, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .nodeJS)
        #expect(result.confidence > 0.9)
    }

    @Test("Detects Next.js from package.json with next dependency")
    func detectNextJS() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let packageJson = """
        {
          "name": "my-app",
          "dependencies": {
            "next": "^14.0.0",
            "react": "^18.0.0"
          }
        }
        """
        let packagePath = tempDir.appendingPathComponent("package.json")
        try packageJson.write(to: packagePath, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .nextJS)
        #expect(result.confidence == 1.0)
        #expect(result.frameworks.contains("Next.js"))
    }

    @Test("Detects React from package.json with react dependency")
    func detectReact() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let packageJson = """
        {
          "name": "my-app",
          "dependencies": {
            "react": "^18.0.0",
            "react-dom": "^18.0.0"
          }
        }
        """
        let packagePath = tempDir.appendingPathComponent("package.json")
        try packageJson.write(to: packagePath, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .react)
        #expect(result.frameworks.contains("React"))
    }

    // MARK: - Python Project Detection

    @Test("Detects Python from requirements.txt")
    func detectPython() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let requirements = tempDir.appendingPathComponent("requirements.txt")
        try "requests==2.28.0".write(to: requirements, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .python)
        #expect(result.confidence > 0.9)
    }

    @Test("Detects Django from manage.py + requirements.txt")
    func detectDjango() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let managePy = tempDir.appendingPathComponent("manage.py")
        try "#!/usr/bin/env python".write(to: managePy, atomically: true, encoding: .utf8)

        let requirements = tempDir.appendingPathComponent("requirements.txt")
        try "Django==4.2.0".write(to: requirements, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .django)
        #expect(result.confidence > 0.9)
        #expect(result.frameworks.contains("Django"))
    }

    // MARK: - Go Project Detection

    @Test("Detects Go from go.mod")
    func detectGo() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let goMod = tempDir.appendingPathComponent("go.mod")
        try "module example.com/myapp".write(to: goMod, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .go)
        #expect(result.confidence > 0.9)
        #expect(result.indicators.contains("go.mod"))
    }

    // MARK: - Rust Project Detection

    @Test("Detects Rust from Cargo.toml")
    func detectRust() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let cargoToml = tempDir.appendingPathComponent("Cargo.toml")
        try "[package]\nname = \"myapp\"".write(to: cargoToml, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .rust)
        #expect(result.confidence > 0.9)
        #expect(result.indicators.contains("Cargo.toml"))
    }

    // MARK: - Java Project Detection

    @Test("Detects Java from pom.xml")
    func detectMaven() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let pomXml = tempDir.appendingPathComponent("pom.xml")
        try "<project></project>".write(to: pomXml, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .java)
        #expect(result.confidence > 0.9)
        #expect(result.indicators.contains("pom.xml"))
    }

    @Test("Detects Java from build.gradle")
    func detectGradle() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let buildGradle = tempDir.appendingPathComponent("build.gradle")
        try "plugins {}".write(to: buildGradle, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .java)
        #expect(result.confidence > 0.9)
        #expect(result.indicators.contains("Gradle build"))
    }

    // MARK: - C++ Project Detection

    @Test("Detects C++ from CMakeLists.txt")
    func detectCpp() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let cmakeLists = tempDir.appendingPathComponent("CMakeLists.txt")
        try "cmake_minimum_required(VERSION 3.10)".write(to: cmakeLists, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .cpp)
        #expect(result.confidence > 0.9)
        #expect(result.indicators.contains("CMakeLists.txt"))
    }

    // MARK: - C# Project Detection

    @Test("Detects C# from .csproj")
    func detectCSharpWithCsproj() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let csprojPath = tempDir.appendingPathComponent("MyApp.csproj")
        try "<Project Sdk=\"Microsoft.NET.Sdk\"></Project>".write(to: csprojPath, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .csharp)
        #expect(result.confidence > 0.9)
        #expect(result.indicators.contains("C#/.NET project"))
    }

    @Test("Detects C# from .sln")
    func detectCSharpWithSln() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let slnPath = tempDir.appendingPathComponent("MySolution.sln")
        try "Microsoft Visual Studio Solution File".write(to: slnPath, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .csharp)
        #expect(result.confidence > 0.9)
    }

    // MARK: - Ruby Project Detection

    @Test("Detects Ruby from Gemfile")
    func detectRubyWithGemfile() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let gemfile = tempDir.appendingPathComponent("Gemfile")
        try "source 'https://rubygems.org'".write(to: gemfile, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .ruby)
        #expect(result.confidence > 0.9)
        #expect(result.indicators.contains("Ruby project"))
    }

    @Test("Detects Ruby from Rakefile")
    func detectRubyWithRakefile() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let rakefile = tempDir.appendingPathComponent("Rakefile")
        try "task :default do\nend".write(to: rakefile, atomically: true, encoding: .utf8)

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .ruby)
        #expect(result.confidence > 0.9)
    }

    // MARK: - Unknown Project

    @Test("Empty directory returns unknown type")
    func detectUnknown() async throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let detector = ProjectTypeDetector()
        let result = try await detector.detect(at: tempDir)

        #expect(result.primaryType == .unknown)
        #expect(result.confidence == 0.0)
    }

    // MARK: - Project Type Display Names

    @Test("ProjectType display names")
    func projectTypeDisplayNames() {
        #expect(ProjectType.swiftPackage.displayName == "Swift Package")
        #expect(ProjectType.xcodeProject.displayName == "Xcode Project")
        #expect(ProjectType.nodeJS.displayName == "Node.js")
        #expect(ProjectType.react.displayName == "React")
        #expect(ProjectType.nextJS.displayName == "Next.js")
        #expect(ProjectType.python.displayName == "Python")
        #expect(ProjectType.django.displayName == "Django")
        #expect(ProjectType.go.displayName == "Go")
        #expect(ProjectType.rust.displayName == "Rust")
        #expect(ProjectType.java.displayName == "Java")
        #expect(ProjectType.cpp.displayName == "C++")
        #expect(ProjectType.csharp.displayName == "C#/.NET")
        #expect(ProjectType.ruby.displayName == "Ruby")
        #expect(ProjectType.unknown.displayName == "Unknown")
    }
}
