[< Core](../core/QUICK_START.md) | [Index](../INDEX.md) | [API >](API.md)

# DevToolsKitGitHub Guide

GitHub REST API client with caching, retry logic, and rate limit support.

## Setup

```swift
.product(name: "DevToolsKitGitHub", package: "DevToolsKit")
```

```swift
import DevToolsKitGitHub
```

## Basic Usage

```swift
let config = GitHubConfig(token: "ghp_...")
let client = GitHubClient(config: config)

// List directory contents
let files = try await client.listDirectory(owner: "apple", repo: "swift", path: "Sources")

// Download a file
let data = try await client.downloadRawFile(owner: "apple", repo: "swift", path: "README.md")
```

## Authentication

Token resolution priority:
1. `GITHUB_TOKEN` environment variable
2. `GitHubConfig.token` property
3. Unauthenticated (60 requests/hour)

## Caching

API responses are cached in-memory with configurable TTL. Cache is enabled by default.

## Retry

Transient failures (network errors, 5xx, 429) are retried with exponential backoff and jitter.

## Status Panel

Register the GitHub status panel to monitor API usage:

```swift
manager.register(GitHubStatusPanel(client: client))
```
