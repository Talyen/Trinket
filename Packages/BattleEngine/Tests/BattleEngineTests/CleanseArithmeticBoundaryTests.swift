import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct CleanseArithmeticBoundaryTests {
    @Test(arguments: [Int.max, Int.max / 2])
    func `cleanse saturates healing and per-status rewards without interrupting removal`(healPerDebuff: Int) {
        var profile = CombatModifierProfile(maximumManaBonus: Int.max)
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.cleanseSelfBlockFlat = Int.max
        profile.triggers.cleanseBlockPerStack = Int.max
        profile.triggers.onCleanseRestoreMana = Int.max
        profile.triggers.onCleansePoisonDealDamagePerStack = Int.max
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20, maxMana: 4),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 20),
            companionEffects: [
                ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .poison(1), remainingTurns: 0),
            ],
            companionHealth: 1,
            heroMana: 0,
            heroModifiers: profile, appliesFightPacing: false,
        )
        let hero = battle.hero
        let companion = battle.companion

        let outcome = battle.recordingResult { battle in await EffectRemovalOperation.resolveCleanse(
            .all(nil), source: hero, target: companion, abilityName: "Boundary Cleanse",
            baseHeal: 2, healPerDebuff: healPerDebuff, in: &battle,
        ) }

        #expect(outcome.value.removed.count == 2)
        #expect(!battle.activeEffects(of: companion).contains { $0.effect.isRemovableDebuff })
        #expect(battle.health(of: companion) == 20)
        #expect(battle.mana(of: hero) == Int.max)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: hero)) == Int.max)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: companion)) == Int.max)
        #expect(battle.isEnemyDefeated)
    }
}
