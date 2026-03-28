import Foundation
import Testing

@testable import DevToolsKitLicensing

@Suite(.serialized)
@MainActor
struct TrialManagerTests {
    private func makeTrial(durationDays: Int = 14) -> TrialManager {
        let prefix = "test.\(UUID().uuidString)"
        return TrialManager(keyPrefix: prefix, configuration: TrialConfiguration(durationDays: durationDays))
    }

    @Test func initialStateIsNotStarted() {
        let trial = makeTrial()
        #expect(trial.state == .notStarted)
        #expect(trial.firstLaunchDate == nil)
        #expect(trial.daysRemaining == 0)
    }

    @Test func startTrialSetsActiveState() {
        let trial = makeTrial()
        trial.startTrialIfNeeded()
        #expect(trial.state == .active)
        #expect(trial.firstLaunchDate != nil)
        #expect(trial.daysRemaining > 0)
    }

    @Test func startTrialIsIdempotent() {
        let trial = makeTrial()
        trial.startTrialIfNeeded()
        let firstDate = trial.firstLaunchDate
        trial.startTrialIfNeeded()
        #expect(trial.firstLaunchDate == firstDate)
    }

    @Test func daysRemainingCalculation() {
        let trial = makeTrial(durationDays: 7)
        trial.startTrialIfNeeded()
        // Just started: should have ~7 days remaining
        #expect(trial.daysRemaining >= 6)
        #expect(trial.daysRemaining <= 7)
    }

    @Test func trialExpiresAfterDuration() {
        let trial = makeTrial(durationDays: 0)
        trial.startTrialIfNeeded()
        trial.refresh()
        #expect(trial.state == .expired)
        #expect(trial.daysRemaining == 0)
    }

    @Test func resetTrialClearsState() {
        let trial = makeTrial()
        trial.startTrialIfNeeded()
        #expect(trial.state == .active)
        trial.resetTrial()
        #expect(trial.state == .notStarted)
        #expect(trial.firstLaunchDate == nil)
    }

    @Test func isFirstLaunch() {
        let trial = makeTrial()
        #expect(trial.isFirstLaunch == true)
        trial.startTrialIfNeeded()
        #expect(trial.isFirstLaunch == false)
    }

    @Test func hasSeenWelcomePersists() {
        let trial = makeTrial()
        #expect(trial.hasSeenWelcome == false)
        trial.hasSeenWelcome = true
        #expect(trial.hasSeenWelcome == true)
    }

    @Test func wasEverLicensedSurvivesReset() {
        let trial = makeTrial()
        trial.wasEverLicensed = true
        trial.resetTrial()
        #expect(trial.wasEverLicensed == true)
    }

    @Test func skipWelcomeIfNeeded() {
        let trial = makeTrial()
        #expect(trial.isFirstLaunch == true)
        trial.skipWelcomeIfNeeded()
        #expect(trial.hasSeenWelcome == true)
        #expect(trial.state == .active)
        #expect(trial.isFirstLaunch == false)
    }
}
