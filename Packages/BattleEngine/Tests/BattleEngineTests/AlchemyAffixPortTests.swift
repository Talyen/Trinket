import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct AlchemyAffixPortTests {
    private func makeAffixBattle(
        heroHealth: Int? = nil,
        heroEffects: [ActiveEffect] = [],
        enemyEffects: [ActiveEffect] = [],
        modifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroEffects: heroEffects,
            enemyEffects: enemyEffects,
            heroHealth: heroHealth,
            heroModifiers: modifiers, appliesFightPacing: false,
        )
    }

    @Test(arguments: [false, true])
    func `Spitebloom strengthens the existing Thorns hit against Poisoned enemies`(poisoned: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.thornsDamageVsPoisonedFlat = 2
        var battle = makeAffixBattle(
            heroEffects: [ActiveEffect(id: 1, effect: .thorns(3), remainingTurns: 0)],
            modifiers: profile,
        )
        if poisoned {
            battle.insertEffect(.poison(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }
        let outcome = battle.resolveTestDamage(2, from: .enemy, to: .hero, options: .attack(
            tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
        ))
        #expect(battle.health(of: battle.enemy) == (poisoned ? 35 : 37))
        #expect(outcome.events.filter { $0.effectKind == .thornsTriggered }.map(\.amount) == [poisoned ? 5 : 3])
        #expect(!outcome.events.contains { $0.kind == .abilityDamage && $0.keyword == .poison })
    }

    @Test func `Bloodroot needs actual Leech restoration and no existing Thorns`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.leechThornsWithoutThorns = 2
        var battle = makeAffixBattle(heroHealth: 10, modifiers: profile)

        _ = CombatExecutor.run { await HealingEngine.leechFromDamage(8, sourceActorID: battle.hero.id, abilityHasLeech: true, in: &battle) }
        #expect(thorns(on: battle.hero, in: battle) == 2)
        _ = CombatExecutor.run { await HealingEngine.leechFromDamage(8, sourceActorID: battle.hero.id, abilityHasLeech: true, in: &battle) }
        #expect(thorns(on: battle.hero, in: battle) == 2)

        var full = makeAffixBattle(modifiers: profile)
        _ = CombatExecutor.run { await HealingEngine.leechFromDamage(8, sourceActorID: full.hero.id, abilityHasLeech: true, in: &full) }
        #expect(thorns(on: full.hero, in: full) == 0)
    }

    @Test func `Scarfeast grants Leech only to Physical attacks below half Health`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.physicalAttackLeechBelowHalfHealth = true
        func strike(at health: Int, keyword: Keyword) -> Int {
            var battle = makeAffixBattle(heroHealth: health, modifiers: profile)
            _ = battle.resolveTestDamage(8, keyword: keyword, options: .attack(tier: .basic, scaling: .flat, accuracy: .unavoidable))
            return battle.health(of: battle.hero)
        }
        #expect(strike(at: 10, keyword: .physical) > 10)
        #expect(strike(at: 20, keyword: .physical) == 20)
        #expect(strike(at: 10, keyword: .holy) == 10)
    }

    @Test func `Heartshock follows actual low-Health Leech without Leeching its own Stun hit`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.leechStunBelowHalfHealth = 2
        profile.triggers.leechChancePercent = 1
        var battle = makeAffixBattle(heroHealth: 10, modifiers: profile)

        _ = CombatExecutor.run { await HealingEngine.leechFromDamage(
            8, sourceActorID: battle.hero.id, target: battle.enemy,
            abilityHasLeech: true, in: &battle,
        ) }
        #expect(battle.health(of: battle.hero) == 14)
        #expect(battle.health(of: battle.enemy) == 38)

        var healthy = makeAffixBattle(heroHealth: 20, modifiers: profile)
        _ = CombatExecutor.run { await HealingEngine.leechFromDamage(
            8, sourceActorID: healthy.hero.id, target: healthy.enemy,
            abilityHasLeech: true, in: &healthy,
        ) }
        #expect(healthy.health(of: healthy.enemy) == 40)
    }

    @Test func `Venomtrail adds flat Poison damage while Bleed is active, including periodic ticks`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.poisonDamageVsBleedingFlat = 2
        func damage(bleeding: Bool, operation: DamageOperation) -> Int {
            var battle = makeAffixBattle(
                enemyEffects: bleeding ? [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)] : [],
                modifiers: profile,
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
        var profile = CombatModifierProfile.zero
        profile.triggers.holyAttackBlockIfNone = 3
        func block(startingWith initialBlock: Int, operation: DamageOperation) -> Int {
            let effects = initialBlock > 0
                ? [ActiveEffect(id: 1, effect: .shield(.block, initialBlock), remainingTurns: 2)] : []
            var battle = makeAffixBattle(heroEffects: effects, modifiers: profile)
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
        var profile = CombatModifierProfile.zero
        profile.triggers.holyDamageVsStunnedPercent = 0.25
        func holyDamage(stunned: Bool) -> Int {
            var battle = makeAffixBattle(modifiers: profile)
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

    private func thorns(on combatant: Combatant, in battle: BattleState) -> Int {
        battle.roster.activeEffects(for: combatant).reduce(0) { total, active in
            if case let .thorns(amount) = active.effect {
                return total + amount
            }
            return total
        }
    }
}
