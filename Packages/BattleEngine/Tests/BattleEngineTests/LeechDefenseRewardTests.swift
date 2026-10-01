import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct LeechDefenseRewardTests {
    @Test func `Armor Pierce recognizes Emberdrinker Leech before Block absorption`() {
        var profile = CombatantTalentCatalog.profile(for: ["warlock_leech_t1_2", "warlock_leech_t4_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleTestFixtures.makePipelineContext(
            targetEffects: [ActiveEffect(id: 1, effect: .shield(.block, 8), remainingTurns: 0)],
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        let result = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: .burn, sourceActorID: battle.hero.id,
            options: .attack(accuracy: .unavoidable),
        ))
        #expect(result.healthLost == 4)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 4)
    }

    @Test func `Vitality Infusion recognizes Scarfeast even when healing is prevented`() {
        var profile = CombatantTalentCatalog.profile(for: ["panther_leech_t2_1"])
        profile.triggers.physicalAttackLeechBelowHalfHealth = true
        var battle = BattleTestFixtures.makePipelineContext(companionModifiers: profile)
        battle.appliesFightPacing = false
        battle.roster.companion.currentHealth = 5
        battle.appendEffect(.healingReductionPercent(1, 2), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 2)
        let result = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.enemy, keyword: .physical, sourceActorID: battle.companion.id,
            options: .attack(accuracy: .unavoidable, guaranteedCritical: true),
        ))
        #expect(result.healthLost == 8)
        #expect(battle.health(of: battle.companion) == 5)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 3)
    }

    @Test func `Vitality Infusion does not reward a fully blocked Leech Critical Hit`() {
        var battle = BattleTestFixtures.makePipelineContext(
            targetEffects: [ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTurns: 0)],
            companionModifiers: CombatantTalentCatalog.profile(for: ["panther_leech_t2_1"]),
        )
        battle.appliesFightPacing = false
        let result = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.enemy, keyword: .physical, sourceActorID: battle.companion.id,
            options: .attack(accuracy: .unavoidable, guaranteedCritical: true, abilityHasLeech: true),
        ))
        #expect(result.healthLost == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 0)
    }
}
