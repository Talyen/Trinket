import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct BattleStateSchedulingTests {
    private var wolfPet: Combatant { GameContent.pets.first { $0.id == "wolf" }! }

    private func advance(_ battle: inout BattleState) -> BattleStep {
        battle.advanceOneStep()
    }

    @Test func advanceOneStepReturnsEndedWhenBattleOver() {
        let fragile = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let helper = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: fragile, pet: helper, enemy: enemy)

        while !battle.isBattleOver {
            _ = advance(&battle)
        }

        if case let .ended(events) = advance(&battle) {
            #expect(events.isEmpty)
        } else {
            Issue.record("Expected ended step when battle is over")
        }
    }

    @Test func firstActionIsHeroOnSecondTick() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        if case .effectsOnly = advance(&battle) {
            // tick 1: nobody acts
        } else {
            Issue.record("Expected effects-only step on tick 1")
        }

        if case let .acted(actor, events) = advance(&battle) {
            #expect(actor.id == hero.id)
            #expect(events.filter { $0.kind == .ability }.map(\.actorName) == ["Hero"])
        } else {
            Issue.record("Expected hero to act on tick 2")
        }

        #expect(battle.actionCount(of: battle.enemy) == 0)
    }

    @Test func petActsOnThirdTickAfterHero() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = advance(&battle)
        _ = advance(&battle)

        if case let .acted(actor, events) = advance(&battle) {
            #expect(actor.id == pet.id)
            #expect(events.filter { $0.kind == .ability }.map(\.actorName) == ["Pet"])
        } else {
            Issue.record("Expected pet to act on tick 3")
        }
    }

    @Test func onlyOneActorActsPerStep() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = advance(&battle)
        let heroStep = advance(&battle)
        let petStep = advance(&battle)

        if case let .acted(heroActor, heroEvents) = heroStep {
            #expect(heroActor.id == hero.id)
            #expect(heroEvents.filter { $0.kind == .ability }.count == 1)
        } else {
            Issue.record("Expected hero step")
        }

        if case let .acted(petActor, petEvents) = petStep {
            #expect(petActor.id == pet.id)
            #expect(petEvents.filter { $0.kind == .ability }.count == 1)
        } else {
            Issue.record("Expected pet step")
        }
    }

    @Test func enemyAttacksOnSixthTick() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 50, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 50, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        for _ in 0 ..< 5 {
            _ = advance(&battle)
        }
        #expect(battle.actionCount(of: battle.enemy) == 0)

        if case let .acted(actor, _) = advance(&battle) {
            #expect(actor.id == enemy.id)
        } else {
            Issue.record("Expected enemy to act on tick 6")
        }
        #expect(battle.actionCount(of: battle.enemy) == 1)
        #expect(battle.tickCount == 6)
    }

    @Test func fastEnemyActsBeforePartyOnSeparateSteps() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        if case let .acted(actor, _) = advance(&battle) {
            #expect(actor.id == enemy.id)
        } else {
            Issue.record("Expected enemy on tick 1")
        }

        if case let .acted(actor, _) = advance(&battle) {
            #expect(actor.id == hero.id)
        } else {
            Issue.record("Expected hero on tick 2")
        }

        if case let .acted(actor, _) = advance(&battle) {
            #expect(actor.id == pet.id)
        } else {
            Issue.record("Expected pet on tick 3")
        }
    }

    @Test func burnEffectExpiresAfterDuration() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0)
            ]
        )

        #expect(!(battle.effectSummaries(of: battle.enemy)).filter { $0.keyword == .burn }.isEmpty)
        _ = advance(&battle)
        _ = advance(&battle)
        _ = advance(&battle)
        #expect(battle.effectSummaries(of: battle.enemy).filter { $0.keyword == .burn }.isEmpty)
    }

    @Test func poisonEffectExpiresAfterDuration() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)
            ]
        )

        #expect(!(battle.effectSummaries(of: battle.enemy)).filter { $0.keyword == .poison }.isEmpty)
        _ = advance(&battle)
        _ = advance(&battle)
        _ = advance(&battle)
        _ = advance(&battle)
        #expect(battle.effectSummaries(of: battle.enemy).filter { $0.keyword == .poison }.isEmpty)
    }

    @Test func effectsOnlyStepWhenNobodyReady() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        if case .effectsOnly = advance(&battle) {
            #expect(battle.tickCount == 1)
        } else {
            Issue.record("Expected passive tick before first actions")
        }
    }

    @Test func rangerHeroFirstActionGrantsExactGold() throws {
        let goldHero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.blackjack])
        var battle = BattleStateTestFactory.makeBattle(hero: goldHero, pet: wolfPet, enemy: defaultEnemy, initialGold: 10)

        _ = advance(&battle)
        _ = advance(&battle)

        #expect(battle.gold == 11)
        #expect(battle.earnedGold == 1)
    }

    @Test func skillFiresOnTurn3UltimateOnTurn6() {
        let basic = Ability(id: "basic", name: "BasicAtk", tier: .basic, directDamage: 1, description: "Basic")
        let skill = Ability(id: "skill", name: "SkillAtk", tier: .skill, directDamage: 3, description: "Skill")
        let ultimate = Ability(id: "ultimate", name: "UltAtk", tier: .ultimate, directDamage: 6, description: "Ultimate")
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            abilities: [basic, skill, ultimate]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 1000,
            actionIntervalTicks: 100,
            abilities: []
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        var heroAbilityNames: [String] = []
        var safety = 0
        while heroAbilityNames.count < 6, safety < 40 {
            let step = battle.advanceOneStep()
            heroAbilityNames.append(
                contentsOf: step.events
                    .filter { $0.actorName == "Hero" && $0.kind == .ability }
                    .map(\.abilityName)
            )
            safety += 1
            if battle.isBattleOver { break }
        }

        #expect(heroAbilityNames == ["BasicAtk", "BasicAtk", "SkillAtk", "BasicAtk", "BasicAtk", "UltAtk"])
    }

    private var defaultEnemy: Combatant {
        GameContent.enemies.first!.combatant
    }
}
