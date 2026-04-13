import Foundation
import Testing

@testable import DevToolsKitLicensing

@Suite(.serialized)
@MainActor
struct DiagnosticProviderTests {
    @Test func sectionNameIsLicensing() {
        let backend = MockBackend()
        let prefix = "test.\(UUID().uuidString)"
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        #expect(manager.sectionName == "licensing")
    }

    @Test func collectReturnsDiagnosticData() async {
        let backend = MockBackend()
        backend.activeEntitlements = ["premium"]
        let prefix = "test.\(UUID().uuidString)"
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        let result = await manager.collect()
        // Verify we get a Codable value (if it encodes without error, it's valid)
        let encoder = JSONEncoder()
        let data = try? encoder.encode(AnyCodableWrapper(result))
        #expect(data != nil)
    }
}

/// Test helper for encoding any Codable value.
private struct AnyCodableWrapper: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ value: any Codable & Sendable) {
        self.encodeClosure = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
