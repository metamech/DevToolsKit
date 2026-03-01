import Foundation

/// Supported programming languages for code analysis.
///
/// > Since: 0.4.0
public enum ProgrammingLanguage: String, CaseIterable, Codable, Sendable {
    case swift
    case python
    case javascript
    case typescript
    case go
    case rust
    case c
    case cpp
    case java
    case kotlin
    case ruby
    case php
    case html
    case css
    case markdown
    case json
    case yaml
    case xml
    case shell
    case unknown

    /// Human-readable display name for the language.
    public var displayName: String {
        switch self {
        case .cpp: return "C++"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .markdown: return "Markdown"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .xml: return "XML"
        case .shell: return "Shell"
        default: return rawValue.capitalized
        }
    }
}

/// Detects the programming language of a file based on its extension.
///
/// ```swift
/// let lang = LanguageDetector.detect(filename: "main.swift")
/// // lang == .swift
/// ```
///
/// > Since: 0.4.0
public struct LanguageDetector: Sendable {

    /// Detect language from a file URL.
    /// - Parameter path: The file URL.
    /// - Returns: The detected ``ProgrammingLanguage``, or `.unknown`.
    public static func detect(path: URL) -> ProgrammingLanguage {
        let ext = path.pathExtension.lowercased()

        return switch ext {
        case "swift": .swift
        case "py": .python
        case "js", "mjs": .javascript
        case "ts": .typescript
        case "go": .go
        case "rs": .rust
        case "c", "h": .c
        case "cpp", "cc", "cxx", "hpp", "hxx", "h++": .cpp
        case "java": .java
        case "kt", "kts": .kotlin
        case "rb": .ruby
        case "php": .php
        case "html", "htm": .html
        case "css", "scss", "sass": .css
        case "md", "markdown": .markdown
        case "json": .json
        case "yaml", "yml": .yaml
        case "xml": .xml
        case "sh", "bash", "zsh": .shell
        default: .unknown
        }
    }

    /// Detect language from a filename string.
    /// - Parameter filename: The filename or path string.
    /// - Returns: The detected ``ProgrammingLanguage``, or `.unknown`.
    public static func detect(filename: String) -> ProgrammingLanguage {
        let url = URL(fileURLWithPath: filename)
        return detect(path: url)
    }
}
