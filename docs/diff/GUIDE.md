[< GitHub](../github/GUIDE.md) | [Index](../INDEX.md) | [API >](API.md)

# DevToolsKitDiff Guide

Unified diff parsing, application, and validation.

## Setup

```swift
.product(name: "DevToolsKitDiff", package: "DevToolsKit")
```

```swift
import DevToolsKitDiff
```

## Parsing a Diff

```swift
let engine = DiffEngine()

let diffText = """
--- a/file.txt
+++ b/file.txt
@@ -1,3 +1,3 @@
 line1
-line2
+modified
 line3
"""

let diff = try engine.parse(diffText)
// diff.originalFile == "a/file.txt"
// diff.hunks.count == 1
```

## Applying to a File

Apply changes to a file on disk with automatic backup:

```swift
try engine.apply(diff, to: fileURL, dryRun: false)
```

Use `dryRun: true` to validate without modifying:

```swift
try engine.apply(diff, to: fileURL, dryRun: true)
```

## Applying to Content

Apply changes to in-memory content:

```swift
let original = "line1\nline2\nline3"
let result = try engine.apply(diff, to: original)
// result == "line1\nmodified\nline3"
```

## Validation

Check diff structure for warnings:

```swift
let warnings = engine.validate(diff)
// Empty array = valid diff
```

Warnings include:
- "Diff contains no hunks"
- "Hunk N has zero line counts"
- "Hunk N has no lines"
