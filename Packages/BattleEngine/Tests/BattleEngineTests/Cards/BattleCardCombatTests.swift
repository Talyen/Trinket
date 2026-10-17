import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct BattleCardCombatTests {
    @Test func `play discards card without making it drawable`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash, .heal, .avatarOfJustice],
            companionAbilities: [.bash, .serratedEdge, .bloodthorn],
        )
        battle.hand = BattleHand()
        let card = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        let deckBefore = battle.heroDeck.count

        _ = try battle.playCard(cardID: card.id)

        try #expect(battle.hand.card(id: card.id) == nil)
        try #expect(battle.heroDeck.count == deckBefore)
        try #expect(battle.heroDeck.discarded.last?.ability.id == Ability.slash.id)
    }

    @Test(arguments: [1, 2, 3])
    func `dark pact requires health even at deaths door`(health: Int) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroAbilities: [.darkPact, .slash, .heal])
        battle.roster.mutateRuntime(for: battle.hero) {
            $0.currentHealth = health
            $0.hasConsumedDeathsDoor = true
            $0.deathsDoorExpiredAtTurn = battle.turnCount
        }
        battle.hand = BattleHand()
        let card = BattleCard(id: 900, ability: .darkPact, owner: .hero)
        battle.hand.append(card)
        #expect(battle.isCardPlayable(card) == (health > 1))
        if health > 1 {
            _ = try battle.playCard(cardID: card.id)
            #expect(battle.health(of: battle.hero) == health - 1)
        } else {
            #expect(throws: BattlePlayError.insufficientHealth) { try battle.playCard(cardID: card.id) }
            #expect(battle.hand.card(id: card.id) != nil)
            #expect(battle.health(of: battle.hero) == health)
            let events = battle.performTestAction(.darkPact)
            #expect(events.isEmpty)
        }
    }

    @Test func `dark pact draws two cards and health cost ignores block`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.darkPact, .slash, .heal, .smite],
            companionAbilities: [.bash, .serratedEdge, .bloodthorn],
            enemyMaxHealth: 500,
        )
        battle.heroDeck.putOnBottom(.heal)
        battle.heroDeck.putOnBottom(.smite)
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTurns: 6)],
            for: battle.roster.hero.combatant,
        )

        battle.hand = BattleHand()
        _ = BattleCardCombatEngine.deal(.darkPact, owner: .hero, context: &battle)
        _ = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        _ = BattleCardCombatEngine.deal(.bash, owner: .companion, context: &battle)

        let events = try BattleTestFixtures.playCardNamed("Dark Pact", owner: .hero, on: &battle)

        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.hand.bufferCount == 1)
        try #expect(events.contains { $0.effectKind == .cardsDrawn && $0.amount == 2 })
        try #expect(battle.health(of: battle.hero) == 19)
        let shield = battle.activeEffects(of: battle.hero).first { $0.effect.kind == .shield }
        guard case let .shield(_, buffer) = shield?.effect else {
            Issue.record("Block should survive Dark Pact's Health cost")
            return
        }
        try #expect(buffer == 20)
    }

    @Test func `end turn at full hand draws into buffer`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash, .heal, .avatarOfJustice],
            companionAbilities: [.bash, .serratedEdge, .bloodthorn],
            enemyAbilities: [],
            enemyMaxHealth: 500,
        )
        while battle.hand.count < BattleHand.maxSize {
            let owner: BattleParticipant = battle.hand.count.isMultiple(of: 2) ? .hero : .companion
            _ = BattleCardCombatEngine.deal(.slash, owner: owner, context: &battle)
        }
        battle.heroDeck.putOnBottom(.slash)
        battle.companionDeck.putOnBottom(.bash)
        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.hand.buffer.isEmpty)

        let countAtCap = battle.hand.count
        _ = battle.endTurn()
        try #expect(battle.hand.count == countAtCap)
        try #expect(battle.hand.bufferCount == 3)
    }

    @Test func `playing card promotes oldest buffered card FIFO`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash, .heal, .avatarOfJustice],
            companionAbilities: [.bash, .serratedEdge, .bloodthorn],
            enemyMaxHealth: 500,
        )
        battle.hand = BattleHand()
        battle.nextCardID += 1
        let firstBuffered = BattleCard(id: battle.nextCardID, ability: .fangs, owner: .companion)
        battle.nextCardID += 1
        let secondBuffered = BattleCard(id: battle.nextCardID, ability: .bloodthorn, owner: .companion)
        _ = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        _ = BattleCardCombatEngine.deal(.heal, owner: .hero, context: &battle)
        _ = BattleCardCombatEngine.deal(.smite, owner: .hero, context: &battle)
        battle.hand.append(firstBuffered)
        battle.hand.append(secondBuffered)

        let played = try #require(battle.hand.cards.first { $0.ability.id == Ability.slash.id })
        _ = try battle.playCard(cardID: played.id)

        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.hand.cards.contains { $0.id == firstBuffered.id })
        try #expect(battle.hand.bufferCount == 1)
        try #expect(battle.hand.buffer.first?.ability.id == Ability.bloodthorn.id)
    }

    @Test func `public card play rejects buffered card`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash],
            companionAbilities: [.bash],
            enemyMaxHealth: 500,
        )
        let visible = BattleCard(id: 1, ability: .slash, owner: .hero)
        let buffered = BattleCard(id: 2, ability: .smite, owner: .hero)
        battle.hand = BattleHand(cards: [visible], buffer: [buffered])

        do {
            _ = try battle.playCard(cardID: buffered.id)
            Issue.record("Expected buffered card to remain hidden from public play")
        } catch BattlePlayError.cardNotInHand {}

        try #expect(battle.hand.buffer == [buffered])
        try #expect(battle.hand.cards == [visible])
    }

    @Test func `turn draw continues alternating owner sequence`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash, .heal, .avatarOfJustice],
            companionAbilities: [.bash, .serratedEdge, .bloodthorn],
            enemyMaxHealth: 500,
        )
        battle.hand = BattleHand()
        _ = battle.endTurn()

        try #expect(battle.hand.count == 3)
        try #expect(battle.hand.buffer.isEmpty)
        try #expect(battle.hand.cards.map(\.owner) == [.companion, .hero, .companion])
    }

    @Test func `turn draw schedules three cards for sole survivor`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash, .heal, .avatarOfJustice],
            companionAbilities: [.bash, .serratedEdge, .bloodthorn],
            enemyMaxHealth: 500,
        )
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 0 }
        battle.hand = BattleHand()
        battle.heroDeck = CombatDeck(abilities: [.slash, .heal, .smite])
        _ = battle.endTurn()

        try #expect(battle.hand.count == 3)
        try #expect(battle.hand.cards.allSatisfy { $0.owner == .hero })
    }

    @Test func `end of round advances effects once`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [],
            companionAbilities: [],
            enemyAbilities: [],
        )
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
            for: battle.enemy,
        )
        let before = battle.health(of: battle.enemy)
        let events = battle.endTurn().events

        try #expect(battle.turnCount == 1)
        try #expect(events.count(where: { $0.kind == .status && $0.keyword == .burn }) == 1)
        try #expect(battle.health(of: battle.enemy) < before)
    }

    @Test func `dead owner cards are unplayable`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroAbilities: [.slash], companionAbilities: [.bash])
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 0 }
        let heroCard = try #require(battle.hand.cards.first { $0.owner == .hero })
        try #expect(!battle.isCardPlayable(heroCard))

        do {
            _ = try battle.playCard(cardID: heroCard.id)
            Issue.record("Expected ownerDefeated")
        } catch BattlePlayError.ownerDefeated {}

        let companionCard = try #require(battle.hand.cards.first { $0.owner == .companion })
        try #expect(battle.isCardPlayable(companionCard))
    }
}

extension BattleCardCombatTests {
    @Test func `enemy resumes basic attacks after an unaffordable health cost skill`() {
        let enemy = Combatant(
            id: "health-cost-enemy", name: "Health Cost Enemy", role: .enemy, maxHealth: 14,
            abilities: [.rendingSlash, .bloodOffering, .hemorrhage],
        )
        var context = BattleStateTestFactory.makeBattle(enemy: enemy)
        context.roster.mutateRuntime(for: enemy) { $0.currentHealth = 1 }

        for _ in 0 ..< 2 {
            let events = context.recordingEvents { observation in await BattleCardCombatEngine.resolveEnemyTurn(context: &observation) }
            #expect(events.contains { $0.kind == .ability && $0.abilityTier == .basic })
        }
        let skippedEvents = context.recordingEvents { observation in await BattleCardCombatEngine.resolveEnemyTurn(context: &observation) }

        #expect(skippedEvents.isEmpty)
        #expect(context.roster.enemy.currentHealth == 1)
        #expect(context.roster.enemy.actionCount == 3)

        let resumedEvents = context.recordingEvents { observation in await BattleCardCombatEngine.resolveEnemyTurn(context: &observation) }

        #expect(resumedEvents.contains { $0.kind == .ability && $0.abilityID == Ability.rendingSlash.id })
        #expect(context.roster.enemy.actionCount == 4)
    }

    @Test(arguments: [false, true])
    func `turn start lethal damage ends the battle`(opening: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.everyNTurnsStunBuildupInterval = 1
        profile.triggers.everyNTurnsStunBuildupAmount = 100
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1),
            heroModifiers: profile,
        )
        battle.turnCount = opening ? 1 : 0
        battle.turnState = opening ? .opening([]) : .playerTurn
        _ = opening ? battle.drawOpeningHand() : battle.endTurn()
        #expect(battle.isBattleOver)
        #expect(battle.phase == .ended)
    }

    @Test(arguments: [false, true])
    func `turn start cleanse restores the cleansed owners card play`(opening: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.autoCleanseTeamPerTurn = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            heroEffects: [ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0)],
            companionModifiers: profile,
        )
        battle.turnState = opening ? .opening([]) : .playerTurn
        _ = opening ? battle.drawOpeningHand() : battle.endTurn()
        let card = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        #expect(!battle.roster.hasPendingActionSkip(for: battle.hero))
        #expect(BattleCardCombatEngine.isCardPlayable(card, in: battle))
    }
}

extension BattleCardCombatTests {
    @Test(arguments: [false, true])
    func `recorded automatic draws preserve nested play and overflow rules`(nested: Bool) throws {
        let fixture = automaticDrawFixture(nested: nested)
        var recorded = fixture.state
        let initiating = fixture.card
        var immediate = recorded
        let startingEventID = recorded.nextEventID
        let result = try recorded.playCard(cardID: initiating.id, recordActions: true)
        let immediateEvents = try immediate.playCard(cardID: initiating.id).events
        let playedIDs = result.playedCards.map(\.id)
        #expect(result.events == immediateEvents)
        #expect(result.events == recorded.events.filter { $0.id > startingEventID })
        #expect(playedIDs.count == (nested ? 3 : 2))
        #expect(playedIDs.first == initiating.id)
        assertResolvedAttacks(result.actions, playedIDs: playedIDs, events: result.events)
        #expect(recorded.commandOutput == nil)
        #expect(recorded.hand == immediate.hand)
        #expect(recorded.heroDeck == immediate.heroDeck)
        #expect(recorded.companionDeck == immediate.companionDeck)
        #expect(recorded.phase == immediate.phase)
        for owner in BattleParticipant.allCases {
            #expect(recorded.roster[owner] == immediate.roster[owner])
        }
        #expect(recorded.rng.next() == immediate.rng.next())
    }

    private func automaticDrawFixture(nested: Bool) -> (state: BattleState, card: BattleCard) {
        var recorded = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1000),
            dealOpeningHand: false,
        )
        let opening = automaticDraw(target: .companion)
        let partner = automaticDraw(target: .hero)
        let initiating = BattleCardCombatEngine.deal(opening, owner: .hero, context: &recorded)
        _ = BattleCardCombatEngine.deal(.block, owner: .hero, context: &recorded)
        _ = BattleCardCombatEngine.deal(.block, owner: .companion, context: &recorded)
        if nested {
            _ = BattleCardCombatEngine.deal(.block, owner: .hero, context: &recorded)
        }
        recorded.heroDeck = CombatDeck(abilities: [.slash, .block])
        recorded.companionDeck = CombatDeck(abilities: [nested ? partner : .bash, .block])
        return (recorded, initiating)
    }

    private func automaticDraw(target: EffectTarget) -> Ability {
        Ability(
            id: "automatic-\(target)", name: "Automatic Draw", tier: .ultimate,
            directDamage: 3, targetedEffects: [TargetedEffect(.drawAndPlayCards(1), target: target)],
        )
    }

    private func assertResolvedAttacks(_ actions: [BattleResolvedAction], playedIDs: [Int], events: [ActionEvent]) {
        #expect(Set(events.map(\.id)).count == events.count)
        #expect(Set(playedIDs).count == playedIDs.count)
        #expect(Set(actions.compactMap(\.cardID)) == Set(playedIDs))
        #expect(Set(actions.map(\.id)).count == actions.count)
        let memberIDs = actions.flatMap(\.eventIDs)
        #expect(Set(memberIDs).count == memberIDs.count)
        #expect(Set(memberIDs).isSubset(of: Set(events.map(\.id))))
        let allAttacks = actions.allSatisfy(\.isAttack)
        #expect(allAttacks)
        for action in actions {
            let damage = events.filter { action.eventIDs.contains($0.id) && $0.kind == .abilityDamage }
            #expect(!damage.isEmpty)
            #expect(damage.allSatisfy { $0.actorID == action.actorID && $0.abilityID == action.abilityID })
        }
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `pack tactics hits first then draws one manual ally card`(owner: BattleParticipant) throws {
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1000), dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.block])
        battle.companionDeck = CombatDeck(abilities: [.block])
        let card = BattleCardCombatEngine.deal(.packTactics, owner: owner, context: &battle)
        let events = try battle.playCard(cardID: card.id).events
        let hit = try #require(events.firstIndex { $0.kind == .abilityDamage && $0.abilityID == Ability.packTactics.id })
        #expect(events[hit].amount == 5)
        let draw = try #require(events.firstIndex { $0.effectKind == .cardsDrawn })
        #expect(hit < draw)
        #expect(!events.contains { $0.kind == .ability && $0.abilityID == Ability.block.id })
        let ally: BattleParticipant = owner == .hero ? .companion : .hero
        #expect(battle.hand.cards.first?.owner == ally)
        #expect(battle.hand.cards.first?.ability.id == Ability.block.id)
    }

    @Test func `pack tactics draws one manual card from survivor deck`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        battle.roster.companion.currentHealth = 0
        battle.heroDeck = CombatDeck(abilities: [.block, .block])
        battle.companionDeck = CombatDeck(abilities: [.slash])
        let card = BattleCardCombatEngine.deal(.packTactics, owner: .hero, context: &battle)
        let events = try battle
            .recordingEvents { context in _ = try await BattleCardCombatEngine.resolveDrawnCard(card, context: &context) }
        #expect(!events.contains { $0.kind == .ability && $0.abilityID == Ability.block.id })
        #expect(battle.hand.cards.map(\.ability.id) == [Ability.block.id])
        #expect(battle.hand.cards.first?.owner == .hero)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 0)
    }

    @Test func `opening hand uses shuffled tiers and one copy per loadout ability`() {
        var observedTiers: Set<AbilityTier> = []
        for seed: UInt64 in 0 ..< 12 {
            let battle = BattleStateTestFactory.makeBattleWithAbilities(
                heroAbilities: [.maul, .smite, .hemorrhage],
                companionAbilities: [.bash, .serratedEdge, .bloodthorn],
                rngSeed: seed,
            )
            #expect(battle.hand.count == 3)
            #expect(battle.hand.buffer.isEmpty)
            #expect(battle.hand.cards.map(\.owner) == [.hero, .companion, .hero])
            observedTiers.formUnion(battle.hand.cards.map(\.ability.tier))
            let heroCards = battle.heroDeck.abilities + battle.hand.cards.filter { $0.owner == .hero }.map(\.ability)
            let companionCards = battle.companionDeck.abilities + battle.hand.cards.filter { $0.owner == .companion }.map(\.ability)
            #expect(Set(heroCards.map(\.id)) == Set([Ability.maul.id, Ability.smite.id, Ability.hemorrhage.id]))
            #expect(heroCards.count == 3)
            #expect(companionCards.count == 3)
            if observedTiers == [.basic, .skill, .ultimate] {
                break
            }
        }
        #expect(observedTiers == [.basic, .skill, .ultimate])
    }

    @Test func `opening settlement cannot grant Block twice or return after a custom hand command`() throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.blockPerTurn = 3
        var battle = BattleStateTestFactory.makeBattle(heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false)
        battle.drawOpeningHand()
        let settled = battle.roster.hero
        let eventCount = battle.events.count
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 3)
        #expect(battle.drawOpeningHand().events.isEmpty)
        #expect(battle.roster.hero == settled)
        #expect(battle.events.count == eventCount)

        var custom = BattleStateTestFactory.makeBattle(heroModifiers: profile, dealOpeningHand: false)
        let card = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &custom)
        try custom.playCard(cardID: card.id)
        #expect(custom.drawOpeningHand().events.isEmpty)
        #expect(BattleTestFixtures.shieldPoints(for: custom.hero, in: custom) == 0)
    }

    @Test func `End Turn settles the round and Mana before returning playable cards`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash], enemyMaxHealth: 1000, heroMaxMana: 10, heroMana: 0,
        )
        let card = try #require(battle.hand.cards.first)
        battle.endTurn()
        #expect(battle.turnCount == 1)
        #expect(battle.roster.hero.currentMana == 1)
        #expect(battle.isCardPlayable(card))
        #expect(battle.drawOpeningHand().events.isEmpty)
        #expect(battle.roster.hero.currentMana == 1)
    }
}
