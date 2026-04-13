import Foundation
import Testing

@testable import DevToolsKitFeatureFlags

@Suite(.serialized)
@MainActor
struct EnrollmentIDTests {
    @Test func generatesStableID() {
        let prefix = "test.\(UUID().uuidString)"
        let enrollment = EnrollmentID(keyPrefix: prefix)

        let id1 = enrollment.value
        let id2 = enrollment.value
        #expect(id1 == id2)
    }

    @Test func resetGeneratesNewID() {
        let prefix = "test.\(UUID().uuidString)"
        let enrollment = EnrollmentID(keyPrefix: prefix)

        let original = enrollment.value
        enrollment.reset()
        let newID = enrollment.value
        #expect(original != newID)
    }

    @Test func expiresAtIsInFuture() {
        let prefix = "test.\(UUID().uuidString)"
        let enrollment = EnrollmentID(keyPrefix: prefix)

        _ = enrollment.value  // trigger generation
        #expect(enrollment.expiresAt > Date())
    }

    @Test func generatedAtIsRecent() {
        let prefix = "test.\(UUID().uuidString)"
        let enrollment = EnrollmentID(keyPrefix: prefix)

        _ = enrollment.value  // trigger generation
        let now = Date()
        #expect(abs(enrollment.generatedAt.timeIntervalSince(now)) < 2)
    }

    @Test func shortIntervalCausesRegeneration() {
        let prefix = "test.\(UUID().uuidString)"
        // Use a very short interval (already expired)
        let enrollment = EnrollmentID(keyPrefix: prefix, regenerationInterval: -1)

        let id1 = enrollment.value
        let id2 = enrollment.value
        // With negative interval, every access regenerates
        #expect(id1 != id2)
    }
}
