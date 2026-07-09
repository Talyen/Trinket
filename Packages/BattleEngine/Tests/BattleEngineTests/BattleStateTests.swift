import Testing
import TrinketTestSupport
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct BattleStateTests {
    private var defaultEnemy: Combatant { GameContent.enemies.first!.combatant }
    private var wolfPet: Combatant { GameContent.pets.first { $0.id == "wolf" }! }

    private func advance(_ battle: inout BattleState) -> BattleStep {
        battle.advanceOneStep()
    }

    @Test func heroActsOnSecondTickPetOnThird() throws {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: defaultEnemy)

        _ = advance(&battle)
        let heroStep = advance(&battle)
        let petStep = advance(&battle)

        if case let .acted(actor, events) = heroStep {
            try #expect(actor.id == hero.id)
            try #expect(events.filter { $0.kind == .ability }.map(\.actorName) == ["Hero"])
        } else {
            Issue.record("Expected hero step")
        }

        if case let .acted(actor, events) = petStep {
            try #expect(actor.id == pet.id)
            try #expect(events.filter { $0.kind == .ability }.map(\.actorName) == ["Pet"])
        } else {
            Issue.record("Expected pet step")
        }
    }

    @Test func enemyHealthDecreasesOnHit() throws {
        var battle = BattleStateTestFactory.makeBattle(hero: GameContent.heroes[0], pet: wolfPet, enemy: defaultEnemy)
        let initial = battle.health(of: battle.enemy)
        _ = advance(&battle)
        _ = advance(&battle)
        try #expect(battle.health(of: battle.enemy) < initial)
    }

    @Test func enemyAttackTargetPrefersHigherHealthMember() throws {
        var battle = BattleStateTestFactory.makeBattle(hero: GameContent.heroes[0], pet: wolfPet, enemy: defaultEnemy)
        let target = battle.enemyAttackTarget
        try #expect(target.id == heroId)
    }

    @Test func enemyTargetsPetWhenHeroDead() throws {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero, maxHealth: 1, actionIntervalTicks: 2)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: hero) { $0.currentHealth = 0 }
        }

        try #expect(!(battle.isHeroAlive))
        try #expect(battle.enemyAttackTarget.id == pet.id)
    }

    @Test func burnDealsDamageAfterApplication() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.fireball]
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, actionIntervalTicks: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: defaultEnemy)
        _ = advance(&battle)
        let applyStep = advance(&battle)
        try #expect(applyStep.events.contains { $0.kind == .ability && $0.keyword == .burn })
        let tickStep = advance(&battle)
        try #expect(tickStep.events.contains { ActionEventFormatter.display(for: $0).text == "-1 Burn" })
    }

    @Test func partyDefeatWhenBothHeroAndPetDie() throws {
        let fragile = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let helper = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: fragile, pet: helper, enemy: enemy)
        while !battle.isBattleOver {
            _ = advance(&battle)
        }
        try #expect(battle.isPartyDefeated)
        try #expect(!(battle.isEnemyDefeated))
    }

    @Test func partyNotDefeatedWhenOneMemberOnDeathsDoor() throws {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero, maxHealth: 5)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: pet) { $0.currentHealth = 0 }
        }
        try #expect(!(battle.isPetAlive))

        let heroID = battle.hero
        battle.withEngineContext { context in
            _ = context.applyTestDamage(5, to: heroID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        }
        try #expect(battle.health(of: battle.hero) == 1)
        try #expect(battle.activeEffects(of: battle.hero).contains { $0.effect.kind == .deathsDoor })
        try #expect(!(battle.isPartyDefeated))
    }

    @Test func partyDefeatWhenBothDeathsDoorConsumedAndExpired() throws {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero, maxHealth: 3)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, maxHealth: 3)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)
        let heroID = battle.hero
        let petID = battle.pet

        battle.withEngineContext { context in
            _ = context.applyTestDamage(3, to: heroID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            _ = context.applyTestDamage(3, to: petID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        }
        try #expect(!(battle.isPartyDefeated))

        for _ in 0 ..< BattleTiming.deathsDoorDurationTicks {
            _ = battle.advanceOneStep()
        }
        // Expiry grace lasts through the tick Death's Door fell off; advance once more to clear it.
        _ = battle.advanceOneStep()

        battle.withEngineContext { context in
            _ = context.applyTestDamage(3, to: heroID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            _ = context.applyTestDamage(3, to: petID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        }

        try #expect(battle.isPartyDefeated)
    }

    @Test func smiteDealsHolyDamageType() throws {
        let smite = Ability.smite
        try #expect(smite.damageKeyword == .holy)
        try #expect(smite.damageType == .holy)
    }

    @Test func poisonDaggerDealsPoisonDamageAndDot() throws {
        let ability = Ability.poisonDagger
        try #expect(ability.damageKeyword == .poison)
        try #expect(ability.damageType == .poison)
        let hasPoisonDot = ability.effects.contains {
            if case .poison = $0 { return true }
            return false
        }
        try #expect(hasPoisonDot)
    }

    @Test func serratedEdgeDealsBleedDamageAndDot() throws {
        let ability = Ability.serratedEdge
        try #expect(ability.damageKeyword == .bleed)
        let hasBleedDot = ability.effects.contains {
            if case .bleed = $0 { return true }
            return false
        }
        try #expect(hasBleedDot)
    }

    @Test func judgmentDealsHolyDamageAndGrantsBlock() throws {
        let ability = Ability.judgment
        try #expect(ability.damageKeyword == .holy)
        let hasBlock = ability.effects.contains {
            if case .shield(.block, _, _) = $0 { return true }
            return false
        }
        let hasStunDamage = ability.damageComponents.contains { $0.keyword == .stun }
        try #expect(hasBlock)
        try #expect(!(hasStunDamage))
    }

    @Test func battleTracksGoldFromResourceGains() throws {
        let goldHero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.blackjack])
        var battle = BattleStateTestFactory.makeBattle(hero: goldHero, pet: wolfPet, enemy: defaultEnemy, initialGold: 10)
        _ = advance(&battle)
        _ = advance(&battle)
        try #expect(battle.gold == 11)
    }

    @Test func initialGoldReflectedInEarnedGold() throws {
        var battle = BattleStateTestFactory.makeBattle(hero: GameContent.heroes[2], pet: wolfPet, enemy: defaultEnemy, initialGold: 5)
        _ = advance(&battle)
        _ = advance(&battle)
        try #expect(battle.earnedGold == battle.gold - 5)
    }

    @Test func battleSimulatorDeterministicWithSeed() throws {
        let hero = GameContent.heroes[2]
        let result1 = BattleSimulator.run(hero: hero, pet: wolfPet, enemy: defaultEnemy, options: BattleSimulationOptions(seed: 42))
        let result2 = BattleSimulator.run(hero: hero, pet: wolfPet, enemy: defaultEnemy, options: BattleSimulationOptions(seed: 42))
        try #expect(
            result1.events.map(ActionEventFormatter.display(for:)).map(\.text) == result2.events.map(ActionEventFormatter.display(for:)).map(\.text)
        )
        try #expect(result1.metrics == result2.metrics)
    }

    @Test func battleVictoryOutcome() throws {
        let hero = GameContent.heroes[2]
        let result = BattleSimulator.run(hero: hero, pet: wolfPet, enemy: defaultEnemy)
        try #expect(result.outcome == BattleSimulationOutcome.victory)
        try #expect(result.didWin)
    }

    @Test func tickLimitWhenBattleCannotFinish() throws {
        let watcher = Combatant(id: "watcher", name: "Watcher", role: .hero, maxHealth: 10, abilities: [])
        let observer = Combatant(id: "observer", name: "Observer", role: .pet, maxHealth: 10, abilities: [])
        let enemy = Combatant(id: "wall", name: "Wall", role: .enemy, maxHealth: 5, abilities: [])
        let result = BattleSimulator.run(hero: watcher, pet: observer, enemy: enemy, maxTicks: 3)
        try #expect(result.outcome == BattleSimulationOutcome.tickLimit)
        try #expect(result.didHitTickLimit)
    }

    @Test func defeatWhenPartyIsObliterated() throws {
        let fragile = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let observer = Combatant(id: "observer", name: "Observer", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        let result = BattleSimulator.run(hero: fragile, pet: observer, enemy: enemy)
        try #expect(result.outcome == BattleSimulationOutcome.defeat)
    }

    @Test func burnAndPoisonStackIndependently() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: GameContent.heroes[0], pet: wolfPet, enemy: defaultEnemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .poison(4), remainingTicks: 0)
            ]
        )
        _ = advance(&battle)
        let summaries = battle.effectSummaries(of: battle.enemy)
        let burnSummary = try #require(summaries.first { $0.keyword == .burn })
        let poisonSummary = try #require(summaries.first { $0.keyword == .poison })
    }

    @Test func seededEffectsDoNotCollideWithNewEffectIDs() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: GameContent.heroes[0],
            pet: wolfPet,
            enemy: defaultEnemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0)
            ]
        )
        let source = battle.hero
        let target = battle.enemy
        let outcome = EffectHandlersTestSupport.dispatch(
            .shield(.block, 5, 3),
            ability: CombatantFixtures.ability(),
            source: source,
            target: target,
            battle: &battle
        )
        try #expect(outcome.didApply)
        let ids = battle.activeEffects(of: battle.enemy).map(\.id)
        try #expect(Set(ids).count == ids.count)
        try #expect(!(ids.contains(1) && ids.filter { $0 == 1 }.count > 1))
        try #expect(ids.contains(2))
    }

    @Test func petSkipsActionWhenHeroKillsEnemySameStep() throws {
        let finisher = Ability(id: "finisher", name: "Finisher", tier: .basic, directDamage: 1, description: "Finisher")
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [finisher])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 1, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = advance(&battle)
        let heroStep = advance(&battle)

        try #expect(battle.isEnemyDefeated)
        if case let .acted(actor, events) = heroStep {
            try #expect(actor.id == hero.id)
            try #expect(!(events.contains { $0.actorName == "Pet" && $0.kind == .ability }))
        } else if case let .ended(events) = heroStep {
            try #expect(!(events.contains { $0.actorName == "Pet" && $0.kind == .ability }))
        } else {
            Issue.record("Expected hero to act before battle ended")
        }

        let petStep = advance(&battle)
        switch petStep {
        case .ended:
            break
        case let .acted(actor, _):
            Issue.record("Pet should not act after enemy defeat, got \(actor.name)")
        default:
            try #expect(battle.isBattleOver)
        }
    }

    @Test func faustianBargainSelfDamageDoesNotWipePartyWhenPetSurvives() throws {
        let hero = Combatant(
            id: "warlock",
            name: "Warlock",
            role: .hero,
            maxHealth: 3,
            actionIntervalTicks: 1,
            abilities: [.faustianBargain]
        )
        let pet = Combatant(
            id: "pet",
            name: "Pet",
            role: .pet,
            maxHealth: 20,
            actionIntervalTicks: 100,
            abilities: []
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 6,
            actionIntervalTicks: 100,
            abilities: []
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        while !battle.isBattleOver {
            _ = advance(&battle)
        }

        try #expect(!(battle.isPartyDefeated))
        try #expect(battle.isEnemyDefeated)
    }

    @Test func rosterContextInitPreservesRngSeed() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        let seed: UInt64 = 42
        let battle = BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                pet: CombatantRuntime(combatant: pet),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: seed),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: .zero
        )
        try #expect(battle.rngSeed == seed)
    }

    private var heroId: String {
        GameContent.heroes[0].id
    }
}
