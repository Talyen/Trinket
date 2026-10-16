import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct PaidInFullPreparationTests {
    @Test func `Paid in Full cannot strengthen the later hit that triggered its theft`() throws {
        let fixtures = UniqueCollectionTests()
        var profile = CombatantTalentCatalog.profile(for: ["wildcard_physical_t4_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = try fixtures.battle(["saintfall_plate", "golden_verdict"], extra: profile)
        let threshold = ControlMeterEngine.threshold(for: battle.enemy, in: battle)
        battle.insertEffect(
            .controlMeter(.stun, threshold - 6, threshold), to: battle.enemy,
            sourceID: battle.hero.id, remainingTurns: 0,
        )
        battle.insertEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        fixtures.block(1, owner: .hero, in: &battle)

        // Consolation Prize can grant Wildcard Ray of Frost. Its first hit breaks
        // the caster's Block on Thorns; Saintfall's Holy response steals via Golden Verdict.
        let events = try fixtures.play(.rayOfFrost, in: &battle)
        let hits = events.filter { $0.kind == .abilityDamage && $0.abilityID == Ability.rayOfFrost.id }
        #expect(hits.map(\.amount) == [1, 1])
        #expect(battle.gold == 1)
        #expect(battle.roster.hero.talents.pending.nextAttackDamageBonus?.value == 2)

        let next = try fixtures.play(.slash, in: &battle)
        #expect(next.first { $0.kind == .abilityDamage && $0.abilityID == Ability.slash.id }?.amount == 5)
        #expect(battle.roster.hero.talents.pending.nextAttackDamageBonus == nil)
    }
}
