import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct EncounterModifierCombatTests {
    @Test func `shielded arrival grants enemy block before play`() {
        let battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(),
            enemyModifiers: CombatModifierProfile(modifiers: [.startBattleBlock(6)]),
            dealOpeningHand: false,
        )
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 6)
        #expect(battle.events.contains { $0.effectKind == .shieldApplied && $0.abilityName == "Shielded Arrival" })
    }

    @Test func `enemy attack leeches health damage but effects do not`() {
        var enemy = CombatModifierProfile(modifiers: [.attackLeechPercent(0.5)])
        enemy.triggers.criticalChanceBonus = -1
        let hero = CombatModifierProfile(triggers: CombatTraitTriggers(dodge: DodgeTriggers(dodgeChanceBonus: -1)))
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: hero, enemyModifiers: enemy)
        battle.appliesFightPacing = false
        _ = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: .attack(scaling: .flat),
        ))
        let enemyBefore = battle.health(of: battle.enemy)

        let attack = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat),
        ))
        #expect(attack.healthLost > 0)
        #expect(battle.health(of: battle.enemy) == enemyBefore + CombatRounding.scaled(attack.healthLost, multiplier: 0.5))

        let afterAttack = battle.health(of: battle.enemy)
        _ = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .effect(scaling: .flat),
        ))
        #expect(battle.health(of: battle.enemy) == afterAttack)
    }

    @Test func `landed enemy attacks strip block before damage`() {
        let hero = CombatModifierProfile(triggers: CombatTraitTriggers(dodge: DodgeTriggers(dodgeChanceBonus: -1)))
        let enemy = CombatModifierProfile(modifiers: [.attackBlockRemoval(2)])
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: hero, enemyModifiers: enemy)
        battle.appliesFightPacing = false
        DefensePoolEngine.set(6, on: battle.hero, in: &battle)
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 5, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat),
        ))
        #expect(outcome.healthLost == 1)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 0)
        #expect(outcome.events.contains { $0.effectKind == .blockStripped && $0.amount == 2 })
    }

    @Test func `landed enemy attacks purge one surviving buff`() {
        let hero = CombatModifierProfile(triggers: CombatTraitTriggers(dodge: DodgeTriggers(dodgeChanceBonus: -1)))
        let enemy = CombatModifierProfile(modifiers: [.attackPurgeCount(1)])
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: hero, enemyModifiers: enemy)
        battle.appliesFightPacing = false
        DefensePoolEngine.set(10, on: battle.hero, in: &battle)
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat),
        ))
        #expect(outcome.healthLost == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 0)
        #expect(outcome.events.contains { $0.effectKind == .purgeApplied && $0.abilityName == "Unbinding Strike" })
    }

    @Test func `landed enemy attack still purges when retaliation defeats its source`() {
        var companion = CombatantTalentCatalog.profile(for: ["frost_whelp_freeze_t1_2"])
        companion.triggers.onDamageFreezeRetaliationChancePercent = 1
        var battle = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 4,
            companionModifiers: companion,
            enemyModifiers: CombatModifierProfile(modifiers: [.attackPurgeCount(1)]),
        )
        battle.appliesFightPacing = false
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .thorns(3), remainingTurns: 2)],
            for: battle.companion, on: &battle,
        )
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.companion, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ))
        #expect(battle.health(of: battle.enemy) == 0)
        #expect(outcome.events.contains { $0.effectKind == .purgeApplied && $0.abilityName == "Unbinding Strike" })
        #expect(!battle.activeEffects(of: battle.companion).contains { $0.effect == .thorns(3) })
    }

    @Test(arguments: Keyword.damageTypes)
    func `typed ward halves damage`(keyword: Keyword) {
        var hero = CombatModifierProfile()
        hero.triggers.criticalChanceBonus = -1
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: hero,
            enemyModifiers: CombatModifierProfile(modifiers: [.damageTakenPercent(keyword, 0.5)]),
        )
        battle.appliesFightPacing = false
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: keyword, sourceActorID: battle.hero.id,
            options: .attack(scaling: .flat),
        ))
        #expect(outcome.healthLost == 4)
    }

    @Test(arguments: [Keyword.burn, .poison, .bleed])
    func `typed ward halves periodic damage`(keyword: Keyword) {
        var battle = BattleTestFixtures.makePipelineContext(
            enemyModifiers: CombatModifierProfile(modifiers: [.damageTakenPercent(keyword, 0.5)]),
        )
        battle.appliesFightPacing = false
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: keyword, sourceActorID: battle.hero.id,
            options: .periodic,
        ))
        #expect(outcome.healthLost == 4)
    }
}
