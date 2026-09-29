import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HomesteadCombatTests {
    @Test(arguments: [false, true])
    func `crystal bonus changes only the existing critical hit`(critical: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            heroModifiers: .init(modifiers: [.criticalDamage(4)]),
        )
        battle.appliesFightPacing = false
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: .effect(scaling: .items, abilityCriticalChanceBonus: critical ? 0 : -1, guaranteedCritical: critical),
        ))
        #expect(outcome.healthLost == (critical ? 24 : 10))
    }

    @Test func `leyline strengthens positive restoration without creating a zero grant`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(), heroModifiers: .init(modifiers: [.manaRestored(4)]),
        )
        _ = battle.payMana(1000, for: battle.hero)
        #expect(battle.restoreMana(0, to: battle.hero) == 0)
        #expect(battle.restoreMana(1, to: battle.hero) == min(5, battle.roster.maxMana(for: battle.hero)))
    }

    @Test(arguments: [false, true])
    func `percentage damage combines before rounding and Critical remains conditional`(critical: Bool) throws {
        let hero = CombatantFixtures.passiveHero()
        let companion = CombatantFixtures.passiveCompanion()
        let bow = try ItemFixtures.makeBareItem("shortbow")
        for ranged in [false, true] {
            let actor = ranged ? hero : companion
            let build = CombatBuildResolver.build(
                combatant: actor,
                equipmentLoadout: ranged ? .init(itemIDsBySlot: [.weapon: bow.id]) : .init(), inventory: [bow],
                additionalModifiers: [.damageDealtPercent(.physical, 0.25), .criticalDamagePercent(0.4),
                                      ranged ? .rangedDamageDealtPercent(0.2) : .companionDamageDealtPercent(0.2)],
            )
            var battle = BattleStateTestFactory.makeMinimalBattle(
                hero: hero, companion: companion, enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
                heroModifiers: ranged ? build.modifiers : .zero, companionModifiers: ranged ? .zero : build.modifiers,
            )
            battle.appliesFightPacing = false
            let outcome = battle.resolveDamage(DamageRequest(
                amount: 20, target: battle.enemy, keyword: .physical, sourceActorID: actor.id,
                options: .effect(scaling: .items, abilityCriticalChanceBonus: critical ? 0 : -1, guaranteedCritical: critical),
            ))
            #expect(outcome.healthLost == (critical ? 81 : 29))
        }
        let unarmed = CombatBuildResolver.build(
            combatant: companion, equipmentLoadout: .init(), inventory: [],
            additionalModifiers: [.rangedDamageDealtPercent(0.2)],
        )
        #expect(unarmed.modifiers.damageDealtPercent(for: .physical) == 0)
    }

    @Test func `percentage Health agrees between build and runtime and keeps flat equipment`() {
        let hero = CombatantFixtures.passiveHero(maxHealth: 20)
        let modifiers = CombatModifierProfile(modifiers: [.maximumHealth(5), .maximumHealthPercent(0.4)])
        let battle = BattleState(
            hero: hero, companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(), heroModifiers: modifiers, dealOpeningHand: false,
        )
        #expect(CombatantMaxValues.maxHealth(for: hero, modifiers: modifiers) == 35)
        #expect(battle.roster.maxHealth(for: hero) == 35)
        #expect(battle.roster.health(for: hero) == 35)
    }

    @Test func `percentage Critical bonus also scales existing flat Critical equipment`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            heroModifiers: .init(modifiers: [.criticalDamage(4), .criticalDamagePercent(0.4)]),
        )
        battle.appliesFightPacing = false
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: .effect(scaling: .items, guaranteedCritical: true),
        ))
        #expect(outcome.healthLost == 34)
    }

    @Test func `restoration and Block percentages apply once and do not create zero gains`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100, maxMana: 20),
            companion: CombatantFixtures.passiveCompanion(), enemy: CombatantFixtures.passiveEnemy(), heroHealth: 10,
            heroModifiers: .init(modifiers: [.healthRestoredPercent(0.4), .leechHealingPercent(0.2),
                                             .manaRestoredPercent(0.4), .blockGainedPercent(0.4)]),
        )
        battle.appliesFightPacing = false
        _ = battle.resolveHeal(HealRequest(amount: 10, target: battle.hero, sourceActorID: battle.hero.id))
        #expect(battle.roster.hero.currentHealth == 24)
        _ = HealingEngine.leechFromDamage(20, sourceActorID: battle.hero.id, abilityHasLeech: true, in: &battle)
        #expect(battle.roster.hero.currentHealth == 41)
        _ = battle.payMana(1000, for: battle.hero)
        #expect(battle.restoreMana(0, to: battle.hero) == 0)
        #expect(battle.restoreMana(10, to: battle.hero) == 14)
        let gain = battle.applyBlockGain(10, to: battle.hero, source: battle.hero, abilityName: "Block")
        #expect(gain.applied == 14)
        let copy = battle.applyBlockGain(10, to: battle.hero, source: battle.hero, abilityName: "Copy", amountBasis: .resolved)
        #expect(copy.applied == 10)
        #expect(battle.applyBlockGain(0, to: battle.hero, source: battle.hero, abilityName: "Zero").applied == 0)
    }

    @Test func `Mycology percentage scales flat equipment and conditional Leech healing`() {
        var modifiers = CombatModifierProfile(modifiers: [.leechHealing(5), .leechHealingPercent(0.2)])
        modifiers.triggers.leechBonusHealVsLowHealthEnemies = 5
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100), heroHealth: 10,
            heroModifiers: modifiers,
        )
        battle.appliesFightPacing = false
        battle.roster.enemy.currentHealth = 40
        _ = HealingEngine.leechFromDamage(
            20, sourceActorID: battle.hero.id, target: battle.enemy, abilityHasLeech: true, in: &battle,
        )
        #expect(battle.roster.hero.currentHealth == 34)
    }
}
