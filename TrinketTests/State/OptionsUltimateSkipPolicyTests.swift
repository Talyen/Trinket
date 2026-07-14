import Foundation
import Testing
@testable import Trinket

@MainActor
struct OptionsUltimateSkipPolicyTests {
    @Test func oncePerBattleAutoSkipsAfterActorPresented() throws {
        let defaults = try #require(UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.\(UUID().uuidString)"))
        let options = OptionsStore(defaults: defaults)
        options.ultimateCinematicSkipPolicy = .oncePerBattle

        #expect(options.canSkipUltimateCinematic())
        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "hero",
                actorsWhoPresentedThisBattle: []
            ) == false
        )
        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "hero",
                actorsWhoPresentedThisBattle: ["hero"]
            )
        )
        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "companion",
                actorsWhoPresentedThisBattle: ["hero"]
            ) == false
        )
    }

    @Test func migratesLegacyAfterFirstViewToOncePerBattle() throws {
        let defaults = try #require(UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.legacy.\(UUID().uuidString)"))
        defaults.set(UltimateCinematicSkipPolicy.afterFirstView.rawValue, forKey: OptionsStore.ultimateCinematicSkipPolicyKey)
        let options = OptionsStore(defaults: defaults)
        #expect(options.ultimateCinematicSkipPolicy == .oncePerBattle)
    }

    @Test(arguments: [
        (UltimateCinematicSkipPolicy.never, false),
        (.always, true)
    ])
    func neverAndAlwaysPoliciesControlManualSkipWithoutAutoSkip(
        policy: UltimateCinematicSkipPolicy,
        canSkip: Bool
    ) throws {
        let defaults = try #require(
            UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.\(policy.rawValue).\(UUID().uuidString)")
        )
        let options = OptionsStore(defaults: defaults)
        options.ultimateCinematicSkipPolicy = policy
        #expect(options.canSkipUltimateCinematic() == canSkip)
        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "hero",
                actorsWhoPresentedThisBattle: ["hero"]
            ) == false
        )
    }
}
