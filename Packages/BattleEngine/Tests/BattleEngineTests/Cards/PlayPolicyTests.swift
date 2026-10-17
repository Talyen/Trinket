import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct PlayPolicyTests {
    @Test func `setup policy prefers new Poison over leftmost chip`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 40, dealOpeningHand: false)
        _ = BattleCardCombatEngine.deal(
            Ability(id: "chip", name: "Chip", tier: .basic, directDamage: 2), owner: .hero, context: &battle,
        )
        let preferred = BattleCardCombatEngine.deal(
            Ability(id: "envenom", name: "Envenom", tier: .basic, effects: [.poison(4)]), owner: .hero, context: &battle,
        )
        #expect(PlayPolicy.setupAware.preferredPlayableCard(in: battle)?.id == preferred.id)
    }

    @Test func `setup policy does not mistake a Burn ward for an affliction`() {
        var battle = finishingBattle(enemyHealth: 100)
        battle.roster.hero.currentHealth = battle.roster.hero.maxHealth
        battle.insertEffect(.onHitDamage(.burn, 2), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        let chip = BattleCardCombatEngine.deal(
            Ability(id: "chip", name: "Chip", tier: .basic, directDamage: 8), owner: .hero, context: &battle,
        )
        let setup = BattleCardCombatEngine.deal(
            Ability(id: "setup", name: "Setup", tier: .basic, effects: [.burn(2)]),
            owner: .hero, context: &battle,
        )
        #expect(PlayPolicy.setupAware.preferredPlayableCard(in: battle)?.id == setup.id)
        battle.insertEffect(.burn(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)
        #expect(PlayPolicy.setupAware.preferredPlayableCard(in: battle)?.id == chip.id)
    }

    @Test(arguments: [Ability.kindling, .shieldBash])
    func `nonlethal choices account for conditional and scaled damage`(ability: Ability) throws {
        var battle = finishingBattle(enemyHealth: 100)
        battle.roster.hero.currentHealth = battle.roster.hero.maxHealth
        battle.roster.hero.currentMana = 0
        DefensePoolEngine.set(12, on: battle.hero, in: &battle)
        _ = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        let preferred = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)
        for policy in PlayPolicy.allCases {
            #expect(policy.preferredPlayableCard(in: battle)?.id == preferred.id)
        }
        let before = battle.health(of: battle.enemy)
        _ = try battle.playCard(cardID: preferred.id)
        #expect(before - battle.health(of: battle.enemy) > Ability.slash.directDamage)
        #expect(!battle.isEnemyDefeated)
    }

    @Test(arguments: [Ability.blackjack, .coldSnap, Ability(
        id: "conditional-gain", name: "Conditional Gain", tier: .basic,
        outcomeBranches: [
            AbilityOutcomeBranch(effects: [.shield(.block, 1)]),
            AbilityOutcomeBranch(effects: [.shield(.block, 100)], condition: .enemyBurning),
        ],
    )])
    func `nonlethal choices exclude inactive effects and impossible outcomes`(ability: Ability) {
        var battle = finishingBattle(enemyHealth: 100)
        _ = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)
        let preferred = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        for policy in PlayPolicy.allCases {
            #expect(policy.preferredPlayableCard(in: battle)?.id == preferred.id)
        }
    }

    @Test func `guaranteed random lethal avoids a companion lost to thorns`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.cinderbloom],
            companionAbilities: [.blackjack],
            enemyMaxHealth: 3,
            dealOpeningHand: false,
        )
        battle.roster.companion.currentHealth = 1
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.roster.companion.deathsDoorExpiredAtTurn = -1
        battle.insertEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.hand = BattleHand()

        let blackjack = BattleCardCombatEngine.deal(.blackjack, owner: .companion, context: &battle)
        let cinderbloom = BattleCardCombatEngine.deal(.cinderbloom, owner: .hero, context: &battle)

        var unsafeBattle = battle
        _ = try unsafeBattle.playCard(cardID: blackjack.id)
        #expect(unsafeBattle.health(of: unsafeBattle.companion) == 0)
        #expect(!unsafeBattle.isEnemyDefeated)

        let chosen = try #require(PlayPolicy.greedy.preferredPlayableCard(in: battle))
        #expect(chosen.id == cinderbloom.id)
        _ = try battle.playCard(cardID: chosen.id)
        #expect(battle.isEnemyDefeated)
        #expect(battle.health(of: battle.companion) == 1)
    }

    @Test func `Auto Battle does not mistake blocked damage for a finishing hit`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash, .heal], enemyMaxHealth: 3, dealOpeningHand: false,
        )
        battle.roster.hero.currentHealth = 1
        DefensePoolEngine.set(3, on: battle.enemy, in: &battle)
        battle.hand = BattleHand()
        let slash = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        let heal = BattleCardCombatEngine.deal(.heal, owner: .hero, context: &battle)

        let chosen = try #require(PlayPolicy.greedy.preferredPlayableCard(in: battle))
        #expect(chosen.id == heal.id)

        var unsafeBattle = battle
        _ = try unsafeBattle.playCard(cardID: slash.id)
        #expect(!unsafeBattle.isEnemyDefeated)
        #expect(unsafeBattle.health(of: unsafeBattle.hero) == 1)
        _ = try battle.playCard(cardID: chosen.id)
        #expect(battle.health(of: battle.hero) > 1)
    }
}

extension PlayPolicyTests {
    @Test(arguments: [Ability.kindling, .shieldBash, .stab])
    func `Auto Battle recognizes conditional scaled and critical finishing attacks`(ability: Ability) throws {
        var battle = finishingBattle(enemyHealth: ability.id == Ability.shieldBash.id ? 5 : 4)
        if ability.id == Ability.shieldBash.id {
            DefensePoolEngine.set(10, on: battle.hero, in: &battle)
        }
        _ = BattleCardCombatEngine.deal(.heal, owner: .hero, context: &battle)
        let attack = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)
        let before = battle
        let chosen = try #require(PlayPolicy.greedy.preferredPlayableCard(in: battle))
        #expect(chosen.id == attack.id)
        // Choosing must not spend cards, preparations, events, or live RNG.
        #expect(battle.hand == before.hand)
        #expect(battle.roster.hero == before.roster.hero)
        #expect(battle.roster.companion == before.roster.companion)
        #expect(battle.roster.enemy == before.roster.enemy)
        #expect(battle.events == before.events)
        var rng = battle.rng
        var previousRNG = before.rng
        #expect(rng.next() == previousRNG.next())
        _ = try battle.playCard(cardID: chosen.id)
        #expect(battle.isEnemyDefeated)
        #expect(battle.roster[chosen.owner].isAlive)
    }

    @Test(arguments: [false, true])
    func `Auto Battle rejects finishing hits prevented by mitigation or lethal retaliation`(retaliation: Bool) throws {
        var battle = finishingBattle(
            enemyHealth: retaliation ? 2 : 3,
            enemyModifiers: retaliation ? .zero : .init(damageTakenFlat: [.physical: 2]),
        )
        if retaliation {
            battle.roster.hero.hasConsumedDeathsDoor = true
            battle.roster.hero.deathsDoorExpiredAtTurn = -1
            battle.insertEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        }
        let attack = BattleCardCombatEngine.deal(retaliation ? .rayOfFrost : .slash, owner: .hero, context: &battle)
        let heal = BattleCardCombatEngine.deal(.heal, owner: .hero, context: &battle)
        var proof = battle
        _ = try proof.playCard(cardID: attack.id)
        #expect(!proof.isEnemyDefeated)
        if retaliation {
            #expect(proof.health(of: proof.hero) == 0)
        } else {
            #expect(proof.health(of: proof.enemy) == 2)
        }
        let chosen = try #require(PlayPolicy.greedy.preferredPlayableCard(in: battle))
        #expect(chosen.id == heal.id)
        _ = try battle.playCard(cardID: chosen.id)
        #expect(battle.health(of: battle.hero) > 1)
    }

    private func finishingBattle(enemyHealth: Int, enemyModifiers: CombatModifierProfile = .zero) -> BattleState {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: enemyHealth),
            heroModifiers: profile, enemyModifiers: enemyModifiers, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 1
        // Consume the optional opening so the fixture models a ready player turn.
        battle.turnState = .playerTurn
        return battle
    }
}
