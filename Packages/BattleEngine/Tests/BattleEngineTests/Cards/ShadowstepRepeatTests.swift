import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct ShadowstepRepeatTests {
    @Test(arguments: [Keyword.physical, .burn])
    func `repeat pays setup once and repeats effects without spending two cards`(keyword: Keyword) throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.cardsPlayedHealPartyThreshold = 2
        profile.triggers.cardsPlayedHealPartyAmount = 4
        var battle = makeBattle(profile: profile)
        battle.roster.hero.currentHealth = 10
        battle.heroDeck = CombatDeck(abilities: [.block, .apple])
        battle.appendEffect(.shield(.block, 6), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        battle.appendEffect(.nextStrikeDouble, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        readyRepeat(on: battle.hero, in: &battle)
        let ability = Ability(
            id: "repeat-costs", name: "Repeat Costs", tier: .skill,
            damageComponents: [DamageComponent(1, target: .actor), DamageComponent(2, keyword: keyword)],
            targetedEffects: [TargetedEffect(.drawCards(1)), TargetedEffect(.resourceGain(.gold, 2))],
            criticalChanceBonus: -1, blockCost: 2,
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)
        let actionsBefore = battle.actionCount
        var resolvedCards: [Int?] = []
        var recordedEnemyHealth: [Int] = []

        let events = try battle.playCard(cardID: card.id) { checkpoint, state, _ in
            if case let .actionResolved(action) = checkpoint, action.abilityID == ability.id {
                resolvedCards.append(action.cardID)
                recordedEnemyHealth.append(state.roster.enemy.currentHealth)
            }
        }

        #expect(events.count(where: { $0.kind == .ability && $0.abilityID == ability.id }) == 2)
        #expect(events.filter { $0.kind == .abilityDamage && $0.targetID == battle.enemy.id }.map(\.amount)
            == (keyword == .burn ? [6, 3] : [4, 2]))
        #expect(battle.roster.hero.currentHealth == 8)
        #expect(battle.mana(of: battle.hero) == (keyword == .burn ? 3 : 6))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 4)
        #expect(events.filter { $0.effectKind == .resourceGain && $0.keyword == .gold }.map(\.amount) == [2, 2])
        #expect(battle.hand.cards.map(\.ability.id) == [Ability.block.id, Ability.apple.id])
        #expect(battle.heroDeck.discarded.map(\.copyID) == [card.deckCopyID])
        #expect(battle.turnCadence.cardsPlayed[.hero] == 1)
        #expect(battle.actionCount == actionsBefore + 1)
        #expect(!events.contains { $0.effectKind == .instantHeal })
        #expect(resolvedCards == [card.id, nil])
        #expect(recordedEnemyHealth == (keyword == .burn ? [94, 91] : [96, 94]))
    }

    @Test func `partner cards automatic plays and echoes preserve the caster's repeat`() throws {
        var battle = makeBattle()
        readyRepeat(on: battle.hero, in: &battle)
        let partner = BattleCardCombatEngine.deal(attack(), owner: .companion, context: &battle)
        let partnerEvents = try battle.playCard(cardID: partner.id)
        #expect(partnerEvents.count(where: { $0.kind == .ability && $0.abilityID == attack().id }) == 1)
        battle.heroDeck = CombatDeck(abilities: [attack()])
        let automatic = EffectHandlersTestSupport.dispatch(
            .drawAndPlayCards(1), source: battle.hero, target: battle.hero, battle: &battle,
        )
        #expect(automatic.events.count(where: { $0.kind == .ability && $0.abilityID == attack().id }) == 1)
        let echo = BattleTurnEngine.performAction(
            ability: attack(), actor: battle.hero, abilityTarget: battle.enemy, origin: .cardRepeat, context: &battle,
        )
        #expect(echo.count(where: { $0.kind == .ability && $0.abilityID == attack().id }) == 1)
        #expect(hasRepeat(on: battle.hero, in: battle))
        battle.heroDeck = CombatDeck(abilities: [.block, .apple])
        let feint = BattleCardCombatEngine.deal(AbilityCatalog.feint, owner: .hero, context: &battle)

        let events = try battle.playCard(cardID: feint.id)

        #expect(events.filter { $0.effectKind == .cardsDrawn }.map(\.amount) == [1, 1])
        #expect(battle.hand.cards.map(\.ability.id) == [Ability.block.id, Ability.apple.id])
        #expect(!hasRepeat(on: battle.hero, in: battle))
    }

    @Test func `refreshes do not stack and repeated Shadowstep readies a later card`() throws {
        var battle = makeBattle()
        for _ in 0 ..< 2 {
            _ = EffectHandlersTestSupport.dispatch(
                .playNextCardTwice, ability: .shadowstep, source: battle.hero, target: battle.hero, battle: &battle,
            )
        }
        let shadowstep = BattleCardCombatEngine.deal(.shadowstep, owner: .hero, context: &battle)
        let preparation = try battle.playCard(cardID: shadowstep.id)
        #expect(preparation.count(where: { $0.effectKind == .playNextCardTwiceApplied }) == 2)
        #expect(battle.activeEffects(of: battle.hero).count(where: { $0.effect == .playNextCardTwice }) == 1)
        for expectedCount in [2, 1] {
            let card = BattleCardCombatEngine.deal(attack(), owner: .hero, context: &battle)
            let events = try battle.playCard(cardID: card.id)
            #expect(events.count(where: { $0.kind == .ability && $0.abilityID == attack().id }) == expectedCount)
            #expect(!hasRepeat(on: battle.hero, in: battle))
        }
    }

    @Test func `an empowered Skill echo cannot spend a freshly readied repeat`() throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.empoweredSkillEchoes = true
        var battle = makeBattle(profile: profile)
        let ability = Ability(
            id: "echo-preparation", name: "Echo Preparation", tier: .skill,
            damageComponents: [DamageComponent(2, keyword: .burn)],
            targetedEffects: [TargetedEffect(.playNextCardTwice)],
            criticalChanceBonus: -1,
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)

        let events = try battle.playCard(cardID: card.id)

        #expect(events.count(where: { $0.kind == .ability && $0.abilityID == ability.id }) == 2)
        #expect(battle.activeEffects(of: battle.hero).count(where: { $0.effect == .playNextCardTwice }) == 1)
        #expect(battle.turnCadence.cardsPlayed[.hero] == 1)
    }

    @Test(arguments: [false, true])
    func `repeat stops at victory or an unaffordable second Health cost`(victory: Bool) throws {
        var battle = makeBattle()
        if victory {
            battle.roster.enemy.currentHealth = 1
        } else {
            battle.roster.hero.currentHealth = 3
        }
        readyRepeat(on: battle.hero, in: &battle)
        let ability = Ability(
            id: "repeat-boundary", name: "Repeat Boundary", tier: .skill,
            damageComponents: [DamageComponent(2, target: .actor), DamageComponent(2)],
            criticalChanceBonus: -1,
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)

        let events = try battle.playCard(cardID: card.id)

        #expect(events.count(where: { $0.kind == .ability && $0.abilityID == ability.id }) == 1)
        #expect(battle.roster.hero.currentHealth == (victory ? 18 : 1))
        #expect(!hasRepeat(on: battle.hero, in: battle))
        #expect(battle.heroDeck.discarded.map(\.copyID) == [card.deckCopyID])
    }

    @Test func `Bandit Shadowstep repeats its next ability once without advancing cadence twice`() {
        var battle = makeBattle()
        _ = BattleTurnEngine.performEnemyAction(ability: .shadowstep, abilityTarget: battle.hero, context: &battle)
        #expect(hasRepeat(on: battle.enemy, in: battle))
        let count = battle.roster.enemy.actionCount

        let repeated = BattleTurnEngine.performEnemyAction(ability: .stab, abilityTarget: battle.hero, context: &battle)

        #expect(repeated.performed)
        #expect(repeated.events.count(where: { $0.kind == .ability && $0.abilityID == Ability.stab.id }) == 2)
        #expect(battle.roster.enemy.actionCount == count + 1)
        #expect(!hasRepeat(on: battle.enemy, in: battle))
        let ordinary = BattleTurnEngine.performEnemyAction(ability: .block, abilityTarget: battle.hero, context: &battle)
        #expect(ordinary.events.count(where: { $0.effectKind == .shieldApplied }) == 1)
    }

    @Test func `fatal Thorns prevents the caster from executing the repeat`() throws {
        var battle = makeBattle()
        battle.roster.hero.currentHealth = 1
        battle.appendEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        readyRepeat(on: battle.hero, in: &battle)
        let card = BattleCardCombatEngine.deal(attack(), owner: .hero, context: &battle)

        let events = try battle.playCard(cardID: card.id)

        #expect(battle.roster.hero.currentHealth == 0)
        #expect(battle.roster.enemy.currentHealth == 98)
        #expect(events.count(where: { $0.kind == .ability && $0.abilityID == attack().id }) == 1)
        #expect(!hasRepeat(on: battle.hero, in: battle))
    }

    @Test(arguments: [Keyword?.none, .stun, .freeze])
    func `skipped and intercepted enemy attacks preserve Shadowstep`(control: Keyword?) {
        var profile = CombatModifierProfile.zero
        profile.triggers.negateFirstEnemyAttack = true
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [attack()], companionModifiers: profile, dealOpeningHand: false,
        )
        readyRepeat(on: battle.enemy, in: &battle)
        if let control {
            battle.appendEffect(.controlMeter(control, 20, 20), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }

        let events = BattleCardCombatEngine.resolveEnemyTurn(context: &battle)

        #expect(!events.contains { $0.kind == .ability && $0.abilityID == attack().id })
        #expect(hasRepeat(on: battle.enemy, in: battle))
    }

    private func makeBattle(profile: CombatModifierProfile = .zero) -> BattleState {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 6, heroMana: 6, heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        return battle
    }

    private func attack() -> Ability {
        Ability(id: "repeat-attack", name: "Repeat Attack", tier: .basic, directDamage: 2, criticalChanceBonus: -1)
    }

    private func readyRepeat(on actor: Combatant, in battle: inout BattleState) {
        battle.appendEffect(.playNextCardTwice, to: actor, sourceID: actor.id, remainingTurns: 0)
    }

    private func hasRepeat(on actor: Combatant, in battle: BattleState) -> Bool {
        battle.activeEffects(of: actor).contains { $0.effect == .playNextCardTwice }
    }
}
