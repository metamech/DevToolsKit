import Testing
import Foundation
@testable import DevToolsKitSecurity

@Suite("FileSystemUtility")
struct FileSystemUtilityTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtoolskit-fsutil-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    // MARK: - Path Resolution

    @Test func resolveAbsolutePath() {
        let result = FileSystemUtility.resolveURL(from: "/usr/local/bin/test", workingDirectory: tempDir)
        #expect(result.path == "/usr/local/bin/test")
    }

    @Test func resolveRelativePath() {
        let result = FileSystemUtility.resolveURL(from: "subdir/file.txt", workingDirectory: tempDir)
        let expected = tempDir.appendingPathComponent("subdir/file.txt")
        #expect(result.path == expected.path)
    }

    // MARK: - Standardization

    @Test func standardizeURLRemovesDotComponents() {
        let url = URL(fileURLWithPath: tempDir.path + "/./subdir/../file.txt")
        let result = FileSystemUtility.standardizeURL(url)
        #expect(!result.path.contains("./"))
        #expect(!result.path.contains("../"))
    }

    @Test func standardizePathResolvesSymlinks() {
        let varURL = URL(fileURLWithPath: "/var/tmp")
        let result = FileSystemUtility.standardizePath(varURL)
        #expect(result.contains("/tmp"))
    }

    // MARK: - Sandbox Validation

    @Test func isAllowedWithinSandbox() {
        let fileURL = tempDir.appendingPathComponent("test.txt")
        let allowedPaths: Set<URL> = [tempDir]
        #expect(FileSystemUtility.isAllowed(fileURL, in: allowedPaths))
    }

    @Test func isAllowedOutsideSandbox() {
        let fileURL = URL(fileURLWithPath: "/etc/passwd")
        let allowedPaths: Set<URL> = [tempDir]
        #expect(!FileSystemUtility.isAllowed(fileURL, in: allowedPaths))
    }

    @Test func validateSandboxSuccess() throws {
        let fileURL = tempDir.appendingPathComponent("test.txt")
        let allowedPaths: Set<URL> = [tempDir]
        try FileSystemUtility.validateSandbox(path: "test.txt", url: fileURL, allowedPaths: allowedPaths)
    }

    @Test func validateSandboxFailure() {
        let fileURL = URL(fileURLWithPath: "/etc/passwd")
        let allowedPaths: Set<URL> = [tempDir]

        #expect(throws: SandboxError.self) {
            try FileSystemUtility.validateSandbox(
                path: "/etc/passwd", url: fileURL, allowedPaths: allowedPaths
            )
        }
    }

    @Test func standardizeAllowedPaths() {
        let paths: Set<URL> = [tempDir, tempDir.appendingPathComponent("subdir")]
        let standardized = FileSystemUtility.standardizeAllowedPaths(paths)
        #expect(standardized.count == 2)
        for path in standardized {
            #expect(path.hasPrefix("/"))
        }
    }

    @Test func isAllowedWithStandardizedPaths() {
        let allowedPaths: Set<URL> = [tempDir]
        let standardizedPaths = FileSystemUtility.standardizeAllowedPaths(allowedPaths)
        let fileURL = tempDir.appendingPathComponent("test.txt")
        #expect(FileSystemUtility.isAllowed(fileURL, in: standardizedPaths))
    }

    // MARK: - Relative Paths

    @Test func relativePathSimple() {
        let fileURL = tempDir.appendingPathComponent("test.txt")
        let relativePath = FileSystemUtility.relativePath(from: fileURL, to: tempDir)
        #expect(relativePath == "test.txt")
    }

    @Test func relativePathNested() {
        let fileURL = tempDir.appendingPathComponent("subdir/nested/file.txt")
        let relativePath = FileSystemUtility.relativePath(from: fileURL, to: tempDir)
        #expect(relativePath == "subdir/nested/file.txt")
    }

    @Test func relativePathDifferentBase() {
        let fileURL = URL(fileURLWithPath: "/usr/local/file.txt")
        let baseURL = URL(fileURLWithPath: "/etc")
        let relativePath = FileSystemUtility.relativePath(from: fileURL, to: baseURL)
        #expect(relativePath == "file.txt")
    }

    // MARK: - Backups

    @Test func createSimpleBackup() throws {
        let testFile = tempDir.appendingPathComponent("test.txt")
        try "original content".write(to: testFile, atomically: true, encoding: .utf8)

        let backupURL = try FileSystemUtility.createSimpleBackup(of: testFile)
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
        #expect(backupURL.lastPathComponent == "test.txt.backup")

        let backupContent = try String(contentsOf: backupURL, encoding: .utf8)
        #expect(backupContent == "original content")

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func createArchivedBackup() throws {
        let testFile = tempDir.appendingPathComponent("archive-test.txt")
        try "content to archive".write(to: testFile, atomically: true, encoding: .utf8)

        let backupURL = try FileSystemUtility.createArchivedBackup(of: testFile)
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
        #expect(backupURL.path.contains("devtoolskit-backups"))

        let backupContent = try String(contentsOf: backupURL, encoding: .utf8)
        #expect(backupContent == "content to archive")

        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - File System Checks

    @Test func isFile() throws {
        let testFile = tempDir.appendingPathComponent("test.txt")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)

        #expect(FileSystemUtility.isFile(testFile))
        #expect(!FileSystemUtility.isFile(tempDir))

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func isDirectory() throws {
        let subdir = tempDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        #expect(FileSystemUtility.isDirectory(subdir))
        #expect(FileSystemUtility.isDirectory(tempDir))

        let testFile = tempDir.appendingPathComponent("test.txt")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        #expect(!FileSystemUtility.isDirectory(testFile))

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func exists() throws {
        let testFile = tempDir.appendingPathComponent("test.txt")
        #expect(!FileSystemUtility.exists(testFile))

        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        #expect(FileSystemUtility.exists(testFile))

        try FileManager.default.removeItem(at: testFile)
        #expect(!FileSystemUtility.exists(testFile))

        try? FileManager.default.removeItem(at: tempDir)
    }
}
