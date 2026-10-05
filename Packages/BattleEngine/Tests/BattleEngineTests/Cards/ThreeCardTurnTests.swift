import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ThreeCardTurnTests {
    private func battle(triggers: CombatTraitTriggers = .init(), seed: UInt64 = 42) -> BattleState {
        var profile = CombatModifierProfile.zero
        profile.triggers = triggers
        var state = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 100, companionMaxHealth: 100, enemyMaxHealth: 1000,
            heroMaxMana: 12, heroMana: 0, heroModifiers: profile, rngSeed: seed,
            dealOpeningHand: false,
        )
        state.appliesFightPacing = false
        return state
    }

    private func attack(_ damage: Int = 2) -> Ability {
        Ability(
            id: "test-strike",
            name: "Test Strike",
            tier: .basic,
            directDamage: damage,
            criticalChanceBonus: -1,
        )
    }

    @Test func `draw effects never advance scheduled owner and exhausted piles never refill mid turn`() throws {
        var state = battle()
        state.heroDeck = CombatDeck(abilities: [.block, .heal, .avatarOfJustice])
        state.companionDeck = CombatDeck(abilities: [.bash, .serratedEdge, .bloodthorn])
        _ = CombatExecutor.run { await BattleCardCombatEngine.drawOpeningHand(context: &state) }
        #expect(state.hand.cards.map(\.owner) == [.hero, .companion, .hero])
        let held = state.hand.cards
        for card in held {
            _ = try state.playCard(cardID: card.id)
        }
        #expect(state.heroDeck.discarded.map(\.ability.id) == [Ability.block.id, Ability.heal.id])
        let additional = try #require(BattleCardCombatEngine.drawOne(for: .hero, context: &state))
        _ = try state.playCard(cardID: additional.id)
        #expect(BattleCardCombatEngine.drawOne(for: .hero, context: &state) == nil)
        #expect(state.heroDeck.discarded.count == 3)
        _ = state.endTurn()
        #expect(state.hand.cards.map(\.owner) == [.companion, .hero, .companion])
        #expect(state.hand.cards[1].ability.id == Ability.block.id)
        #expect(state.hand.cards[1].deckCopyID == held[0].deckCopyID)
    }

    @Test func `blocked scheduled draws do not borrow and arrivals retain fifo`() {
        var state = battle()
        state.heroDeck = CombatDeck(abilities: [.slash, .heal, .avatarOfJustice])
        state.companionDeck = CombatDeck(abilities: [.bash, .serratedEdge, .bloodthorn])
        state.appendEffect(
            .controlMeter(.stun, 10, 5),
            to: state.hero,
            sourceID: state.enemy.id,
            remainingTurns: 0,
        )
        _ = CombatExecutor.run { await BattleCardCombatEngine.drawOpeningHand(context: &state) }
        #expect(state.hand.cards.map(\.owner) == [.companion])
        #expect(state.companionDeck.count == 2)
        #expect(state.heroDeck.count == 3)
        let hero = BattleCardCombatEngine.deal(.block, owner: .hero, context: &state)
        _ = BattleCardCombatEngine.deal(.bash, owner: .companion, context: &state)
        _ = BattleCardCombatEngine.deal(.heal, owner: .hero, context: &state)
        _ = state.hand.remove(id: hero.id)
        _ = BattleCardCombatEngine.promoteNextFromBuffer(context: &state)
        #expect(state.hand.cards.map(\.owner) == [.companion, .companion, .hero])
    }

    @Test func `Gale moves the played copy despite an identical held ability and cannot return repeatedly`() throws {
        var state = battle(triggers: CombatTraitTriggers(attack: AttackTriggers(thirdCardReturnsToHand: true)))
        let played = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &state)
        _ = try state.playCard(cardID: played.id)
        let duplicate = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &state)
        state.appendEffect(.evadeNextHit, to: state.hero, sourceID: state.hero.id, remainingTurns: 0)
        _ = BattleTurnEngine.performAction(ability: attack(), actor: state.enemy, abilityTarget: state.hero, context: &state)
        let recovered = try #require(state.hand.cards.first { $0.deckCopyID == played.deckCopyID })
        #expect(recovered.deckCopyID != duplicate.deckCopyID)
        _ = try state.playCard(cardID: recovered.id)
        state.appendEffect(.evadeNextHit, to: state.hero, sourceID: state.hero.id, remainingTurns: 0)
        _ = BattleTurnEngine.performAction(ability: attack(), actor: state.enemy, abilityTarget: state.hero, context: &state)
        #expect(!state.hand.cards.contains { $0.deckCopyID == played.deckCopyID })
        #expect(state.heroDeck.discarded.count == 1)
        #expect(state.hand.cards.contains { $0.deckCopyID == duplicate.deckCopyID })
    }

    @Test(arguments: [false, true])
    func `Cold Snap draws for existing or newly applied Frozen`(alreadyFrozen: Bool) {
        var state = battle()
        state.heroDeck = CombatDeck(abilities: [.block])
        let threshold = ControlMeterEngine.threshold(for: state.enemy, in: state)
        state.appendEffect(
            .controlMeter(.freeze, alreadyFrozen ? threshold : threshold - 1, threshold),
            to: state.enemy,
            sourceID: state.hero.id,
            remainingTurns: alreadyFrozen ? 1 : 0,
        )
        _ = BattleTurnEngine.performAction(ability: .coldSnap, actor: state.hero, abilityTarget: state.enemy, context: &state)
        #expect(state.hand.cards.map(\.ability.id) == [Ability.block.id])
    }

    @Test func `Cold Snap without Frozen does not draw and Blood Offering pays changed cost`() throws {
        var state = battle()
        state.heroDeck = CombatDeck(abilities: [.block])
        _ = BattleTurnEngine.performAction(ability: .coldSnap, actor: state.hero, abilityTarget: state.enemy, context: &state)
        #expect(state.hand.isEmpty)
        let card = BattleCardCombatEngine.deal(.bloodOffering, owner: .hero, context: &state)
        let health = state.health(of: state.hero)
        _ = try state.playCard(cardID: card.id)
        #expect(state.health(of: state.hero) == health - 2)
        #expect(state.hand.cards.map(\.ability.id) == [Ability.block.id])
    }

    @Test(arguments: [BattleParticipant.hero, .companion], [0, 1])
    func `Clear Mind draws once for a real multi effect Cleanse at zero Mana`(target: BattleParticipant, mana: Int) {
        var state = battle(triggers: CombatTraitTriggers(cleanse: CleanseTriggers(clearMind: true)))
        state.roster.hero.currentMana = mana
        state.heroDeck = CombatDeck(abilities: [.block, .heal])
        let recipient = state.roster[target].combatant
        state.appendEffect(.burn(1), to: recipient, sourceID: state.enemy.id, remainingTurns: 1)
        state.appendEffect(.poison(1), to: recipient, sourceID: state.enemy.id, remainingTurns: 1)
        _ = CombatExecutor.run { await EffectRemovalOperation.resolveCleanse(
            .all(nil),
            source: state.hero,
            target: recipient,
            abilityName: "Test Cleanse",
            in: &state,
        ) }
        #expect(state.hand.totalCount == (mana == 0 ? 1 : 0))
        _ = CombatExecutor.run { await EffectRemovalOperation.resolveCleanse(
            .all(nil),
            source: state.hero,
            target: recipient,
            abilityName: "Empty Cleanse",
            in: &state,
        ) }
        #expect(state.hand.totalCount == (mana == 0 ? 1 : 0))
        #expect(state.roster.hero.talents.pending.nextManaEmpowerDiscount == 0)
    }

    @Test(arguments: [49, 50])
    func `Smite the Wicked draws once on successful Purge strictly below half Health`(health: Int) {
        var state = battle(triggers: CombatTraitTriggers(cleanse: CleanseTriggers(purgeDrawBelowHalf: true)))
        state.roster.hero.currentHealth = health
        state.heroDeck = CombatDeck(abilities: [.block, .heal])
        state.appendEffect(.shield(.block, 3), to: state.enemy, sourceID: state.enemy.id, remainingTurns: 0)
        state.appendEffect(.thorns(3), to: state.enemy, sourceID: state.enemy.id, remainingTurns: 0)
        _ = CombatExecutor.run { await EffectRemovalOperation.resolvePurge(
            .all(nil),
            source: state.hero,
            target: state.enemy,
            abilityName: "Test Purge",
            in: &state,
        ) }
        #expect(state.hand.totalCount == (health < 50 ? 1 : 0))
        _ = CombatExecutor.run { await EffectRemovalOperation.resolvePurge(
            .all(nil),
            source: state.hero,
            target: state.enemy,
            abilityName: "Empty Purge",
            in: &state,
        ) }
        #expect(state.hand.totalCount == (health < 50 ? 1 : 0))
        #expect(!state.roster.hero.talents.pending.doubleNextHolyAttack)
    }

    @Test(arguments: [49, 50, 51])
    func `Resourceful reads Health after the enemy hit breaks Block`(health: Int) {
        var state = battle(triggers: CombatTraitTriggers(block: BlockTriggers(blockBreakDrawBelowHalf: true)))
        state.roster.hero.currentHealth = health
        state.heroDeck = CombatDeck(abilities: [.block, .heal])
        state.appendEffect(.shield(.block, 1), to: state.hero, sourceID: state.hero.id, remainingTurns: 0)
        _ = BattleTurnEngine.performAction(ability: attack(2), actor: state.enemy, abilityTarget: state.hero, context: &state)
        #expect(state.health(of: state.hero) == health - 1)
        #expect(state.hand.totalCount == (health <= 50 ? 1 : 0))
    }

    @Test func `Consolation Prize is seeded once per combat and its generated copy cycles`() throws {
        let triggers = CombatTraitTriggers(gold: GoldTriggers(blockedAttackFirstRandomCard: true))
        var state = battle(triggers: triggers)
        var peer = battle(triggers: triggers)
        func trigger(_ context: inout BattleState) throws {
            context.appendEffect(
                .shield(.block, 100),
                to: context.enemy,
                sourceID: context.enemy.id,
                remainingTurns: 0,
            )
            let card = BattleCardCombatEngine.deal(attack(), owner: .hero, context: &context)
            _ = try context.playCard(cardID: card.id)
        }
        try trigger(&state)
        try trigger(&peer)
        let generated = try #require(state.hand.cards.first)
        #expect(generated.ability.id == peer.hand.cards.first?.ability.id)
        #expect(AbilityCatalog.all.contains { $0.id == generated.ability.id })
        #expect(generated.owner == .hero)
        let loadout = state.hero.abilityLoadout
        let before = state.hand.totalCount
        let another = BattleCardCombatEngine.deal(attack(), owner: .hero, context: &state)
        _ = try state.playCard(cardID: another.id)
        #expect(state.hand.totalCount == before)
        _ = try state.playCard(cardID: generated.id)
        #expect(state.heroDeck.discarded.contains { $0.copyID == generated.deckCopyID })
        #expect(state.hero.abilityLoadout == loadout)
        state.heroDeck.recycleDiscards()
        #expect(state.heroDeck.abilities.contains { $0.id == generated.ability.id })
    }

    @Test func `guaranteed theft draws with both return Uniques still exhaust finite cards`() throws {
        let triggers = CombatTraitTriggers(
            attack: AttackTriggers(thirdCardReturnsToHand: true, recoverLastAttackCardEachTurn: true),
            gold: GoldTriggers(goldTheftDrawChancePercent: 1),
        )
        var state = battle(triggers: triggers)
        state.heroDeck = CombatDeck(abilities: [.steal, .steal, .steal])
        _ = BattleCardCombatEngine.drawOne(for: .hero, context: &state)
        var plays = 0
        while let card = state.hand.cards.first {
            _ = try state.playCard(cardID: card.id)
            plays += 1
            try #require(plays <= 5)
            state.appendEffect(.evadeNextHit, to: state.hero, sourceID: state.hero.id, remainingTurns: 0)
            _ = BattleTurnEngine.performAction(ability: attack(), actor: state.enemy, abilityTarget: state.hero, context: &state)
        }
        #expect(plays == 5)
        #expect(state.heroDeck.isEmpty)
        #expect(state.heroDeck.discarded.count == 3)
        #expect(Set(state.heroDeck.discarded.compactMap(\.copyID)).count == 3)
    }

    @Test func `Resourceful has no turn allowance and ignores voluntary and self damage breaks`() {
        var state = battle(triggers: CombatTraitTriggers(block: BlockTriggers(blockBreakDrawBelowHalf: true)))
        state.roster.hero.currentHealth = 40
        state.heroDeck = CombatDeck(abilities: [.block, .heal, .slash])
        for _ in 0 ..< 2 {
            state.appendEffect(.shield(.block, 1), to: state.hero, sourceID: state.hero.id, remainingTurns: 0)
            _ = BattleTurnEngine.performAction(ability: attack(2), actor: state.enemy, abilityTarget: state.hero, context: &state)
        }
        #expect(state.hand.totalCount == 2)
        state.appendEffect(.shield(.block, 1), to: state.hero, sourceID: state.hero.id, remainingTurns: 0)
        _ = BattleTurnEngine.performAction(ability: attack(2), actor: state.hero, abilityTarget: state.hero, context: &state)
        #expect(state.hand.totalCount == 2)
        DefensePoolEngine.set(0, on: state.hero, in: &state)
        #expect(state.hand.totalCount == 2)
    }

    @Test(arguments: [0.0, 1.0])
    func `theft draw rolls once per successful ability without a turn limit`(chance: Double) {
        var state = battle(triggers: CombatTraitTriggers(gold: GoldTriggers(goldTheftDrawChancePercent: chance)))
        state.heroDeck = CombatDeck(abilities: [.block, .heal, .slash])
        let theft = Ability(
            id: "double-theft", name: "Double Theft", tier: .skill,
            effects: [.resourceGain(.gold, 1), .resourceGain(.gold, 1)], stealsGold: true,
        )
        for _ in 0 ..< 2 {
            _ = BattleTurnEngine.performAction(ability: theft, actor: state.hero, abilityTarget: state.enemy, context: &state)
        }
        #expect(state.hand.totalCount == (chance == 1 ? 2 : 0))
        _ = state.grantGoldEvent(1, to: state.hero, abilityName: "Ordinary Gold")
        _ = state.grantGoldEvent(0, to: state.hero, abilityName: "Empty Theft", isTheft: true)
        #expect(state.hand.totalCount == (chance == 1 ? 2 : 0))
    }

    @Test func `winning cards finish draw rewards but drawn cards cannot act after victory`() throws {
        var state = battle()
        state.heroDeck = CombatDeck(abilities: [.block])
        let winning = Ability(
            id: "winning-draw", name: "Winning Draw", tier: .ultimate,
            directDamage: 2000,
            targetedEffects: [TargetedEffect(.drawCards(1), target: .actor)],
            criticalChanceBonus: -1,
        )
        let card = BattleCardCombatEngine.deal(winning, owner: .hero, context: &state)
        _ = try state.playCard(cardID: card.id)
        #expect(state.isEnemyDefeated)
        let reward = try #require(state.hand.cards.first { $0.ability.id == Ability.block.id })
        #expect(throws: BattlePlayError.battleOver) { try state.playCard(cardID: reward.id) }
    }
}
