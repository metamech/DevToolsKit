import Foundation
import Testing

@testable import DevToolsKitFeatureFlags

@Suite
struct FeatureFlagTests {
    @Test func defaultValues() {
        let flag = FeatureFlag(
            id: "test.flag", name: "Test", description: "Desc")

        #expect(flag.defaultEnabled == false)
        #expect(flag.category == "General")
    }

    @Test func hashableConformance() {
        let flag1 = FeatureFlag(
            id: "test.a", name: "A", description: "Desc")
        let flag2 = FeatureFlag(
            id: "test.a", name: "A", description: "Desc")
        let flag3 = FeatureFlag(
            id: "test.b", name: "B", description: "Desc")

        #expect(flag1 == flag2)
        #expect(flag1 != flag3)
    }

    @Test func identifiableConformance() {
        let flag = FeatureFlag(
            id: "test.identifiable", name: "ID", description: "Desc")
        #expect(flag.id == "test.identifiable")
    }

    @Test func customCategory() {
        let flag = FeatureFlag(
            id: "test.cat", name: "Cat", description: "Desc", category: "Custom")
        #expect(flag.category == "Custom")
    }

    @Test func defaultEnabledTrue() {
        let flag = FeatureFlag(
            id: "test.on", name: "On", description: "Desc", defaultEnabled: true)
        #expect(flag.defaultEnabled == true)
    }
}
