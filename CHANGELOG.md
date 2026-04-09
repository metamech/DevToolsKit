# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — next minor

### Added

- `RetentionArchiver` protocol and `RetentionPruneReason` enum in `DevToolsKitMetricsStore`.
  Conforming types can be attached to `RetentionPolicy.archiver` to receive each batch of
  `MetricObservation` rows immediately before they are permanently deleted (TTL expiry or
  size-cap enforcement).  Archiver errors are logged at warning level and never block deletion.
- `RetentionPolicy.archiver: (any RetentionArchiver)?` property (default `nil`).  When `nil`,
  behavior is byte-identical to previous releases — no extra fetches are performed.
  When set, TTL purges use a fetch→archive→delete loop with a batch size of 8,000 rows
  (`RetentionEngine.ttlPurgeBatchSize`); size-cap purges archive each existing 500-row batch.
