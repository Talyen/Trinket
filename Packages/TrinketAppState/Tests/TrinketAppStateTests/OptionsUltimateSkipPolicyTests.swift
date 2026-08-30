import Foundation
import Testing
import TrinketBattleFeature
import TrinketFeatureSupport
@testable import TrinketAppState

@MainActor
struct OptionsUltimateSkipPolicyTests {
    @Test func `default show policy is once per battle`() throws {
        let defaults = try #require(UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.\(UUID().uuidString)"))
        let options = OptionsStore(defaults: defaults)
        #expect(options.ultimateCinematicShowPolicy == .oncePerBattle)
    }

    @Test func `once per battle auto skips after actor presented`() throws {
        let defaults = try #require(UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.\(UUID().uuidString)"))
        let options = OptionsStore(defaults: defaults)
        options.ultimateCinematicShowPolicy = .oncePerBattle

        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "hero",
                actorsWhoPresentedThisBattle: [],
            ) == false,
        )
        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "hero",
                actorsWhoPresentedThisBattle: ["hero"],
            ),
        )
        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "companion",
                actorsWhoPresentedThisBattle: ["hero"],
            ) == false,
        )
    }

    @Test(arguments: [
        (UltimateCinematicShowPolicy.always, false),
        (.never, true),
    ])
    func `always and never policies control auto skip`(
        policy: UltimateCinematicShowPolicy,
        autoSkips: Bool,
    ) throws {
        let defaults = try #require(
            UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.\(policy.rawValue).\(UUID().uuidString)"),
        )
        let options = OptionsStore(defaults: defaults)
        options.ultimateCinematicShowPolicy = policy
        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "hero",
                actorsWhoPresentedThisBattle: [],
            ) == autoSkips,
        )
        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "hero",
                actorsWhoPresentedThisBattle: ["hero"],
            ) == autoSkips,
        )
    }
}
