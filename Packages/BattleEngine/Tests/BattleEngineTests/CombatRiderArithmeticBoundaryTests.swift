import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CombatRiderArithmeticBoundaryTests {
    @Test func `converted Thorns combines typed flat defenses without overflowing`() {
        let profile = CombatModifierProfile(damageTakenFlat: [.physical: Int.max, .thorns: 1])
        var battle = BattleStateTestFactory.makeMinimalBattle(heroModifiers: profile, appliesFightPacing: false)
        var operation = DamageOperation.reaction()
        operation.isThornsDamage = true

        let outcome = battle.resolveTestDamage(10, from: .enemy, to: .hero, options: operation)

        #expect(outcome.healthLost == 0)
        #expect(battle.health(of: battle.hero) == battle.roster.hero.maxHealth)
    }

    @Test func `living party Basic Attack Holy riders saturate before resolving damage`() {
        var heroProfile = CombatModifierProfile.zero
        heroProfile.triggers.partyBasicAttackHolyBonus = Int.max
        heroProfile.triggers.criticalChanceBonus = -1
        var companionProfile = CombatModifierProfile.zero
        companionProfile.triggers.partyBasicAttackHolyBonus = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 20),
            heroModifiers: heroProfile, companionModifiers: companionProfile, appliesFightPacing: false,
        )

        let outcome = battle.resolveTestDamage(1, options: .attack(tier: .basic, accuracy: .unavoidable))

        #expect(battle.isEnemyDefeated)
        #expect(outcome.healthLost == 1)
    }

    @Test func `Pickpocket combines Poison theft bonuses without overflowing`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.onAttackStealGold = Int.max
        profile.triggers.stealGoldBonusVsPoisoned = 1
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemyEffects: [ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 0)],
            heroModifiers: profile, appliesFightPacing: false,
        )

        _ = battle.resolveTestDamage(1, options: .attack(accuracy: .unavoidable))

        #expect(battle.gold == Int.max)
    }

    @Test func `living party Bleed attack reactions saturate before enemy damage`() {
        var heroProfile = CombatModifierProfile.zero
        heroProfile.triggers.bleedingEnemyAttackDealDamage = Int.max
        heroProfile.triggers.criticalChanceBonus = -1
        var companionProfile = CombatModifierProfile.zero
        companionProfile.triggers.bleedingEnemyAttackDealDamage = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 20),
            enemyEffects: [ActiveEffect(id: 1, effect: .bleed(1), remainingTurns: 2)],
            heroModifiers: heroProfile, companionModifiers: companionProfile, appliesFightPacing: false,
        )

        _ = CombatExecutor.run { await CombatTriggerEngine.beforeEnemyAttackBleedReactions(in: &battle) }

        #expect(battle.isEnemyDefeated)
    }

    @Test func `party Bleed avoidance still sums fractional chances`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.bleedingEnemyActionSkipChancePercent = 0.5
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemyEffects: [ActiveEffect(id: 1, effect: .bleed(1), remainingTurns: 2)],
            heroModifiers: profile, companionModifiers: profile, appliesFightPacing: false,
        )

        let outcome = CombatTriggerEngine.beforeEnemyActBleedReactions(in: &battle)

        #expect(outcome.cancelled)
        #expect(outcome.events.contains { $0.effectKind == .controlActionSkipped })
    }

    @Test func `secondary Cleanse preserves Dodge through a saturated expiry turn`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.cleanseDodgeChanceBonus = 0.25
        profile.triggers.cleanseDodgeChanceBonusTurns = Int.max
        var battle = BattleStateTestFactory.makeMinimalBattle(
            companionEffects: [ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 0)],
            heroModifiers: profile, appliesFightPacing: false,
        )
        battle.turnCount = 2
        let source = battle.hero
        let target = battle.companion

        let outcome = CombatExecutor.run { await EffectRemovalOperation.resolveCleanse(
            .all(nil), source: source, target: target, abilityName: "Cleanse", propagation: .secondary, in: &battle,
        ) }

        #expect(outcome.removed.count == 1)
        #expect(!battle.roster.hasAffliction(.poison, on: target))
        #expect(battle.roster.companion.talents.dodgeChanceBonus(atTurn: Int.max - 1) == 0.25)
        #expect(battle.roster.companion.talents.dodgeChanceBonus(atTurn: Int.max) == 0)
    }
}
