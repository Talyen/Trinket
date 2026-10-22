import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HealingReactionBoundaryTests {
    @Test func `maximum Health overflow cannot revive a healer defeated by Blood Link retaliation`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 19,
            heroModifiers: .withTriggers {
                $0.leechOverhealTransfersToCompanion = true
                $0.overhealConvertsToMaxHealth = true
                $0.onHealDealHoly = 1
                $0.criticalChanceBonus = -1
            },
            enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 21 }, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        var request = HealRequest(amount: 4, target: battle.hero, sourceActorID: battle.hero.id, origin: .leech)
        request.amountBasis = .resolved

        let result = CombatExecutor.run { await HealingEngine.resolveHealing(request, in: &battle) }

        #expect(battle.health(of: battle.companion) == 20)
        #expect(battle.health(of: battle.hero) == 0)
        #expect(battle.maxHealth(of: battle.hero) == 20)
        #expect(result.allocation.transferred == 1)
        #expect(result.allocation.maximumHealth == 0)
        #expect(result.allocation.remaining == 3)
    }

    @Test func `Cooling Salve stops when Mana restoration retaliation defeats its healer`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20, maxMana: 5),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10, companionHealth: 4, companionMana: 0,
            companionModifiers: .withTriggers {
                $0.healthRestoreManaChancePercent = 1
                $0.onGainManaHealFlat = 1
                $0.onHealDealHoly = 1
                $0.coolingSalve = true
                $0.criticalChanceBonus = -1
            },
            enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 3 }, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        battle.insertEffect(.burn(2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)

        _ = battle.resolveHeal(HealRequest(amount: 1, target: battle.hero, sourceActorID: battle.companion.id))

        #expect(battle.health(of: battle.hero) == 11)
        #expect(battle.health(of: battle.companion) == 0)
        #expect(battle.mana(of: battle.companion) == 1)
        #expect(battle.roster.hasAffliction(.burn, on: battle.hero))
    }

    @Test func `recipient Aether Shield has one allowance regardless of who heals it`() {
        let profile = CombatModifierProfile.withTriggers { $0.overhealFirstBlockPerTurn = 3 }
        var battle = BattleStateTestFactory.makeMinimalBattle(
            heroModifiers: profile, companionModifiers: profile, appliesFightPacing: false,
        )
        for (source, target) in [(battle.hero, battle.hero), (battle.companion, battle.hero), (battle.hero, battle.companion)] {
            var request = HealRequest(amount: 1, target: target, sourceActorID: source.id)
            request.amountBasis = .resolved
            _ = battle.resolveHeal(request)
        }

        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 3)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 3)
    }
}
