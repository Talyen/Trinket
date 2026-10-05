import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CompanionHitRewardSurvivalTests {
    @Test(arguments: [false, true], [false, true])
    func `Sun Glyph and Vitality Infusion require surviving their hit's retaliation`(holy: Bool, survives: Bool) {
        let talent = holy ? "shield_scarab_holy_t2_1" : "panther_leech_t2_1"
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: survives ? 5 : 1,
            companionModifiers: CombatantTalentCatalog.profile(for: [talent]),
        )
        battle.appliesFightPacing = false
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.appendEffect(.thorns(4), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        // Vitality Infusion qualifies through guaranteed Leech even when Sapped prevents restoration.
        battle.appendEffect(.healingReductionPercent(1, 2), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 2)

        let result = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.enemy, keyword: holy ? .holy : .physical,
            sourceActorID: battle.companion.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, guaranteedCritical: true, abilityHasLeech: !holy),
        ))

        #expect(result.healthLost == 4)
        #expect(battle.health(of: battle.companion) == (survives ? 1 : 0))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == (survives ? (holy ? 2 : 3) : 0))
        let reward = holy ? "Sun Glyph" : "Vitality Infusion"
        #expect(result.events.contains { $0.abilityName == reward } == survives)
    }
}
