import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct SharedPreparedDamageRegressionTests {
    @Test(arguments: [false, true])
    func `bloodember spends Ashen Vitality on Bleed only when sharing is equipped`(shared: Bool) throws {
        let fixtures = UniqueCollectionTests()
        let profile = CombatantTalentCatalog.profile(for: ["phoenix_health_t3_2"])
        var battle = try fixtures.battle(shared ? ["bloodember_pendant"] : [], owner: .companion, extra: profile)
        _ = CombatExecutor.run { await battle.healEmitting(
            amount: 1, target: battle.companion, source: battle.companion, abilityName: "Heal",
        ) }
        #expect(battle.roster.companion.talents.pending.nextBurnDamageBonus?.value == 2)

        try fixtures.play(fixtures.attack(.bleed, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == (shared ? 1978 : 1980))
        #expect((battle.roster.companion.talents.pending.nextBurnDamageBonus == nil) == shared)
        try fixtures.play(fixtures.attack(.burn, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == 1958)
    }

    @Test(arguments: [false, true])
    func `bloodember spends Redline on Burn only when sharing is equipped`(shared: Bool) throws {
        let fixtures = UniqueCollectionTests()
        let profile = CombatantTalentCatalog.profile(for: ["panther_bleed_t4_2"])
        var battle = try fixtures.battle(shared ? ["bloodember_pendant"] : [], owner: .companion, extra: profile)
        _ = fixtures.enemyHit(110, target: .companion, in: &battle)
        #expect(battle.roster.companion.talents.pending.doubleNextBleedAttack != nil)

        try fixtures.play(fixtures.attack(.burn, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == (shared ? 1960 : 1980))
        #expect((battle.roster.companion.talents.pending.doubleNextBleedAttack == nil) == shared)
        try fixtures.play(fixtures.attack(.bleed, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == 1940)
    }

    @Test(arguments: [false, true])
    func `oathkeeper spends Feigned Miss on Holy only when sharing is equipped`(shared: Bool) throws {
        let fixtures = UniqueCollectionTests()
        let profile = CombatantTalentCatalog.profile(for: ["wildcard_physical_t3_2"])
        var battle = try fixtures.battle(shared ? ["oathkeeper"] : [], extra: profile)
        fixtures.block(20, owner: .enemy, in: &battle)
        try fixtures.play(fixtures.attack(.physical, amount: 20), in: &battle)
        #expect(battle.health(of: battle.enemy) == 2000)
        #expect(battle.roster.hero.talents.pending.doubleNextPhysicalAttack != nil)

        try fixtures.play(fixtures.attack(.holy, amount: 20), in: &battle)
        #expect(battle.health(of: battle.enemy) == (shared ? 1960 : 1980))
        #expect((battle.roster.hero.talents.pending.doubleNextPhysicalAttack == nil) == shared)
        try fixtures.play(fixtures.attack(.physical, amount: 20), in: &battle)
        #expect(battle.health(of: battle.enemy) == 1940)
    }

    @Test(arguments: ["wolf_dodge_t1_2", "wolf_dodge_t4_1"], [false, true])
    func `shared attacks spend Nimble Fang and Phantom Counter once`(talentID: String, shared: Bool) throws {
        let fixtures = UniqueCollectionTests()
        let nimble = talentID == "wolf_dodge_t1_2"
        let item = nimble ? "bloodember_pendant" : "oathkeeper"
        let sharedKeyword: Keyword = nimble ? .burn : .holy
        let originalKeyword: Keyword = nimble ? .bleed : .physical
        let profile = CombatantTalentCatalog.profile(for: [talentID])
        var battle = try fixtures.battle(shared ? [item] : [], owner: .companion, extra: profile)
        battle.appendEffect(.evadeNextHit, to: battle.companion, sourceID: battle.companion.id, remainingTurns: 0)
        let avoided = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.companion, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(tier: .basic, abilityCriticalChanceBonus: -1),
        ))
        #expect(avoided.flags.contains(.dodged))
        let prepared = nimble ? battle.roster.companion.talents.pending.nextBleedAttackMultiplier?.value
            : battle.roster.companion.talents.pending.nextPhysicalAttackMultiplier?.value
        #expect(prepared == (nimble ? 1.25 : 1.5))

        try fixtures.play(fixtures.attack(sharedKeyword, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == (shared ? (nimble ? 1975 : 1970) : 1980))
        try fixtures.play(fixtures.attack(originalKeyword, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == (nimble ? 1955 : 1950))
        #expect(battle.roster.companion.talents.pending.nextBleedAttackMultiplier == nil)
        #expect(battle.roster.companion.talents.pending.nextPhysicalAttackMultiplier == nil)
    }
}
