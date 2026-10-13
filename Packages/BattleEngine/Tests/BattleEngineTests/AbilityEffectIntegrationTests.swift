import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct AbilityEffectIntegrationTests {
    @Test(arguments: [0, 2, 8])
    func `hemorrhage preserves Block and lethal protection events in feedback and history`(block: Int) throws {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            heroHealth: 3,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.hemorrhage(4), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        DefensePoolEngine.set(block, on: battle.hero, in: &battle)

        let events = CombatExecutor.run {
            await BattleTurnEngine.consumeHemorrhageIfActive(for: battle.hero, in: &battle)
        }
        #expect(events == battle.events)
        let healthLost = min(3, max(0, 4 - block))
        let hemorrhage = events.filter { $0.effectKind == .hemorrhageTriggered }
        #expect(hemorrhage.map(\.amount) == (healthLost > 0 ? [healthLost] : []))
        if block > 0 {
            let absorbed = try #require(events.first { $0.effectKind == .shieldAbsorbed })
            #expect(absorbed.amount == min(block, 4))
            #expect(absorbed.keyword == .block)
        } else {
            #expect(events.contains { $0.effectKind == .deathsDoorTriggered })
            #expect(battle.roster.hero.currentHealth == 1)
        }
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `a finishing hit cannot steal Gold again from the defeated enemy`(owner: BattleParticipant) throws {
        var triggers = CombatTraitTriggers()
        triggers.criticalGoldStealFlat = 2
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 1,
            heroModifiers: owner == .hero ? CombatModifierProfile(triggers: triggers) : .zero,
            companionModifiers: owner == .companion ? CombatModifierProfile(triggers: triggers) : .zero,
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let attack = Ability(
            id: "finishing-double-hit", name: "Finishing Double Hit", tier: .basic,
            damageComponents: [DamageComponent(1), DamageComponent(1)],
            criticalChanceBonus: 1,
        )

        let card = BattleCardCombatEngine.deal(attack, owner: owner, context: &battle)
        let events = try battle.playCard(cardID: card.id).events

        #expect(battle.isEnemyDefeated)
        #expect(events.count { $0.kind == .abilityDamage && $0.abilityID == attack.id } == 1)
        #expect(battle.gold == 2)
    }

    @Test(arguments: [false, true])
    func `Dodge Gold theft uses theft modifiers without changing legacy Gold`(isTheft: Bool) {
        var profile = CombatantTalentCatalog.profile(for: ["fox_gold_t1_1"])
        profile.triggers.dodgeGoldChancePercent = 1
        profile.triggers.dodgeGoldIsTheft = isTheft
        profile.triggers.goldStealFlatBonus = 3
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile, dealOpeningHand: false,
        )
        _ = CombatExecutor.run {
            await CombatTriggerEngine.afterDodge(by: battle.companion, attackerID: battle.enemy.id, in: &battle)
        }
        #expect(battle.gold == (isTheft ? 7 : 4))
    }

    @Test(arguments: [false, true])
    func `War Chest converts actual stolen Gold to resolved Hero Block`(ownerDefeated: Bool) {
        var profile = CombatantTalentCatalog.profile(for: ["golden_retriever_gold_t4_1"])
        profile.triggers.goldStealFlatBonus = 2
        profile.goldGainedPercent = 0.5
        profile.blockGainedPercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile, dealOpeningHand: false,
        )
        if ownerDefeated {
            battle.roster.companion.currentHealth = 0
        }
        _ = battle.grantGoldEvent(2, to: battle.companion, abilityName: "Gold")
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 0)
        let before = battle.gold
        _ = battle.grantGoldEvent(2, to: battle.companion, abilityName: "Steal", isTheft: true)
        #expect(battle.gold - before == (ownerDefeated ? 3 : 6))
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == (ownerDefeated ? 0 : 6))
    }

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
        let events = battle.performTestAction(attack, from: .enemy, to: .hero)
        #expect(events.contains { $0.effectKind == .dodgeApplied })
        #expect(battle.roster.hero.currentHealth == before)
        #expect(!battle.roster.hero.activeEffects.contains { $0.keyword == keyword })
        _ = CombatExecutor.run { await EffectTurnEngine.advanceAll(context: &battle) }
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
        let events = battle.performTestAction(attack)
        #expect(battle.roster.hero.currentHealth == 0)
        #expect(battle.roster.enemy.currentHealth == before - (hemorrhage ? 0 : 1))
        #expect(battle.gold == 0)
        #expect(events.count(where: { $0.kind == .abilityDamage }) == (hemorrhage ? 0 : 1))
    }

    func combustionBattle() -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.combustion]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100),
            dealOpeningHand: false,
        )
    }

    func iceShotBattle(frozenEnemy: Bool) -> BattleState {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.iceShot]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100),
            dealOpeningHand: false,
        )
        if frozenEnemy {
            battle.seedActiveEffects([ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)], for: battle.enemy)
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
        battle.performTestAction(support)
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == .hemorrhage(4) })
        let health = battle.health(of: battle.hero)
        battle.performTestAction(.slash)
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
        battle.performTestAction(cleanse)
        #expect(battle.health(of: battle.hero) == health)
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.effect == .hemorrhage(4) })
    }

    @Test(arguments: [(0.0, false, 7), (0.2, false, 9), (0.35, false, 11), (0.0, true, 14)])
    func `burn detonation deals all remaining ticks before consuming the status`(
        slow: Double, doubleTicks: Bool, expectedDamage: Int,
    ) {
        var triggers = CombatTraitTriggers()
        triggers.burnDecaySlowPercent = slow
        triggers.burnTicksTwicePerTurn = doubleTicks
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatModifierProfile(triggers: triggers), dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.burn(8), to: battle.enemy, sourceID: battle.companion.id, remainingTurns: 0)
        let before = battle.roster.enemy.currentHealth

        _ = EffectHandlersTestSupport.dispatch(
            .detonateDoT(.burn, 1), source: battle.hero, target: battle.enemy, battle: &battle,
        )

        #expect(before - battle.roster.enemy.currentHealth == expectedDamage)
        #expect(!battle.roster.enemy.activeEffects.contains { $0.effect.kind == .burn })
    }

    @Test(arguments: [false, true])
    func `combustion detonates freshly applied and existing burn`(existingBurn: Bool) {
        var context = combustionBattle()
        let before = context.roster.health(for: context.enemy)
        if existingBurn {
            context.seedActiveEffects(
                [ActiveEffect(id: 1, effect: .burn(6), remainingTurns: 0)], for: context.enemy,
            )
        }
        context.performTestAction(.combustion)
        let remainingBurn = context.roster.activeEffects(for: context.enemy).filter { $0.effect.keyword == .burn }
        #expect(remainingBurn.isEmpty)
        let lost = before - context.roster.health(for: context.enemy)
        #expect(lost > 4)
    }
}
