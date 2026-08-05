import Foundation
import Testing
import TrinketBattleFeature
import TrinketFeatureSupport
@testable import TrinketAppState

@MainActor
struct OptionsUltimateSkipPolicyTests {
    @Test func oncePerBattleAutoSkipsAfterActorPresented() throws {
        let defaults = try #require(UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.\(UUID().uuidString)"))
        let options = OptionsStore(defaults: defaults)
        options.ultimateCinematicShowPolicy = .oncePerBattle

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

    @Test(arguments: [
        (UltimateCinematicShowPolicy.always, false),
        (.never, true),
    ])
    func alwaysAndNeverPoliciesControlAutoSkip(
        policy: UltimateCinematicShowPolicy,
        autoSkips: Bool
    ) throws {
        let defaults = try #require(
            UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.\(policy.rawValue).\(UUID().uuidString)")
        )
        let options = OptionsStore(defaults: defaults)
        options.ultimateCinematicShowPolicy = policy
        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "hero",
                actorsWhoPresentedThisBattle: []
            ) == autoSkips
        )
        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "hero",
                actorsWhoPresentedThisBattle: ["hero"]
            ) == autoSkips
        )
    }
}
