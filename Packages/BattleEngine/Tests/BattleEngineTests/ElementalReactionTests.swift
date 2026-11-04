import Testing
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct ElementalReactionTests {
    private func battle() -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
    }

    private func attack(_ amount: Int, _ keyword: Keyword, in battle: inout BattleState) -> CombatOutcome {
        battle.resolveTestDamage(
            amount,
            keyword: keyword,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
    }

    private func reactions(_ events: [ActionEvent]) -> [CombatReaction] {
        events.compactMap {
            if case let .reaction(reaction) = $0.kind {
                reaction
            } else {
                nil
            }
        }
    }

    @Test func `Shatter strips all Block once and preserves Freeze and copied readiness`() {
        var state = battle()
        _ = attack(20, .freeze, in: &state)
        DefensePoolEngine.set(50, on: state.enemy, in: &state)
        let original = state
        let outcome = state.recordingResult { context in attack(1, .physical, in: &context) }
        #expect(reactions(outcome.events) == [.shatter])
        #expect(outcome.value.healthLost == 1)
        #expect(state.roster.enemy.currentHealth == 74)
        #expect(DefensePoolEngine.blockPoints(in: state.activeEffects(of: state.enemy)) == 0)
        #expect(state.roster.hasControlStatus(for: state.enemy, keyword: .freeze))
        #expect(original.roster.enemy.reactions.shatter == 5)
        #expect(reactions(state.recordingResult { context in attack(1, .physical, in: &context) }.events).isEmpty)
    }

    @Test func `Frostfire requires substantial natural Burn and only triggers on fresh Freeze`() {
        var state = battle()
        state.insertEffect(.burn(32), to: state.enemy, sourceID: state.hero.id, remainingTurns: 0)
        let fresh = state.recordingResult { context in attack(20, .freeze, in: &context) }
        #expect(reactions(fresh.events).isEmpty)
        ActiveEffectMutation.removeMatching(from: state.enemy, in: &state) { $0.keyword == .freeze }
        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: state.enemy, context: &state) }
        let outcome = state.recordingResult { context in attack(20, .freeze, in: &context) }
        #expect(reactions(outcome.events) == [.frostfire])
        #expect(!state.roster.hasAffliction(.burn, on: state.enemy))
        #expect(state.additionalControlSkipsByEffectID.values.reduce(0, +) == 1)
        #expect(outcome.events.filter { $0.reactionPayoff == .frostfire }.reduce(0) { $0 + $1.amount } == 20)
    }

    @Test func `Rupture detonates remaining Bleed and halves healing for two turns`() {
        var state = battle()
        state.insertEffect(.bleed(20), to: state.enemy, sourceID: state.hero.id, remainingTurns: 3)
        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: state.enemy, context: &state) }
        _ = attack(20, .stun, in: &state)
        let outcome = state.recordingResult { context in attack(1, .bleed, in: &context) }
        #expect(reactions(outcome.events) == [.rupture])
        #expect(outcome.events.filter { $0.reactionPayoff == .rupture }.reduce(0) { $0 + $1.amount } == 45)
        #expect(!state.roster.hasAffliction(.bleed, on: state.enemy))
        #expect(state.roster.hasControlStatus(for: state.enemy, keyword: .stun))
        #expect(CombatTriggerEngine.incomingHealMultiplier(for: state.enemy, in: state) == 0.5)
        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: state.enemy, context: &state) }
        #expect(CombatTriggerEngine.incomingHealMultiplier(for: state.enemy, in: state) == 0.5)
        state.turnCount += 1
        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: state.enemy, context: &state) }
        #expect(CombatTriggerEngine.incomingHealMultiplier(for: state.enemy, in: state) == 0.5)
        state.turnCount += 1
        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: state.enemy, context: &state) }
        #expect(CombatTriggerEngine.incomingHealMultiplier(for: state.enemy, in: state) == 1)
    }

    @Test func `a finishing attack cannot mature its own undersized preparation`() throws {
        var state = battle()
        state.insertEffect(.bleed(8), to: state.enemy, sourceID: state.hero.id, remainingTurns: 2)
        state.roster.mutateRuntime(for: state.enemy) { $0.reactions.naturalDamage[.bleed] = 20 }
        _ = attack(20, .stun, in: &state)
        let ability = Ability(
            id: "reaction-small-wound",
            name: "Attack",
            tier: .basic,
            damageComponents: [DamageComponent(4, keyword: .bleed)],
            criticalChanceBonus: -1,
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &state)
        let events = try state.playCard(cardID: card.id).events
        #expect(reactions(events).isEmpty)
        #expect(state.roster.enemy.reactions.rupture == 5)
        #expect(state.roster.hasAffliction(.bleed, on: state.enemy))
    }

    @Test func `Consecration cashes out Bleed immediately and grants a quarter of actual damage to each living ally`() {
        var state = battle()
        state.insertEffect(.bleed(20), to: state.enemy, sourceID: state.hero.id, remainingTurns: 3)
        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: state.enemy, context: &state) }
        let outcome = state.recordingResult { context in attack(1, .holy, in: &context) }
        #expect(reactions(outcome.events) == [.consecration])
        #expect(outcome.events.filter { $0.reactionPayoff == .consecration }.reduce(0) { $0 + $1.amount } == 45)
        #expect(DefensePoolEngine.blockPoints(in: state.activeEffects(of: state.hero)) == 11)
        #expect(DefensePoolEngine.blockPoints(in: state.activeEffects(of: state.companion)) == 11)
        #expect(!state.roster.hasAffliction(.bleed, on: state.enemy))
    }

    @Test func `Toxic Shock requires fresh successful Stun and consumes Poison without shortening control`() {
        var state = battle()
        state.insertEffect(.poison(16), to: state.enemy, sourceID: state.hero.id, remainingTurns: 0)
        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: state.enemy, context: &state) }
        state.applyControlMeter(10, keyword: .stun, to: state.enemy, sourceActorID: state.hero.id)
        #expect(!state.roster.enemy.reactions.weakenNextAttack)
        let events = state.recordingEvents { context in
            await context.applyControlMeter(10, keyword: .stun, to: context.enemy, sourceActorID: context.hero.id)
        }
        #expect(reactions(events) == [.toxicShock])
        #expect(!state.roster.hasAffliction(.poison, on: state.enemy))
        #expect(state.roster.hasControlStatus(for: state.enemy, keyword: .stun))
        #expect(state.roster.enemy.reactions.weakenNextAttack)
    }

    @Test func `Toxic Shock weakens all hits of exactly one actual attack and survives utility actions`() {
        var state = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: .withTriggers { $0.dodgeChanceBonus = -1 },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        state.roster.mutateRuntime(for: state.enemy) { $0.reactions.weakenNextAttack = true }
        let utility = Ability(id: "reaction-utility", name: "Block", tier: .basic, effects: [.shield(.block, 1)])
        BattleTurnEngine.performAction(ability: utility, actor: state.enemy, abilityTarget: state.enemy, context: &state)
        #expect(state.roster.enemy.reactions.weakenNextAttack)
        let hits = Ability(
            id: "reaction-multihit",
            name: "Attack",
            tier: .basic,
            damageComponents: [DamageComponent(4), DamageComponent(4)],
            criticalChanceBonus: -1,
        )
        let health = state.roster.hero.currentHealth
        BattleTurnEngine.performAction(ability: hits, actor: state.enemy, abilityTarget: state.hero, context: &state)
        #expect(state.roster.hero.currentHealth == health - 4)
        #expect(!state.roster.enemy.reactions.weakenNextAttack)
        BattleTurnEngine.performAction(ability: hits, actor: state.enemy, abilityTarget: state.hero, context: &state)
        #expect(state.roster.hero.currentHealth == health - 12)
    }

    @Test func `Venomflash detonates both ingredients and Purges a buff`() throws {
        var state = battle()
        state.insertEffect(.poison(16), to: state.enemy, sourceID: state.hero.id, remainingTurns: 0)
        state.insertEffect(.thorns(1), to: state.enemy, sourceID: state.enemy.id, remainingTurns: 0)
        state.roster.mutateRuntime(for: state.enemy) { $0.reactions.naturalDamage[.poison] = 20 }
        let ability = Ability(
            id: "reaction-ignition",
            name: "Attack",
            tier: .basic,
            damageComponents: [DamageComponent(4, keyword: .burn)],
            criticalChanceBonus: -1,
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &state)
        let events = try state.playCard(cardID: card.id).events
        #expect(reactions(events) == [.venomflash])
        #expect(!state.roster.hasAffliction(.poison, on: state.enemy))
        #expect(!state.roster.hasAffliction(.burn, on: state.enemy))
        #expect(!state.activeEffects(of: state.enemy).contains { $0.effect.kind == .thorns })
        #expect(events.filter { $0.reactionPayoff == .venomflash }.reduce(0) { $0 + $1.amount } > 5)
    }

    @Test func `one multi component card cannot trigger Consecration and Venomflash together`() throws {
        var state = battle()
        state.insertEffect(.bleed(20), to: state.enemy, sourceID: state.hero.id, remainingTurns: 2)
        state.insertEffect(.poison(16), to: state.enemy, sourceID: state.hero.id, remainingTurns: 0)
        state.roster.mutateRuntime(for: state.enemy) { $0.reactions.naturalDamage = [.bleed: 20, .poison: 20] }
        let ability = Ability(
            id: "reaction-mixed",
            name: "Attack",
            tier: .basic,
            damageComponents: [DamageComponent(1, keyword: .holy), DamageComponent(1, keyword: .burn)],
            criticalChanceBonus: -1,
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &state)
        let events = try state.playCard(cardID: card.id).events
        #expect(reactions(events) == [.consecration])
        #expect(state.roster.hasAffliction(.poison, on: state.enemy))
    }

    @Test func `natural Burn and Bleed never release the shelved Bloodboil or another passive reaction`() {
        var state = battle()
        state.insertEffect(.burn(20), to: state.enemy, sourceID: state.hero.id, remainingTurns: 0)
        state.insertEffect(.bleed(20), to: state.enemy, sourceID: state.hero.id, remainingTurns: 2)
        let events = state.recordingEvents { context in await EffectTurnEngine.advanceEffects(on: context.enemy, context: &context) }
        #expect(reactions(events).isEmpty)
    }

    @Test func `reaction damage remains unscaled and never creates new DoTs`() {
        var state = battle()
        DefensePoolEngine.set(40, on: state.enemy, in: &state)
        let outcome = state.resolveTestDamage(7, keyword: .burn, options: .elementalReaction)
        #expect(outcome.healthLost == 7)
        #expect(!outcome.isCritical)
        #expect(DefensePoolEngine.blockPoints(in: state.activeEffects(of: state.enemy)) == 40)
        #expect(!state.roster.hasAffliction(.burn, on: state.enemy))
        #expect(ElementalReactionEngine.bonus(Int.max, Int.max) == Int.max / 2 + 1)
    }
}
