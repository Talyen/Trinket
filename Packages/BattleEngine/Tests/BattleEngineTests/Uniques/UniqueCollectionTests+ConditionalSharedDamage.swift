import Testing
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

extension UniqueCollectionTests {
    @Test(arguments: [
        ("cinderbound", Keyword.bleed, Effect.bleed(1)),
        ("ashen_wake", Keyword.bleed, Effect.poison(1)),
        ("cauterize", Keyword.burn, Effect.burn(1)),
        ("infected", Keyword.burn, Effect.poison(1)),
    ])
    func `bloodember shares conditional numeric affix bonuses`(affixID: String, keyword: Keyword, status: Effect) throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: affixID))
        let power = definition.power(for: .basic)
        var profile = CombatModifierProfile(modifiers: power.modifiers)
        power.triggers.apply(to: &profile)
        for shared in [false, true] {
            var context = try battle(shared ? ["bloodember_pendant"] : [], extra: profile)
            context.insertEffect(status, to: context.enemy, sourceID: context.hero.id, remainingTurns: 3)
            try play(attack(keyword, amount: 20), in: &context)
            #expect(context.health(of: context.enemy) == (shared ? 1979 : 1980))
        }
    }

    @Test(arguments: [Keyword.burn, .bleed])
    func `bloodember adds each native and shared conditional bonus once`(keyword: Keyword) throws {
        let profile = CombatModifierProfile.withTriggers {
            $0.burnDamageVsPoisonedFlat = 2
            $0.bleedDamageVsPoisonedFlat = 3
        }
        var context = try battle(["bloodember_pendant"], extra: profile)
        context.insertEffect(.poison(1), to: context.enemy, sourceID: context.hero.id, remainingTurns: 0)
        try play(attack(keyword, amount: 20), in: &context)
        #expect(context.health(of: context.enemy) == 1975)
    }

    @Test(arguments: [false, true])
    func `bloodember shares Bloodfire with Bleed attacks`(shared: Bool) throws {
        var context = try battle(
            shared ? ["bloodember_pendant"] : [],
            extra: CombatantTalentCatalog.profile(for: ["warlock_burn_t1_1"]),
        )
        context.insertEffect(.bleed(1), to: context.enemy, sourceID: context.hero.id, remainingTurns: 3)
        try play(attack(.bleed, amount: 20), in: &context)
        #expect(context.health(of: context.enemy) == (shared ? 1975 : 1980))
    }

    @Test(arguments: [false, true])
    func `oathkeeper shares saved physical conditional damage with Holy attacks`(shared: Bool) throws {
        var context = try battle(
            shared ? ["oathkeeper"] : [],
            extra: .withTriggers { $0.physicalAttackDamageVsBurningOrFrozenFlat = 3 },
        )
        context.insertEffect(.burn(1), to: context.enemy, sourceID: context.hero.id, remainingTurns: 0)
        try play(attack(.holy, amount: 20), in: &context)
        #expect(context.health(of: context.enemy) == (shared ? 1977 : 1980))
    }
}
