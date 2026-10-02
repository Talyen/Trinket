import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HealingGainBoundaryTests {
    @Test(arguments: ["alchemist_health_t1_1", "druid_health_t1_1"], [0.25, 1.0])
    func `Sapped reduces the complete restoration including flat talent bonuses`(talent: String, reduction: Double) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10,
            heroModifiers: CombatantTalentCatalog.profile(for: [talent]),
            companionModifiers: CombatantTalentCatalog.profile(for: ["pixie_health_t1_1"]),
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.thorns(1), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        battle.appendEffect(.healingReductionPercent(reduction, 2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 2)

        let outcome = battle.resolveHeal(HealRequest(amount: 8, target: battle.hero, sourceActorID: battle.companion.id))

        // Eight base Health plus two from Sprite Touch and two from the Hero's talent.
        let restored = reduction == 1 ? 0 : 9
        #expect(outcome.healthRestored == restored)
        #expect(battle.health(of: battle.hero) == 10 + restored)
        if reduction == 1 {
            battle.roster.hero.activeEffects.removeAll { $0.effect.kind == .healingReductionPercent }
            let later = battle.resolveHeal(HealRequest(amount: 1, target: battle.hero, sourceActorID: battle.companion.id))
            #expect(later.healthRestored == 5)
        }
    }

    @Test(arguments: [false, true])
    func `resolved Block preserves its amount and does not spend a prepared gain`(resolved: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(),
            companionHealth: 10,
            companionModifiers: CombatantTalentCatalog.profile(for: ["bear_block_t3_2"]),
        )
        battle.appliesFightPacing = false
        battle.roster.companion.talents.pending.nextBlockGainMultiplier = PreparedTalentBonus(value: 2)

        let gain = battle.applyBlockGain(
            4, to: battle.companion, source: battle.hero, abilityName: "Sunwall",
            amountBasis: resolved ? .resolved : .base,
        )

        #expect(gain.applied == (resolved ? 4 : 12))
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == gain.applied)
        #expect(battle.roster.companion.talents.pending.nextBlockGainMultiplier?.value == (resolved ? 2 : nil))
    }
}
