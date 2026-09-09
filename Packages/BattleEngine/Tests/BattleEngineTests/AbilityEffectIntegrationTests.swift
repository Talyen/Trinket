import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct AbilityEffectIntegrationTests {
    @Test(arguments: [Keyword.burn, .poison, .bleed])
    func `dodging an enemy attack prevents its damage over time`(keyword: Keyword) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.appliesFightPacing = false
        battle.appendEffect(.evadeNextHit, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        let before = battle.roster.hero.currentHealth
        let attack = Ability(
            id: "dodged-dot",
            name: "Afflicting Strike",
            tier: .basic,
            damageComponents: [DamageComponent(3, keyword: keyword)],
        )
        let events = BattleTurnEngine.performAction(
            ability: attack, actor: battle.enemy, abilityTarget: battle.hero, context: &battle,
        )
        #expect(events.contains { $0.effectKind == .dodgeApplied })
        #expect(battle.roster.hero.currentHealth == before)
        #expect(!battle.roster.hero.activeEffects.contains { $0.keyword == keyword })
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.hero.currentHealth == before)
    }

    @Test(arguments: [true, false])
    func `a defeated attacker stops before remaining damage and support effects`(hemorrhage: Bool) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 1
        battle.roster.hero.hasConsumedDeathsDoor = true
        battle.roster.hero.deathsDoorExpiredAtTurn = -1
        if hemorrhage {
            battle.appendEffect(.hemorrhage(4), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        } else {
            battle.appendEffect(.thorns(4), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        }
        let attack = Ability(
            id: "interrupted",
            name: "Interrupted Attack",
            tier: .basic,
            damageComponents: [DamageComponent(1), DamageComponent(10)],
            targetedEffects: [TargetedEffect(.resourceGain(.gold, 7), target: .actor)],
            criticalChanceBonus: -1,
        )
        let before = battle.roster.enemy.currentHealth
        let events = BattleTurnEngine.performAction(
            ability: attack, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(battle.roster.hero.currentHealth == 0)
        #expect(battle.roster.enemy.currentHealth == before - (hemorrhage ? 0 : 1))
        #expect(battle.gold == 0)
        #expect(events.count(where: { $0.kind == .abilityDamage }) == (hemorrhage ? 0 : 1))
    }

    private func combustionBattle() -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.combustion]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100),
            dealOpeningHand: false,
        )
    }

    private func iceShotBattle(frozenEnemy: Bool) -> BattleState {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.iceShot]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100),
            dealOpeningHand: false,
        )
        if frozenEnemy {
            BattleStateTestFactory.seedActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
                for: battle.enemy,
                on: &battle,
            )
        }
        return battle
    }

    @Test(arguments: [Ability.heal, .block])
    func `hemorrhage waits for an attack after support card`(support: Ability) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 100, effect: .hemorrhage(4), remainingTurns: 0, sourceActorID: "enemy")],
            for: battle.hero,
        )
        _ = BattleTurnEngine.performAction(
            ability: support, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == .hemorrhage(4) })
        let health = battle.health(of: battle.hero)
        _ = BattleTurnEngine.performAction(
            ability: .slash, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.effect == .hemorrhage(4) })
        #expect(battle.health(of: battle.hero) < health)
    }

    @Test func `cleansing removes hemorrhage before it can trigger`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 100, effect: .hemorrhage(4), remainingTurns: 0, sourceActorID: "enemy")],
            for: battle.hero,
        )
        let health = battle.health(of: battle.hero)
        let cleanse = Ability(id: "cleanse", name: "Cleanse", tier: .skill, effects: [.cleanse(nil)])
        _ = BattleTurnEngine.performAction(
            ability: cleanse, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(battle.health(of: battle.hero) == health)
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.effect == .hemorrhage(4) })
    }

    @Test func `combustion consumes burn for bonus damage`() {
        var context = combustionBattle()
        let before = context.roster.health(for: context.enemy)
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(6), remainingTurns: 0)],
            for: context.enemy,
            on: &context,
        )
        _ = BattleTurnEngine.performAction(
            ability: .combustion,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let remainingBurn = context.roster.activeEffects(for: context.enemy).filter { $0.effect.keyword == .burn }
        #expect(remainingBurn.isEmpty)
        let lost = before - context.roster.health(for: context.enemy)
        #expect(lost > 4)
    }

    @Test func `combustion detonates even freshly applied burn`() {
        var context = combustionBattle()
        let before = context.roster.health(for: context.enemy)
        _ = BattleTurnEngine.performAction(
            ability: .combustion,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let remainingBurn = context.roster.activeEffects(for: context.enemy).filter { $0.effect.keyword == .burn }
        #expect(remainingBurn.isEmpty)
        let lost = before - context.roster.health(for: context.enemy)
        #expect(lost > 4)
    }

    @Test func `damage component applies do T stack without immediate tick`() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.kindling],
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        var context = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            rngSeed: CombatantFixtures.deterministicBattleSeed,
            dealOpeningHand: false,
        )
        let startingHealth = context.roster.health(for: enemy)

        let events = BattleTurnEngine.performAction(
            ability: .kindling,
            actor: hero,
            abilityTarget: enemy,
            context: &context,
        )

        try #expect(context.roster.activeEffects(for: enemy).contains { $0.effect.keyword == .burn })
        let abilityDamage = events
            .filter { $0.kind == ActionEvent.Kind.abilityDamage }
            .reduce(0) { $0 + $1.amount }
        try #expect(context.roster.health(for: enemy) == startingHealth - abilityDamage)
        try #expect(!events.contains { $0.kind == ActionEvent.Kind.status && $0.keyword == .burn })
    }

    @Test func `ice shot shatters a frozen enemy`() {
        var context = iceShotBattle(frozenEnemy: true)
        let events = BattleTurnEngine.performAction(
            ability: .iceShot,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let components = events.filter { $0.kind == .abilityDamage }
        #expect(components.count == 2)
        #expect(components.map(\.keyword) == [.freeze, .physical])
    }

    @Test func `ice shot skips shatter on an unfrozen enemy`() {
        var context = iceShotBattle(frozenEnemy: false)
        let events = BattleTurnEngine.performAction(
            ability: .iceShot,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let components = events.filter { $0.kind == .abilityDamage }
        #expect(components.count == 1)
        #expect(components.map(\.keyword) == [.freeze])
    }
}
