import Foundation

/// Shared lifecycle contract for all two-phase action providers.
///
/// Action providers follow a two-phase init pattern: the ``ActionRegistryProtocol``
/// is injected at construction time (app startup), but view-level dependencies
/// arrive later via a provider-specific `configure()` method.
///
/// ## Conformance Requirements
///
/// Conforming types must:
/// 1. Store a `registry` property and expose it as the protocol property.
/// 2. Store `var isConfigured: Bool` and expose it as the protocol property.
/// 3. Implement ``registerAll()`` — all action registration logic goes here.
/// 4. Optionally override ``refreshAll()`` — defaults to calling ``registerAll()``.
///
/// ## Typical configure() Implementation
///
/// ```swift
/// func configure(dependency: SomeType) {
///     self.dependency = dependency
///     markConfigured()   // sets isConfigured = true, calls registerAll()
/// }
/// ```
///
/// > Note: `configure()` is intentionally not on the protocol because each
/// > provider has a unique set of dependencies with distinct signatures.
@MainActor
public protocol ActionProviderProtocol: AnyObject {
    /// The registry where actions are registered.
    var registry: ActionRegistryProtocol { get }

    /// Set to `true` by ``markConfigured()`` after all dependencies have arrived.
    var isConfigured: Bool { get set }

    /// Register (or re-register) all actions owned by this provider.
    /// Must be idempotent — ``ActionRegistryProtocol/register(_:)-1a2b`` upserts by ID.
    func registerAll()

    /// Refresh dynamic action state (subtitles, enabled state, children).
    /// Default implementation calls ``registerAll()``.
    func refreshAll()
}

// MARK: - Default Implementations

extension ActionProviderProtocol {
    /// Marks the provider as configured and triggers initial registration.
    /// Call this at the end of every `configure()` method.
    public func markConfigured() {
        isConfigured = true
        registerAll()
    }

    /// Default `refreshAll` delegates to ``registerAll()``.
    public func refreshAll() {
        guard isConfigured else { return }
        registerAll()
    }

    /// Returns `true` when the provider is ready to register actions.
    public var canRegister: Bool { isConfigured }
}
