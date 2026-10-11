import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct PlayPolicyTests {
    @Test func `prefers lethal card over weaker leftmost card`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [],
            companionAbilities: [],
            enemyMaxHealth: 5,
            dealOpeningHand: false,
        )
        battle.hand = BattleHand()

        battle.nextCardID += 1
        let weak = BattleCard(
            id: battle.nextCardID,
            ability: Ability(
                id: "chip",
                name: "Chip",
                tier: .basic,
                directDamage: 1,
                description: "Chip",
            ),
            owner: .hero,
        )
        battle.hand.append(weak)

        battle.nextCardID += 1
        let lethal = BattleCard(
            id: battle.nextCardID,
            ability: Ability(
                id: "execute",
                name: "Execute",
                tier: .basic,
                directDamage: 5,
                description: "Execute",
            ),
            owner: .hero,
        )
        battle.hand.append(lethal)

        let chosen = PlayPolicy.greedy.preferredPlayableCard(in: battle)
        #expect(chosen?.id == lethal.id)
        #expect(battle.hand.cards.first?.id == weak.id)
    }

    @Test func `setup policy prefers applying missing dot over chip damage`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [],
            companionAbilities: [],
            enemyMaxHealth: 40,
            dealOpeningHand: false,
        )
        battle.hand = BattleHand()

        battle.nextCardID += 1
        let chip = BattleCard(
            id: battle.nextCardID,
            ability: Ability(
                id: "chip",
                name: "Chip",
                tier: .basic,
                directDamage: 2,
                description: "Chip",
            ),
            owner: .hero,
        )
        battle.hand.append(chip)

        battle.nextCardID += 1
        let poison = BattleCard(
            id: battle.nextCardID,
            ability: Ability(
                id: "envenom",
                name: "Envenom",
                tier: .basic,
                directDamage: 0,
                description: "Poison",
                effects: [.poison(4)],
            ),
            owner: .hero,
        )
        battle.hand.append(poison)

        let chosen = PlayPolicy.setupAware.preferredPlayableCard(in: battle)
        #expect(chosen?.id == poison.id)
    }

    @Test(arguments: PlayPolicy.allCases)
    func `guaranteed random lethal avoids a companion lost to thorns`(policy: PlayPolicy) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.cinderbloom],
            companionAbilities: [.blackjack],
            enemyMaxHealth: 3,
            dealOpeningHand: false,
        )
        battle.roster.companion.currentHealth = 1
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.roster.companion.deathsDoorExpiredAtTurn = -1
        battle.appendEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.hand = BattleHand()

        battle.nextCardID += 1
        let blackjack = BattleCard(id: battle.nextCardID, ability: .blackjack, owner: .companion)
        battle.hand.append(blackjack)
        battle.nextCardID += 1
        let cinderbloom = BattleCard(id: battle.nextCardID, ability: .cinderbloom, owner: .hero)
        battle.hand.append(cinderbloom)

        var unsafeBattle = battle
        _ = try unsafeBattle.playCard(cardID: blackjack.id)
        #expect(unsafeBattle.health(of: unsafeBattle.companion) == 0)
        #expect(!unsafeBattle.isEnemyDefeated)

        let chosen = try #require(policy.preferredPlayableCard(in: battle))
        #expect(chosen.id == cinderbloom.id)
        _ = try battle.playCard(cardID: chosen.id)
        #expect(battle.isEnemyDefeated)
        #expect(battle.health(of: battle.companion) == 1)
    }

    @Test(arguments: PlayPolicy.allCases)
    func `Auto Battle does not mistake blocked damage for a finishing hit`(policy: PlayPolicy) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash, .heal], enemyMaxHealth: 3, dealOpeningHand: false,
        )
        battle.roster.hero.currentHealth = 1
        DefensePoolEngine.set(3, on: battle.enemy, in: &battle)
        battle.hand = BattleHand()
        let slash = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        let heal = BattleCardCombatEngine.deal(.heal, owner: .hero, context: &battle)

        let chosen = try #require(policy.preferredPlayableCard(in: battle))
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
    @Test(arguments: PlayPolicy.allCases, [Ability.kindling, .shieldBash, .stab])
    func `Auto Battle recognizes conditional scaled and critical finishing attacks`(policy: PlayPolicy, ability: Ability) throws {
        var battle = finishingBattle(enemyHealth: ability.id == Ability.shieldBash.id ? 5 : 4)
        if ability.id == Ability.shieldBash.id {
            DefensePoolEngine.set(10, on: battle.hero, in: &battle)
        }
        BattleCardCombatEngine.deal(.heal, owner: .hero, context: &battle)
        let attack = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)
        var proof = battle
        _ = try proof.playCard(cardID: attack.id)
        #expect(proof.isEnemyDefeated)

        let before = battle
        let chosen = try #require(policy.preferredPlayableCard(in: battle))
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
    }

    @Test(arguments: PlayPolicy.allCases)
    func `Auto Battle does not mistake mitigated damage for a finishing hit`(policy: PlayPolicy) throws {
        var battle = finishingBattle(enemyHealth: 3, enemyModifiers: .init(damageTakenFlat: [.physical: 2]))
        let attack = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        let heal = BattleCardCombatEngine.deal(.heal, owner: .hero, context: &battle)
        var proof = battle
        _ = try proof.playCard(cardID: attack.id)
        #expect(!proof.isEnemyDefeated)
        #expect(proof.health(of: proof.enemy) == 2)

        let chosen = try #require(policy.preferredPlayableCard(in: battle))
        #expect(chosen.id == heal.id)
        _ = try battle.playCard(cardID: chosen.id)
        #expect(battle.health(of: battle.hero) > 1)
    }

    @Test(arguments: PlayPolicy.allCases)
    func `Auto Battle does not count hits prevented by lethal retaliation`(policy: PlayPolicy) throws {
        var battle = finishingBattle(enemyHealth: 2)
        battle.roster.hero.hasConsumedDeathsDoor = true
        battle.roster.hero.deathsDoorExpiredAtTurn = -1
        battle.appendEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        let attack = BattleCardCombatEngine.deal(.rayOfFrost, owner: .hero, context: &battle)
        let heal = BattleCardCombatEngine.deal(.heal, owner: .hero, context: &battle)
        var proof = battle
        _ = try proof.playCard(cardID: attack.id)
        #expect(proof.health(of: proof.hero) == 0)
        #expect(!proof.isEnemyDefeated)

        let chosen = try #require(policy.preferredPlayableCard(in: battle))
        #expect(chosen.id == heal.id)
        _ = try battle.playCard(cardID: chosen.id)
        #expect(battle.health(of: battle.hero) > 1)
    }

    private func finishingBattle(enemyHealth: Int, enemyModifiers: CombatModifierProfile = .zero) -> BattleState {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: enemyHealth),
            heroModifiers: profile, enemyModifiers: enemyModifiers, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 1
        // Consume the optional opening so the fixture models a ready player turn.
        battle.turnState = .playerTurn
        return battle
    }
}
