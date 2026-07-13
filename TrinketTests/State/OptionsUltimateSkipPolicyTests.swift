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

    @Test func neverPolicyBlocksSkip() throws {
        let defaults = try #require(UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.never.\(UUID().uuidString)"))
        let options = OptionsStore(defaults: defaults)
        options.ultimateCinematicSkipPolicy = .never
        #expect(options.canSkipUltimateCinematic() == false)
        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "hero",
                actorsWhoPresentedThisBattle: ["hero"]
            ) == false
        )
    }

    @Test func alwaysPolicyAllowsSkipAndNeverAutoSkips() throws {
        let defaults = try #require(UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.always.\(UUID().uuidString)"))
        let options = OptionsStore(defaults: defaults)
        options.ultimateCinematicSkipPolicy = .always
        #expect(options.canSkipUltimateCinematic())
        #expect(
            options.shouldAutoSkipUltimateCinematic(
                actorID: "hero",
                actorsWhoPresentedThisBattle: ["hero"]
            ) == false
        )
    }
}
