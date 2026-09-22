import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct AbilityStrategyTests {
    private func battle(mana: Int = 0) -> BattleState {
        var triggers = CombatTraitTriggers()
        triggers.criticalChanceBonus = -1
        let profile = CombatModifierProfile(triggers: triggers)
        var state = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: mana, heroMana: mana,
            heroModifiers: profile, companionModifiers: profile, dealOpeningHand: false,
        )
        state.appliesFightPacing = false
        return state
    }

    private func deal(_ ability: Ability, owner: BattleParticipant = .hero, in state: inout BattleState) -> BattleCard {
        state.nextCardID += 1
        let card = BattleCard(id: state.nextCardID, ability: ability, owner: owner)
        state.hand = BattleHand(cards: [card])
        return card
    }

    @discardableResult
    private func play(_ ability: Ability, owner: BattleParticipant = .hero, in state: inout BattleState) throws -> [ActionEvent] {
        let card = deal(ability, owner: owner, in: &state)
        return try state.playCard(cardID: card.id)
    }

    @Test(arguments: [0, 1, 2, 6])
    func `shield bash gains block and scales stun from resulting block`(block: Int) throws {
        var state = battle()
        DefensePoolEngine.set(block, on: state.hero, in: &state)
        let card = deal(.shieldBash, in: &state)
        let rng = state.rng
        let assessment = state.assessCard(card)
        #expect(state.rng == rng)
        #expect(assessment.resources.isEmpty)
        #expect(DefensePoolEngine.blockPoints(in: state.roster.hero.activeEffects) == block)
        let events = try state.playCard(cardID: card.id)
        #expect(events.first { $0.kind == .abilityDamage }?.amount == max(1, (block + 1) / 2))
        #expect(DefensePoolEngine.blockPoints(in: state.roster.hero.activeEffects) == block + 1)
        #expect(!events.contains { $0.effectKind == .blockSpent })
        #expect(events.contains { $0.effectKind == .shieldApplied })
    }

    @Test func `enemy shield bash gains block before its stun damage`() {
        var triggers = CombatTraitTriggers()
        triggers.bleedingEnemyAttackDealDamage = 1
        triggers.criticalChanceBonus = -1
        var state = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: CombatModifierProfile(triggers: triggers), dealOpeningHand: false,
        )
        state.appliesFightPacing = false
        DefensePoolEngine.set(2, on: state.enemy, in: &state)
        state.appendEffect(.bleed(1), to: state.enemy, sourceID: state.hero.id, remainingTurns: 3)
        let result = BattleTurnEngine.performEnemyAction(ability: .shieldBash, abilityTarget: state.hero, context: &state)
        #expect(result.performed)
        #expect(DefensePoolEngine.blockPoints(in: state.roster.enemy.activeEffects) == 2)
        #expect(result.events.first { $0.kind == .abilityDamage }?.amount == 1)
    }

    @Test func `cancelled enemy shield bash refunds reserved block`() {
        var triggers = CombatTraitTriggers()
        triggers.negateFirstEnemyAttack = true
        var state = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatModifierProfile(triggers: triggers), dealOpeningHand: false,
        )
        DefensePoolEngine.set(2, on: state.enemy, in: &state)
        let result = BattleTurnEngine.performEnemyAction(ability: .shieldBash, abilityTarget: state.hero, context: &state)
        #expect(!result.performed)
        #expect(DefensePoolEngine.blockPoints(in: state.roster.enemy.activeEffects) == 2)
        #expect(!result.events.contains { $0.effectKind == .blockSpent })
    }

    @Test(arguments: [false, true])
    func `ice shot assessment selects before mana payment`(frozen: Bool) throws {
        var state = battle(mana: 6)
        if frozen {
            state.appendEffect(.controlMeter(.freeze, 10, 10), to: state.enemy, sourceID: state.hero.id, remainingTurns: 0)
        }
        let card = deal(.iceShot, in: &state)
        let rng = state.rng
        let assessment = state.assessCard(card)
        #expect(assessment.targets.contains { $0.intent == .damage(.freeze) })
        #expect(!assessment.resources.isEmpty)
        #expect(state.rng == rng)
        let selected = BattleAbilityRules.resolveOutcome(.iceShot, actor: state.hero, in: &state)
        #expect(state.rng == rng)
        #expect(selected.directDamage == 2)
        let events = try state.playCard(cardID: card.id)
        #expect(events.filter { $0.kind == .abilityDamage }.map(\.keyword) == [.freeze])
        #expect(state.roster.hero.currentMana < 6)
        if frozen {
            #expect(BattleConditionEvaluator.isMet(.enemyFrozen, actor: state.hero, in: state))
        }
    }

    @Test(arguments: [0, 1, 8])
    func `maul uses block at preparation without random selection`(block: Int) throws {
        var state = battle()
        DefensePoolEngine.set(block, on: state.enemy, in: &state)
        let card = deal(.maul, in: &state)
        let rng = state.rng
        let expected: Keyword = block > 0 ? .stun : .bleed
        #expect(state.assessCard(card).targets.first?.intent == .damage(expected))
        let selected = BattleAbilityRules.resolveOutcome(.maul, actor: state.hero, in: &state)
        #expect(selected.directDamage == 3)
        #expect(selected.damageKeyword == expected)
        #expect(state.rng == rng)
        let events = try state.playCard(cardID: card.id)
        #expect(events.first { $0.kind == .abilityDamage }?.keyword == expected)
    }

    @Test(arguments: [false, true])
    func `stab guarantees critical only at full health`(full: Bool) throws {
        var state = battle()
        if !full {
            state.roster.enemy.currentHealth -= 1
        }
        let events = try play(.stab, in: &state)
        let hit = try #require(events.first { $0.kind == .abilityDamage })
        #expect(hit.isCritical == full)
        #expect(hit.amount == (full ? 4 : 2))
    }

    @Test(arguments: [0, 5, 8])
    func `sunder halves block before its hit`(block: Int) throws {
        var state = battle()
        DefensePoolEngine.set(block, on: state.enemy, in: &state)
        let events = try play(.sunder, in: &state)
        let hitIndex = try #require(events.firstIndex { $0.kind == .abilityDamage })
        #expect(events[hitIndex].amount == max(0, 4 - block / 2))
        if block > 0 {
            let reduction = try #require(events.firstIndex { $0.effectKind == .shieldHalved })
            #expect(reduction < hitIndex)
        }
    }

    @Test func `sniff out waits for partner attack across support and turns`() throws {
        var state = battle()
        let opening = try play(.sniffOut, in: &state)
        let chip = try #require(opening.first { $0.effectKind == .partyDamagePreparationApplied })
        #expect(chip.targetID == state.companion.id)
        #expect(chip.amount == 1)
        let attack = Ability(id: "attack", name: "Attack", tier: .basic, directDamage: 2)
        _ = try play(attack, in: &state)
        _ = try play(.block, owner: .companion, in: &state)
        #expect(state.resolution.pendingPartyDamage(for: state.companion.id) == 1)
        _ = state.endTurn()
        _ = try play(.sniffOut, in: &state)
        let multi = Ability(id: "multi", name: "Multi", tier: .basic, damageComponents: [
            DamageComponent(2, keyword: .physical), DamageComponent(2, keyword: .physical),
        ])
        let before = state.roster.enemy.currentHealth
        _ = try play(multi, owner: .companion, in: &state)
        #expect(before - state.roster.enemy.currentHealth == 5)
        #expect(state.resolution.pendingPartyDamage(for: state.companion.id) == 0)
    }

    @Test func `sniff out falls back to caster and assessment agrees`() throws {
        var state = battle()
        state.roster.companion.currentHealth = 0
        let card = deal(.sniffOut, in: &state)
        #expect(state.assessCard(card).targets.contains { $0.combatantID == state.hero.id })
        let events = try state.playCard(cardID: card.id)
        #expect(events.first { $0.effectKind == .partyDamagePreparationApplied }?.targetID == state.hero.id)
        #expect(state.resolution.pendingPartyDamage(for: state.hero.id) == 1)
    }

    @Test func `automatic partner attack consumes preparation but counterattack does not`() throws {
        var state = battle()
        _ = try play(.sniffOut, in: &state)
        let attack = Ability(id: "followup", name: "Followup", tier: .basic, directDamage: 2)
        _ = BattleTurnEngine.performAction(
            ability: attack, actor: state.companion, abilityTarget: state.enemy, origin: .counterattack, context: &state,
        )
        #expect(state.resolution.pendingPartyDamage(for: state.companion.id) == 1)
        state.companionDeck = CombatDeck(abilities: [attack])
        let before = state.roster.enemy.currentHealth
        _ = try play(.packTactics, in: &state)
        #expect(before - state.roster.enemy.currentHealth == 6)
        #expect(state.resolution.pendingPartyDamage(for: state.companion.id) == 0)
    }
}
