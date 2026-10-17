import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

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
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 20),
            heroModifiers: .withTriggers {
                $0.partyBasicAttackHolyBonus = Int.max
                $0.criticalChanceBonus = -1
            }, companionModifiers: .withTriggers { $0.partyBasicAttackHolyBonus = 1 }, appliesFightPacing: false,
        )

        let outcome = battle.resolveTestDamage(1, options: .attack(tier: .basic, accuracy: .unavoidable))

        #expect(battle.isEnemyDefeated)
        #expect(outcome.healthLost == 1)
    }

    @Test func `Pickpocket combines Poison theft bonuses without overflowing`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemyEffects: [ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 0)],
            heroModifiers: .withTriggers {
                $0.onAttackStealGold = Int.max
                $0.stealGoldBonusVsPoisoned = 1
                $0.criticalChanceBonus = -1
            }, appliesFightPacing: false,
        )

        _ = battle.resolveTestDamage(1, options: .attack(accuracy: .unavoidable))

        #expect(battle.gold == Int.max)
    }

    @Test func `living party Bleed attack reactions saturate before enemy damage`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 20),
            enemyEffects: [ActiveEffect(id: 1, effect: .bleed(1), remainingTurns: 2)],
            heroModifiers: .withTriggers {
                $0.bleedingEnemyAttackDealDamage = Int.max
                $0.criticalChanceBonus = -1
            }, companionModifiers: .withTriggers { $0.bleedingEnemyAttackDealDamage = 1 }, appliesFightPacing: false,
        )

        CombatExecutor.run { await CombatTriggerEngine.beforeEnemyAttackBleedReactions(in: &battle) }

        #expect(battle.isEnemyDefeated)
    }

    @Test func `party Bleed avoidance still sums fractional chances`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.bleedingEnemyActionSkipChancePercent = 0.5
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemyEffects: [ActiveEffect(id: 1, effect: .bleed(1), remainingTurns: 2)],
            heroModifiers: profile, companionModifiers: profile, appliesFightPacing: false,
        )

        let outcome = battle.recordingResult { battle in
            CombatTriggerEngine.beforeEnemyActBleedReactions(in: &battle)
        }

        #expect(outcome.value)
        #expect(outcome.events.contains { $0.effectKind == .controlActionSkipped })
    }

    @Test func `secondary Cleanse preserves Dodge through a saturated expiry turn`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            companionEffects: [ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 0)],
            heroModifiers: .withTriggers {
                $0.cleanseDodgeChanceBonus = 0.25
                $0.cleanseDodgeChanceBonusTurns = Int.max
            }, appliesFightPacing: false,
        )
        battle.turnCount = 2
        let source = battle.hero
        let target = battle.companion

        let outcome = battle.recordingResult { battle in await EffectRemovalOperation.resolveCleanse(
            .all(nil), source: source, target: target, abilityName: "Cleanse", propagation: .secondary, in: &battle,
        ) }

        #expect(outcome.value.removed.count == 1)
        #expect(!battle.roster.hasAffliction(.poison, on: target))
        #expect(battle.roster.companion.talents.dodgeChanceBonus(atTurn: Int.max - 1) == 0.25)
        #expect(battle.roster.companion.talents.dodgeChanceBonus(atTurn: Int.max) == 0)
    }
}
