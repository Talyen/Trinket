import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct AlchemyAffixPortTests {
    @Test(arguments: [false, true])
    func `Spitebloom strengthens the existing Thorns hit against Poisoned enemies`(poisoned: Bool) {
        var battle = BattleTestFixtures.makeAffixBattle(
            heroEffects: [ActiveEffect(id: 1, effect: .thorns(3), remainingTurns: 0)],
            modifiers: .withTriggers { $0.thornsDamageVsPoisonedFlat = 2 },
        )
        if poisoned {
            battle.insertEffect(.poison(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }
        let outcome = battle.recordingResult { context in context.resolveTestDamage(2, from: .enemy, to: .hero, options: .attack(
            tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
        )) }
        #expect(battle.health(of: battle.enemy) == (poisoned ? 35 : 37))
        #expect(outcome.events.filter { $0.effectKind == .thornsTriggered }.map(\.amount) == [poisoned ? 5 : 3])
        #expect(!outcome.events.contains { $0.kind == .abilityDamage && $0.keyword == .poison })
    }

    @Test func `Bloodroot needs actual Leech restoration and no existing Thorns`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.leechThornsWithoutThorns = 2
        var battle = BattleTestFixtures.makeAffixBattle(heroHealth: 10, modifiers: profile)

        _ = CombatExecutor.run { await HealingEngine.leechFromDamage(8, sourceActorID: battle.hero.id, abilityHasLeech: true, in: &battle) }
        #expect(BattleTestFixtures.thorns(on: battle.hero, in: battle) == 2)
        _ = CombatExecutor.run { await HealingEngine.leechFromDamage(8, sourceActorID: battle.hero.id, abilityHasLeech: true, in: &battle) }
        #expect(BattleTestFixtures.thorns(on: battle.hero, in: battle) == 2)

        var full = BattleTestFixtures.makeAffixBattle(modifiers: profile)
        _ = CombatExecutor.run { await HealingEngine.leechFromDamage(8, sourceActorID: full.hero.id, abilityHasLeech: true, in: &full) }
        #expect(BattleTestFixtures.thorns(on: full.hero, in: full) == 0)
    }

    @Test func `Scarfeast grants Leech only to Physical attacks below half Health`() {
        func strike(at health: Int, keyword: Keyword) -> Int {
            var battle = BattleTestFixtures.makeAffixBattle(
                heroHealth: health,
                modifiers: .withTriggers { $0.physicalAttackLeechBelowHalfHealth = true },
            )
            _ = battle.resolveTestDamage(8, keyword: keyword, options: .attack(tier: .basic, scaling: .flat, accuracy: .unavoidable))
            return battle.health(of: battle.hero)
        }
        #expect(strike(at: 10, keyword: .physical) > 10)
        #expect(strike(at: 20, keyword: .physical) == 20)
        #expect(strike(at: 10, keyword: .holy) == 10)
    }

    @Test(arguments: [false, true], [false, true])
    func `Heartshock increases the existing Leech heal only below half Health against Stunned enemies`(belowHalf: Bool, stunned: Bool) {
        var battle = BattleTestFixtures.makeAffixBattle(heroHealth: belowHalf ? 10 : 20, modifiers: .withTriggers {
            $0.leechHealVsStunnedBelowHalfFlat = 2
            $0.leechChancePercent = 1
            $0.criticalChanceBonus = -1
        })
        if stunned {
            battle.insertEffect(.controlMeter(.stun, 8, 8), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)
        }
        let outcome = battle.recordingResult { context in await HealingEngine.leechFromDamage(
            8, sourceActorID: context.hero.id, target: context.enemy,
            abilityHasLeech: true, in: &context,
        ) }
        #expect(battle.health(of: battle.hero) == (belowHalf ? 14 + (stunned ? 2 : 0) : 24))
        #expect(battle.health(of: battle.enemy) == 40)
        #expect(!outcome.events.contains { $0.kind == .abilityDamage })
        #expect(outcome.events.filter { $0.effectKind == .leechHeal }.map(\.amount) == [belowHalf && stunned ? 6 : 4])
    }

    @Test func `Venomtrail adds flat Poison damage while Bleed is active, including periodic ticks`() {
        func damage(bleeding: Bool, operation: DamageOperation) -> Int {
            var battle = BattleTestFixtures.makeAffixBattle(
                enemyEffects: bleeding ? [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)] : [],
                modifiers: .withTriggers { $0.poisonDamageVsBleedingFlat = 2 },
            )
            _ = battle.resolveTestDamage(4, keyword: .poison, options: operation)
            return 40 - battle.health(of: battle.enemy)
        }
        let attack = DamageOperation.attack(
            tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
        )
        #expect(damage(bleeding: true, operation: attack) == 6)
        #expect(damage(bleeding: false, operation: attack) == 4)
        #expect(damage(bleeding: true, operation: .resolvedPeriodic) == 6)
    }

    @Test func `Hallowguard grants Block only after an unguarded Holy attack damages Health`() {
        func block(startingWith initialBlock: Int, operation: DamageOperation) -> Int {
            let effects = initialBlock > 0
                ? [ActiveEffect(id: 1, effect: .shield(.block, initialBlock), remainingTurns: 2)] : []
            var battle = BattleTestFixtures.makeAffixBattle(heroEffects: effects, modifiers: .withTriggers { $0.holyAttackBlockIfNone = 3 })
            _ = battle.resolveTestDamage(4, keyword: .holy, options: operation)
            return DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.hero))
        }
        let attack = DamageOperation.attack(
            tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
        )
        #expect(block(startingWith: 0, operation: attack) == 3)
        #expect(block(startingWith: 1, operation: attack) == 1)
        #expect(block(startingWith: 0, operation: .reaction()) == 0)
    }

    @Test func `Hallowbreak increases Holy damage to Stunned enemies`() {
        func holyDamage(stunned: Bool) -> Int {
            var battle = BattleTestFixtures.makeAffixBattle(modifiers: .withTriggers { $0.holyDamageVsStunnedPercent = 0.25 })
            if stunned {
                _ = battle.chargeTestControl(20, keyword: .stun, to: battle.enemy, sourceActorID: battle.hero.id, applyFightPacing: false)
            }
            _ = battle.resolveTestDamage(
                8,
                keyword: .holy,
                options: .attack(tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
            )
            return 40 - battle.health(of: battle.enemy)
        }
        #expect(holyDamage(stunned: false) == 8)
        #expect(holyDamage(stunned: true) == 10)
    }
}
