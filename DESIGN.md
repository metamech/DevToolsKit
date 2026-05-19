# DTK #79 — Batched + Best-Effort Metrics Writes

Target: cut the ~4s of main-thread wall time Tenrec sees during the startup metrics drain, by reshaping `PersistentMetricsStorage` so the emit path is non-blocking, drops are explicit, and the actor side coalesces work per drain.

Version bump: **0.14.2 → 0.15.0** (additive API, one deprecation; no source-breaking renames).

---

## 1. Current state (read from worktree)

### `PersistentMetricsStorage.swift` (Storage/, 247 lines)

- `@MainActor @Observable final class`, `Sendable` (line 27–29).
- Buffer: `private var buffer: [MetricEntry] = []` — main-actor isolated; emitters hit it directly via `record(_:)` (line 67).
- `record(_:)` synchronously appends to `buffer`, and at `count >= batchSize` spawns `Task { await flushNow() }` (line 67–74). The caller of `record` *is* on the main actor (it's the only place `buffer` is touched), so every emit pays a main-actor hop.
- `scheduleFlush()` (line 223–231): single `Task { [weak self] in while !Task.isCancelled { sleep(flushInterval); await self?.flushNow() } }`. The closure inherits `@MainActor` from `self`, so the sleep loop runs on the main actor.
- `flushNow()` (line 211–219): drains `buffer`, maps to DTOs, calls `try? await metricsActor.insert(dtos)`. Already one actor hop per drain — good.

### `MetricsStoreActor.insert(_:)` (MetricsStoreActor.swift line 104–120)

```
for dto in dtos {
    let obs = MetricObservation(...)
    modelContext.insert(obs)
    upsertDefinition(label: ..., typeRawValue: ..., dto: dto)   // line 117
}
try modelContext.save()  // single save per drain — good
```

This **already is** "one transaction per drain, N inserts inside" at the SwiftData layer. The cost is **not** N transactions. It is:

1. **`upsertDefinition` does a per-DTO fetch with `#Predicate`** (line 228–268). At 1000 entries on a cold start this is 1000 SwiftData fetches inside a single `save()` envelope — that's the ~4s.
2. **No backpressure / coalescing in the buffer.** A flood of emits during startup all queue identical `Counter("foo")` increments as distinct rows; we can't drop them and we can't merge them.
3. **`scheduleFlush` fires its first flush at `t = flushInterval` (1s)** unconditionally — but `record(_:)` triggers an immediate `Task { await flushNow() }` when `buffer.count >= batchSize`. Startup hits 50 entries instantly and the first flush lands during launch.

### Public surface (must preserve)

```swift
init(metricsActor:modelContainer:batchSize:flushInterval:)   // public
func record(_ entry: MetricEntry)                            // MetricsStorage
func query(_:), summary(for:), knownMetrics(), clear(), purge(olderThan:)
public var entryCount: Int
public func flushNow() async                                 // public, since 0.7.0
Notification.Name.metricsStoreDidFlush                       // public
```

Tenrec calls `record`, `flushNow`, and reads `entryCount`; tests construct via the four-arg init.

---

## 2. Proposal

### 2a. Batched per-drain — cut per-DTO definition fetches

Add `MetricsStoreActor.insertBatched(_ dtos:)`:

1. Group DTOs by `(label, typeRawValue)` → `[Key: [DTO]]`.
2. **One** `FetchDescriptor<MetricDefinition>` with an `IN` predicate over the distinct keys (or one per key, but at most `distinctKeys.count`, not `dtos.count`).
3. Loop over groups: insert all observations for a key, then upsert the definition **once** (sum the count, union dimension keys, take max `lastSeenAt`).
4. Single `modelContext.save()`.

Expected effect: 1000 emits with ~10 distinct labels collapse from 1000 fetches → 10 fetches. Keep `insert(_:)` as a thin shim that calls `insertBatched` so v0.14.2 callers (none external) keep compiling.

### 2b. Best-effort queue — **ring buffer (drop oldest)**

Why ring buffer over the other two:
- **Count-cap + reject newest** loses the *most recent* signal during a burst — useless for "what's happening *now*" diagnostics.
- **Key-coalesce** is tempting but only safe for counters/gauges-with-no-dimensions; merging timers / histograms changes semantics and we'd need per-type policy. Out of scope for #79.
- **Ring buffer** is one decision (cap), drops are explicit (telemetry counter), and dropping oldest matches our "metrics must not block, recent > historical" contract.

Sketch:

```swift
private struct RingBuffer<T> {
    private var storage: [T?]; private var head = 0; private var count = 0
    var droppedCount: UInt64 = 0
    mutating func append(_ x: T) { /* overwrite head if full, advance, ++drop */ }
    mutating func drain() -> [T]
}
```

Default cap: `max(batchSize * 8, 1024)` — 8× burst headroom. Configurable via new init param `bufferCapacity: Int = 0` where `0` means "derive from batchSize".

### 2c. Cold-start defer

Two-gate: **don't flush until either** (a) `firstFlushDelay` (default 2s) has elapsed **or** (b) `buffer.count >= batchSize * 4` (default 200) — whichever comes first.

After the first flush, normal `flushInterval` cadence takes over. This gives Tenrec startup time to settle before the metrics actor wakes its SwiftData context. Override via init: `firstFlushDelay: TimeInterval = 2.0`.

### 2d. Isolation contract — `flushNow` must not be sync-callable from `@MainActor`

Today `flushNow` is `public func ... async` on a `@MainActor` class — calling `await storage.flushNow()` from main is legal and parks main during the actor hop. Two changes:

1. **Move buffer state off `@MainActor`.** Introduce a `private actor BufferActor { var ring; var droppedCount; func append/drain }`. `PersistentMetricsStorage` stays `@MainActor @Observable` for `@Observable` to function, but `record(_:)` becomes `nonisolated` and dispatches to the buffer actor:

   ```swift
   public nonisolated func record(_ entry: MetricEntry) {
       Task { await bufferActor.append(entry) }   // fire-and-forget
   }
   ```

   This makes the emit path **truly non-blocking** — the caller doesn't even take a main-actor hop, just enqueues a Task. The Tenrec hot path sees ~microseconds.

2. **`flushNow()` stays `async`** but is now intrinsically off-main (it talks to `bufferActor` then `metricsActor`, both non-main actors). The "can't be called sync from main" property is enforced by it being `async` + the fact that the body never touches main-actor state. Document this with a `// flushNow is intentionally async; never call it via a synchronous wrapper` comment.

`unflushedEntries` (internal) and the `@Observable` `buffer` exposure for `query()` change: `query()` currently does `var buffered = buffer` synchronously (line 111). We need a fast `nonisolated` snapshot — `bufferActor.snapshot()` is `async`, which would force `query()` async (breaking). Solution: keep a **second** main-actor-isolated `recentSnapshot: [MetricEntry]` updated by the buffer actor via a callback on each append (bounded, e.g. last 256 entries). Reads stay sync; the snapshot may lag by a few microseconds, which is fine for query merge.

### 2e. Telemetry (non-recursive)

Two pieces of data, exposed via existing swift-metrics `Counter`/`Gauge` labels (we already depend on `Metrics`):

- `Counter("devtoolskit.metrics.buffer.dropped").increment(by: n)` — emitted at drain time from the count accumulated by the ring buffer. **Non-recursive** because emitting goes through `swift-metrics` which fans out to *whatever backend the host registered*, not back through `PersistentMetricsStorage` (which is one such backend — and if it *is* the backend, the increment hits our own `record` and gets queued like any other; that's fine since we drop on overflow rather than infinite-loop).
- `Gauge("devtoolskit.metrics.flush.duration.ms").record(...)` — wall time of each `insertBatched` call, measured with `ContinuousClock.now` at the actor.

Additionally expose `public var droppedSinceLaunch: UInt64 { get async }` for tests and the dashboard.

### 2f. API compatibility (v0.15.0)

**Additive:**

```swift
public init(
    metricsActor: MetricsStoreActor,
    modelContainer: ModelContainer,
    batchSize: Int = 50,
    flushInterval: TimeInterval = 1.0,
    bufferCapacity: Int = 0,           // new — 0 means auto
    firstFlushDelay: TimeInterval = 2.0 // new
)
```

The existing four-arg init becomes a convenience that forwards to the new one. No breakage.

`record(_:)` becomes `nonisolated` — this is **source-compatible** for all callers (sync calls still work) but technically an ABI/MainActor-contract change. Acceptable in a 0.x minor bump; document in CHANGELOG.

`MetricsStoreActor.insert(_:)` stays as-is, internally delegates to `insertBatched(_:)`. No deprecation in 0.15.0; consider `@available(*, deprecated)` in 0.16.0 if we want.

---

## 3. Test scaffolding

Add to `Tests/DevToolsKitMetricsStoreTests/`:

- `BufferActorRingBufferTests.swift` — unit: append past cap drops oldest, `droppedCount` accurate, drain empties.
- `PersistentMetricsStorageBatchingTests.swift` — integration: 1000 emits with 5 distinct labels produces ≤5 definition fetches (verify via spy/counter on `MetricsStoreActor` or by asserting wall-time bound).
- `PersistentMetricsStorageColdStartTests.swift` — verify no flush within `firstFlushDelay` unless burst threshold hit; verify first flush *does* fire on burst.
- `PersistentMetricsStorageDropTests.swift` — flood past `bufferCapacity` while actor is held; verify dropped counter and that recent entries survived (oldest dropped).
- **Perf**: extend `MetricsStoreActorConcurrencyTests.swift` (or new `MetricsStoreActorPerfTests.swift`) with an XCTest measure block: 5000 inserts across 50 labels < 200ms (regression guard for the 4s Tenrec observation, with headroom for CI slowness).

Existing `PersistentMetricsStorageTests.swift` requires minor updates: `flushInterval: 60` long-flush trick still works; some tests assume `record(_:)` is synchronously visible in `buffer` immediately (line 88, 101, 131) — those need a `await storage.flushNow()` or a new `await storage.drainForTest()` since the buffer is now actor-isolated and `record` is fire-and-forget.

---

## 4. Risks / open questions for the user

1. **`record(_:)` becoming `nonisolated` + fire-and-forget changes observability semantics.** A test that calls `record(x); XCTAssertEqual(storage.entryCount, 1)` will now race. We have such patterns (line 88 of the existing test). I'll fix the tests, but downstream Tenrec test suites may have the same pattern. **Mitigation:** add an internal `await storage._testWaitForPendingAppends()`. Worth flagging.

2. **`@Observable` + actor-isolated buffer.** SwiftUI observers watching `buffer` via the `@Observable` macro will no longer see live updates (the buffer moved to an actor). The `recentSnapshot` mirror handles `query()` merge but not arbitrary observers. **Question:** does Tenrec actually observe the buffer? Grep suggests no — the macro is on the class but `buffer` isn't `public`. If it stays private/internal we're fine.

3. **Ring-buffer cap default of `max(batchSize*8, 1024)` is a guess.** Worth a heuristic check against Tenrec's startup emit rate. If startup emits ~5k entries in 1s, the buffer fills before the 2s `firstFlushDelay` and we drop the early signal. Two mitigations: (a) make `firstFlushDelay` shorter (1s), or (b) raise default cap to 4096. **Recommend:** start at `4096` and `firstFlushDelay = 1.5s`; revisit after we measure.

4. **`upsertDefinition` correctness under batching.** The grouped path must produce the same `totalObservations` / `knownDimensionKeysJSON` as the per-DTO path. Need a parity test (run both, diff result). Easy but mandatory.

5. **What does Tenrec's `MetricsStack`/`MetricsDatabase` use for the first launch?** Confirm they don't pre-warm `insert` with empty data; otherwise the cold-start defer adds 2s to test-suite cycles. Grep before implementation.

---

## Summary for the next agent (Swift engineer)

**Start by extracting a `private actor BufferActor` inside `PersistentMetricsStorage.swift` with a ring buffer (cap default 4096), make `record(_:)` `nonisolated`, and route appends through it.** Land that as Phase 1 — it unblocks everything else and is independently testable. Phase 2: `MetricsStoreActor.insertBatched`. Phase 3: cold-start defer + telemetry counters.

Files to touch:
- `/Users/ion/go/src/github.com/metamech/DevToolsKit/.claude/worktrees/perf-79-metrics-batched-best-effort/Sources/DevToolsKitMetricsStore/Storage/PersistentMetricsStorage.swift`
- `/Users/ion/go/src/github.com/metamech/DevToolsKit/.claude/worktrees/perf-79-metrics-batched-best-effort/Sources/DevToolsKitMetricsStore/MetricsStoreActor.swift` (add `insertBatched`)
- `/Users/ion/go/src/github.com/metamech/DevToolsKit/.claude/worktrees/perf-79-metrics-batched-best-effort/Tests/DevToolsKitMetricsStoreTests/PersistentMetricsStorageTests.swift` (update assertions)
- New: `Tests/DevToolsKitMetricsStoreTests/BufferActorRingBufferTests.swift`, `PersistentMetricsStorageBatchingTests.swift`, `PersistentMetricsStorageColdStartTests.swift`, `PersistentMetricsStorageDropTests.swift`.
