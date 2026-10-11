import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct SharedUniqueDamageRegressionTests {
    @Test func `bloodember shares razor claws with burn attacks and stores the resolved bonus once`() throws {
        let fixtures = UniqueCollectionTests()
        let profile = CombatantTalentCatalog.profile(for: ["panther_bleed_t1_1"])
        var context = try fixtures.battle(["bloodember_pendant"], owner: .companion, extra: profile)

        try fixtures.play(fixtures.attack(.burn), owner: .companion, in: &context)

        #expect(context.roster.enemy.currentHealth == 1989)
        #expect(context.roster.enemy.activeEffects.first { $0.effect.kind == .burn }?.effect.potency == 11)

        var ordinary = try fixtures.battle([], owner: .companion, extra: profile)
        try fixtures.play(fixtures.attack(.burn), owner: .companion, in: &ordinary)
        #expect(ordinary.roster.enemy.currentHealth == 1990)
    }

    @Test(arguments: [false, true])
    func `bloodember shares thermal shock only against frozen targets`(frozen: Bool) throws {
        let fixtures = UniqueCollectionTests()
        let profile = CombatantTalentCatalog.profile(for: ["wizard_freeze_t2_1"])
        var context = try fixtures.battle(["bloodember_pendant"], extra: profile)
        if frozen {
            context.appendEffect(
                .controlMeter(.freeze, 400, 400), to: context.enemy,
                sourceID: context.hero.id, remainingTurns: 0,
            )
        }

        try fixtures.play(fixtures.attack(.bleed, amount: 20), in: &context)

        #expect(context.roster.enemy.currentHealth == (frozen ? 1970 : 1980))
    }

    @Test(arguments: [99, 100])
    func `bloodember shares scorching ash below the sources half health boundary`(health: Int) throws {
        let fixtures = UniqueCollectionTests()
        let profile = CombatantTalentCatalog.profile(for: ["warlock_burn_t1_2"])
        var context = try fixtures.battle(["bloodember_pendant"], extra: profile)
        context.roster.hero.currentHealth = health

        try fixtures.play(fixtures.attack(.bleed, amount: 20), in: &context)

        #expect(context.roster.enemy.currentHealth == (health < 100 ? 1975 : 1980))
    }

    @Test func `oathkeeper shares guarded impact block damage with holy hits`() throws {
        let fixtures = UniqueCollectionTests()
        let profile = CombatantTalentCatalog.profile(for: ["knight_block_t2_2"])
        var context = try fixtures.battle(["oathkeeper"], extra: profile)
        fixtures.block(20, owner: .hero, in: &context)

        try fixtures.play(fixtures.attack(.holy), in: &context)

        #expect(context.roster.enemy.currentHealth == 1985)

        var ordinary = try fixtures.battle([], extra: profile)
        fixtures.block(20, owner: .hero, in: &ordinary)
        try fixtures.play(fixtures.attack(.holy), in: &ordinary)
        #expect(ordinary.roster.enemy.currentHealth == 1990)
    }

    @Test(arguments: [Keyword.holy, .burn, .bleed], [BattleParticipant.hero, .companion])
    func `shared damage includes both keyword percentages and universal bonuses once`(
        keyword: Keyword,
        owner: BattleParticipant,
    ) throws {
        let sharedKeyword: Keyword = switch keyword {
        case .holy: .physical
        case .burn: .bleed
        default: .burn
        }
        let unique = keyword == .holy ? "oathkeeper" : "bloodember_pendant"
        let profile = CombatModifierProfile(
            damageDealtPercents: [keyword: 0.1, sharedKeyword: 0.2],
            companionDamageDealtPercent: 0.3,
        )
        let fixtures = UniqueCollectionTests()
        var context = try fixtures.battle([unique], owner: owner, extra: profile)

        try fixtures.play(fixtures.attack(keyword, amount: 100), owner: owner, in: &context)

        #expect(context.roster.enemy.currentHealth == 1840)

        var ordinary = try fixtures.battle([], owner: owner, extra: profile)
        try fixtures.play(fixtures.attack(keyword, amount: 100), owner: owner, in: &ordinary)
        #expect(ordinary.roster.enemy.currentHealth == 1860)
    }
}
