import Foundation
import Testing
@testable import DevToolsKitCodeAnalysis

@Suite("Language Detector")
struct LanguageDetectorTests {

    @Test("Detects Swift files")
    func detectSwift() {
        #expect(LanguageDetector.detect(filename: "main.swift") == .swift)
    }

    @Test("Detects Python files")
    func detectPython() {
        #expect(LanguageDetector.detect(filename: "app.py") == .python)
    }

    @Test("Detects JavaScript files")
    func detectJavaScript() {
        #expect(LanguageDetector.detect(filename: "index.js") == .javascript)
        #expect(LanguageDetector.detect(filename: "module.mjs") == .javascript)
    }

    @Test("Detects TypeScript files")
    func detectTypeScript() {
        #expect(LanguageDetector.detect(filename: "app.ts") == .typescript)
    }

    @Test("Detects Go files")
    func detectGo() {
        #expect(LanguageDetector.detect(filename: "main.go") == .go)
    }

    @Test("Detects Rust files")
    func detectRust() {
        #expect(LanguageDetector.detect(filename: "lib.rs") == .rust)
    }

    @Test("Detects C and C++ files")
    func detectCAndCpp() {
        #expect(LanguageDetector.detect(filename: "main.c") == .c)
        #expect(LanguageDetector.detect(filename: "header.h") == .c)
        #expect(LanguageDetector.detect(filename: "main.cpp") == .cpp)
        #expect(LanguageDetector.detect(filename: "main.cc") == .cpp)
        #expect(LanguageDetector.detect(filename: "header.hpp") == .cpp)
    }

    @Test("Detects Java files")
    func detectJava() {
        #expect(LanguageDetector.detect(filename: "Main.java") == .java)
    }

    @Test("Detects Kotlin files")
    func detectKotlin() {
        #expect(LanguageDetector.detect(filename: "App.kt") == .kotlin)
        #expect(LanguageDetector.detect(filename: "build.kts") == .kotlin)
    }

    @Test("Detects Ruby files")
    func detectRuby() {
        #expect(LanguageDetector.detect(filename: "app.rb") == .ruby)
    }

    @Test("Detects shell scripts")
    func detectShell() {
        #expect(LanguageDetector.detect(filename: "setup.sh") == .shell)
        #expect(LanguageDetector.detect(filename: "run.bash") == .shell)
        #expect(LanguageDetector.detect(filename: "profile.zsh") == .shell)
    }

    @Test("Detects web and data files")
    func detectWebAndData() {
        #expect(LanguageDetector.detect(filename: "index.html") == .html)
        #expect(LanguageDetector.detect(filename: "style.css") == .css)
        #expect(LanguageDetector.detect(filename: "data.json") == .json)
        #expect(LanguageDetector.detect(filename: "config.yaml") == .yaml)
        #expect(LanguageDetector.detect(filename: "config.yml") == .yaml)
        #expect(LanguageDetector.detect(filename: "layout.xml") == .xml)
        #expect(LanguageDetector.detect(filename: "README.md") == .markdown)
    }

    @Test("Unknown extension returns .unknown")
    func detectUnknown() {
        #expect(LanguageDetector.detect(filename: "file.xyz") == .unknown)
        #expect(LanguageDetector.detect(filename: "noextension") == .unknown)
    }

    @Test("Detects from URL")
    func detectFromURL() {
        let url = URL(fileURLWithPath: "/path/to/main.swift")
        #expect(LanguageDetector.detect(path: url) == .swift)
    }

    @Test("ProgrammingLanguage display names")
    func displayNames() {
        #expect(ProgrammingLanguage.swift.displayName == "Swift")
        #expect(ProgrammingLanguage.cpp.displayName == "C++")
        #expect(ProgrammingLanguage.javascript.displayName == "JavaScript")
        #expect(ProgrammingLanguage.typescript.displayName == "TypeScript")
        #expect(ProgrammingLanguage.json.displayName == "JSON")
    }
}
