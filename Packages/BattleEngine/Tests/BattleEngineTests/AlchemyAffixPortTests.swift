import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct AlchemyAffixPortTests {
    @Test func `Spitebloom follows damaging Thorns with Poison`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.poisonOnThornsDamage = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroEffects: [ActiveEffect(id: 1, effect: .thorns(3), remainingTurns: 0)],
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false

        _ = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.hero, keyword: .physical,
            sourceActorID: battle.enemy.id,
            options: .attack(tier: .basic, scaling: .flat, accuracy: .unavoidable),
        ))
        #expect(battle.health(of: battle.enemy) == 35)
        #expect(battle.roster.hasAffliction(.poison, on: battle.enemy))
    }

    @Test func `Bloodroot needs actual Leech restoration and no existing Thorns`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.leechThornsWithoutThorns = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(),
            heroHealth: 10,
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false

        _ = HealingEngine.leechFromDamage(8, sourceActorID: battle.hero.id, abilityHasLeech: true, in: &battle)
        #expect(thorns(on: battle.hero, in: battle) == 2)
        _ = HealingEngine.leechFromDamage(8, sourceActorID: battle.hero.id, abilityHasLeech: true, in: &battle)
        #expect(thorns(on: battle.hero, in: battle) == 2)

        var full = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(),
            heroModifiers: profile,
        )
        _ = HealingEngine.leechFromDamage(8, sourceActorID: full.hero.id, abilityHasLeech: true, in: &full)
        #expect(thorns(on: full.hero, in: full) == 0)
    }

    @Test func `Scarfeast grants Leech only to Physical attacks below half Health`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.physicalAttackLeechBelowHalfHealth = true
        func strike(at health: Int, keyword: Keyword) -> Int {
            var battle = BattleStateTestFactory.makeMinimalBattle(
                hero: CombatantFixtures.passiveHero(maxHealth: 40),
                companion: CombatantFixtures.passiveCompanion(),
                enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
                heroHealth: health,
                heroModifiers: profile,
            )
            battle.appliesFightPacing = false
            _ = battle.resolveDamage(DamageRequest(
                amount: 8, target: battle.enemy, keyword: keyword,
                sourceActorID: battle.hero.id,
                options: .attack(tier: .basic, scaling: .flat, accuracy: .unavoidable),
            ))
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
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroHealth: 10,
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false

        _ = HealingEngine.leechFromDamage(
            8, sourceActorID: battle.hero.id, target: battle.enemy,
            abilityHasLeech: true, in: &battle,
        )
        #expect(battle.health(of: battle.hero) == 14)
        #expect(battle.health(of: battle.enemy) == 38)

        var healthy = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroHealth: 20,
            heroModifiers: profile,
        )
        _ = HealingEngine.leechFromDamage(
            8, sourceActorID: healthy.hero.id, target: healthy.enemy,
            abilityHasLeech: true, in: &healthy,
        )
        #expect(healthy.health(of: healthy.enemy) == 40)
    }

    @Test func `Venomtrail adds flat Poison damage while Bleed is active, including periodic ticks`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.poisonDamageVsBleedingFlat = 2
        func damage(bleeding: Bool, operation: DamageOperation) -> Int {
            var battle = BattleStateTestFactory.makeMinimalBattle(
                hero: CombatantFixtures.passiveHero(maxHealth: 40),
                companion: CombatantFixtures.passiveCompanion(),
                enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
                enemyEffects: bleeding ? [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)] : [],
                heroModifiers: profile,
            )
            battle.appliesFightPacing = false
            _ = battle.resolveDamage(DamageRequest(
                amount: 4, target: battle.enemy, keyword: .poison,
                sourceActorID: battle.hero.id, options: operation,
            ))
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
            var battle = BattleStateTestFactory.makeMinimalBattle(
                hero: CombatantFixtures.passiveHero(maxHealth: 40),
                companion: CombatantFixtures.passiveCompanion(),
                enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
                heroEffects: effects, heroModifiers: profile,
            )
            battle.appliesFightPacing = false
            _ = battle.resolveDamage(DamageRequest(
                amount: 4, target: battle.enemy, keyword: .holy,
                sourceActorID: battle.hero.id, options: operation,
            ))
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
            var battle = BattleStateTestFactory.makeMinimalBattle(
                hero: CombatantFixtures.passiveHero(maxHealth: 40),
                companion: CombatantFixtures.passiveCompanion(),
                enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
                heroModifiers: profile,
            )
            battle.appliesFightPacing = false
            if stunned {
                _ = ControlMeterEngine.applyMeterCharge(
                    20, keyword: .stun, to: battle.enemy,
                    sourceActorID: battle.hero.id, applyFightPacing: false, in: &battle,
                )
            }
            _ = battle.resolveDamage(DamageRequest(
                amount: 8, target: battle.enemy, keyword: .holy,
                sourceActorID: battle.hero.id,
                options: .attack(tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
            ))
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
