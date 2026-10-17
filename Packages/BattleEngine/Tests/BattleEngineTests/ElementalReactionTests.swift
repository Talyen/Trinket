import Testing
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct ElementalReactionTests {
    private func battle() -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
    }

    private func attack(
        _ amount: Int,
        _ keyword: Keyword,
        from source: BattleParticipant = .hero,
        in battle: inout BattleState,
    ) -> CombatOutcome {
        battle.resolveTestDamage(
            amount,
            from: source,
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

    @Test func `Shatter strips Block and pays the original setup once across allies without forcing a Critical`() {
        var state = battle()
        _ = attack(20, .freeze, in: &state)
        DefensePoolEngine.set(50, on: state.enemy, in: &state)
        let outcome = state.recordingResult { context in attack(1, .physical, from: .companion, in: &context) }
        #expect(outcome.value.healthLost == 1)
        #expect(reactions(outcome.events) == [.shatter])
        #expect(outcome.events.contains { $0.abilityName == "Shatter" && $0.kind == .abilityDamage && $0.amount == 5 && !$0.isCritical })
        #expect(state.roster.enemy.currentHealth == 74)
        #expect(state.roster.hasControlStatus(for: state.enemy, keyword: .freeze))
        #expect(DefensePoolEngine.blockPoints(in: state.activeEffects(of: state.enemy)) == 0)
        #expect(reactions(state.recordingResult { context in attack(1, .physical, in: &context) }.events).isEmpty)
    }

    @Test func `zero Physical damage preserves Shatter and Block`() {
        var state = battle()
        _ = attack(20, .freeze, in: &state)
        DefensePoolEngine.set(8, on: state.enemy, in: &state)
        _ = attack(0, .physical, in: &state)
        #expect(state.roster.enemy.reactions.shatter == 5)
        #expect(DefensePoolEngine.blockPoints(in: state.activeEffects(of: state.enemy)) == 8)
    }

    @Test(arguments: [DamageOperation.AttackOrigin.counterattack, .repeatedAttack, .cardRepeat, .criticalRepeat])
    func `secondary attacks cannot spend control opportunities`(origin: DamageOperation.AttackOrigin) {
        var state = battle()
        _ = attack(20, .freeze, in: &state)
        let outcome = state.recordingResult { context in context.resolveTestDamage(
            1,
            keyword: .physical,
            options: .attack(origin: origin, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) }
        #expect(reactions(outcome.events).isEmpty)
        #expect(state.roster.enemy.reactions.shatter == 5)
    }

    @Test func `secondary control prepares minimum bonuses and removing control expires both Freeze opportunities`() {
        var state = battle()
        state.applyControlMeter(20, keyword: .freeze, to: state.enemy, sourceActorID: state.hero.id)
        #expect(state.roster.enemy.reactions.shatter == 1)
        #expect(state.roster.enemy.reactions.frostfire == 1)
        ActiveEffectMutation.removeMatching(from: state.enemy, in: &state) { $0.keyword == .freeze }
        #expect(state.roster.enemy.reactions.shatter == 0)
        #expect(state.roster.enemy.reactions.frostfire == 0)
        _ = attack(20, .freeze, in: &state)
        #expect(state.roster.enemy.reactions.shatter == 5)
    }

    @Test func `Frostfire routes share a Freeze opportunity while Shatter remains independent`() {
        var state = battle()
        state.insertEffect(.burn(8), to: state.enemy, sourceID: state.hero.id, remainingTurns: 0)
        let frozen = state.recordingResult { context in attack(20, .freeze, in: &context) }
        #expect(reactions(frozen.events) == [.frostfire])
        #expect(reactions(state.recordingResult { context in attack(1, .burn, in: &context) }.events).isEmpty)
        #expect(reactions(state.recordingResult { context in attack(1, .physical, in: &context) }.events) == [.shatter])

        var other = battle()
        _ = attack(20, .freeze, in: &other)
        #expect(reactions(other.recordingResult { context in attack(1, .burn, from: .companion, in: &context) }.events) == [.frostfire])
        #expect(other.roster.enemy.reactions.shatter == 5)
    }

    @Test func `fatal retaliation prevents a bonus while the other ally survives`() {
        var state = battle()
        _ = attack(20, .freeze, in: &state)
        state.roster.mutateRuntime(for: state.hero) {
            $0.currentHealth = 1
            $0.hasConsumedDeathsDoor = true
        }
        state.insertEffect(.thorns(10), to: state.enemy, sourceID: state.enemy.id, remainingTurns: 0)
        let outcome = state.recordingResult { context in attack(1, .burn, in: &context) }
        #expect(!state.roster.hero.isAlive)
        #expect(state.roster.companion.isAlive)
        #expect(reactions(outcome.events).isEmpty)
        #expect(state.roster.enemy.reactions.frostfire == 5)
    }

    @Test func `phase bonuses aggregate Bleeds and count a final fading Burn without advancing on extra damage`() {
        var state = battle()
        state.insertEffect(.burn(8), to: state.enemy, sourceID: state.hero.id, remainingTurns: 0)
        state.insertEffect(.bleed(4), to: state.enemy, sourceID: state.hero.id, remainingTurns: 2)
        state.insertEffect(.bleed(4), to: state.enemy, sourceID: state.companion.id, remainingTurns: 2)
        _ = attack(1, .holy, in: &state)
        let events = state.recordingEvents { context in
            await EffectTurnEngine.advanceEffects(on: context.enemy, context: &context)
        }
        #expect(reactions(events) == [.consecration, .bloodboil])
        #expect(events.filter { $0.kind == .abilityDamage && $0.abilityName == "Consecration" }.map(\.amount) == [2])
        #expect(events.filter { $0.kind == .abilityDamage && $0.abilityName == "Bloodboil" }.map(\.amount) == [3])
        #expect(state.roster.enemy.reactions.pendingPoisonTick == nil)
        _ = state.resolveDoTTick(basePotency: 12, keyword: .burn, target: state.enemy, sourceActorID: state.hero.id)
        #expect(state.roster.enemy.reactions.pendingPoisonTick == nil)
        #expect(state.roster.enemy.reactions.toxicShock == 0)
    }

    @Test func `Consecration cancels on removal and cannot mark a wound created after its Holy hit`() {
        var state = battle()
        _ = attack(1, .holy, in: &state)
        state.insertEffect(.bleed(4), to: state.enemy, sourceID: state.hero.id, remainingTurns: 2)
        #expect(state.roster.enemy.reactions.consecratedBy == nil)
        _ = attack(1, .holy, in: &state)
        #expect(state.roster.enemy.reactions.consecratedBy == state.hero.id)
        ActiveEffectMutation.removeMatching(from: state.enemy, in: &state) { $0.isBleed }
        #expect(state.roster.enemy.reactions.consecratedBy == nil)
    }

    @Test func `Venomflash survives immediate ignition detonation without adding bonus Burn stacks`() throws {
        var state = battle()
        state.insertEffect(.poison(12), to: state.enemy, sourceID: state.hero.id, remainingTurns: 0)
        let ability = Ability(
            id: "reaction-ignition", name: "Ignition", tier: .basic,
            damageComponents: [DamageComponent(4, keyword: .burn)],
            targetedEffects: [TargetedEffect(.detonateDoT(.burn, 1))], criticalChanceBonus: -1,
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &state)
        let events = try state.playCard(cardID: card.id).events
        #expect(reactions(events) == [.venomflash])
        #expect(events.contains { $0.kind == .abilityDamage && $0.abilityName == "Venomflash" && $0.amount == 3 })
        #expect(!state.roster.hasAffliction(.burn, on: state.enemy))
        #expect(state.roster.hasAffliction(.poison, on: state.enemy))
    }

    @Test func `reaction damage bypasses defenses and modifiers without consuming preparations or applying riders`() {
        var state = battle()
        state.insertEffect(.nextStrikeDouble, to: state.hero, sourceID: state.hero.id, remainingTurns: 0)
        DefensePoolEngine.set(40, on: state.enemy, in: &state)
        let outcome = state.recordingResult { context in context.resolveTestDamage(7, keyword: .burn, options: .elementalReaction) }
        #expect(outcome.value.healthLost == 7)
        #expect(!outcome.value.isCritical)
        #expect(state.activeEffects(of: state.hero).contains { $0.effect.kind == .nextStrikeDouble })
        #expect(DefensePoolEngine.blockPoints(in: state.activeEffects(of: state.enemy)) == 40)
        #expect(!state.roster.hasAffliction(.burn, on: state.enemy))
        #expect(reactions(outcome.events).isEmpty)
    }

    @Test func `forecast copies cannot consume the live enemy reaction state`() {
        var live = battle()
        _ = attack(20, .freeze, in: &live)
        var copy = live
        _ = attack(1, .physical, in: &copy)
        #expect(copy.roster.enemy.reactions.shatter == 0)
        #expect(live.roster.enemy.reactions.shatter == 5)
        #expect(live.roster.enemy.currentHealth == 80)
        #expect(ElementalReactionEngine.bonus(Int.max, Int.max) == Int.max / 2 + 1)
        #expect(ElementalReactionEngine.bonus(8, 4) == 3)
        #expect(ElementalReactionEngine.bonus(4, 2) == 2)
    }

    @Test func `Rupture rewards a partners Bleed attack once per Stun without another Bleed application`() {
        var state = battle()
        _ = attack(20, .stun, in: &state)
        let outcome = state.recordingResult { context in attack(1, .bleed, from: .companion, in: &context) }
        #expect(reactions(outcome.events) == [.rupture])
        #expect(outcome.events
            .contains { $0.kind == .abilityDamage && $0.abilityName == "Rupture" && $0.amount == 5 && $0.keyword == .bleed })
        #expect(state.roster.enemy.currentHealth == 74)
        #expect(state.roster.hasControlStatus(for: state.enemy, keyword: .stun))
        #expect(!state.roster.hasAffliction(.bleed, on: state.enemy))
        #expect(reactions(state.recordingResult { context in attack(1, .bleed, in: &context) }.events).isEmpty)
    }

    @Test func `Toxic Shock pairs natural Poison phases across gaps and ignores extra ticks`() {
        var state = battle()
        state.insertEffect(.poison(16), to: state.enemy, sourceID: state.hero.id, remainingTurns: 0)
        _ = state.recordingEvents { context in await EffectTurnEngine.advanceEffects(on: context.enemy, context: &context) }
        #expect(state.roster.enemy.reactions.pendingPoisonTick == 12)
        _ = state.resolveDoTTick(basePotency: 4, keyword: .poison, target: state.enemy, sourceActorID: state.hero.id)
        #expect(state.roster.enemy.reactions.pendingPoisonTick == 12)
        ActiveEffectMutation.removeMatching(from: state.enemy, in: &state) { $0.keyword == .poison }
        state.turnCount += 1
        state.insertEffect(.poison(12), to: state.enemy, sourceID: state.companion.id, remainingTurns: 0)
        _ = state.recordingEvents { context in await EffectTurnEngine.advanceEffects(on: context.enemy, context: &context) }
        #expect(state.roster.enemy.reactions.toxicShock == 5)
        #expect(state.roster.enemy.reactions.pendingPoisonTick == nil)
        ActiveEffectMutation.removeMatching(from: state.enemy, in: &state) { $0.keyword == .poison }
        let partial = state.recordingResult { context in attack(1, .stun, from: .companion, in: &context) }
        #expect(reactions(partial.events).isEmpty)
        #expect(state.roster.enemy.reactions.toxicShock == 5)
        let outcome = state.recordingResult { context in attack(20, .stun, from: .companion, in: &context) }
        #expect(reactions(outcome.events) == [.toxicShock])
        #expect(outcome.events
            .contains { $0.kind == .abilityDamage && $0.abilityName == "Toxic Shock" && $0.amount == 5 && $0.keyword == .poison })
        #expect(state.roster.enemy.reactions.toxicShock == 0)
        #expect(!state.roster.hasAffliction(.poison, on: state.enemy))
        #expect(reactions(state.recordingResult { context in attack(1, .stun, in: &context) }.events).isEmpty)
    }

    @Test func `a reaction kill belongs to its finisher and cannot pay kill rewards twice`() {
        var state = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: .withTriggers { $0.defeatBleedingEnemyGold = 3 },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        _ = attack(20, .freeze, in: &state)
        state.insertEffect(.bleed(1), to: state.enemy, sourceID: state.hero.id, remainingTurns: 2)
        state.roster.mutateRuntime(for: state.enemy) { $0.currentHealth = 6 }
        _ = attack(1, .physical, from: .companion, in: &state)
        state.appendDefeatMilestonesIfNeeded()
        state.appendDefeatMilestonesIfNeeded()
        #expect(state.isEnemyDefeated)
        #expect(state.lastEnemyDefeatSourceActorID == state.companion.id)
        #expect(state.gold == 3)
        #expect(state.events.count(where: { $0.kind == .milestone(.enemyDefeated) }) == 1)
    }

    @Test(arguments: PlayPolicy.allCases)
    func `forecast recognizes a reaction finisher without consuming live readiness`(policy: PlayPolicy) throws {
        var state = battle()
        _ = attack(20, .freeze, in: &state)
        state.roster.mutateRuntime(for: state.enemy) { $0.currentHealth = 6 }
        let support = BattleCardCombatEngine.deal(.block, owner: .hero, context: &state)
        let ability = Ability(id: "reaction-finisher", name: "Finisher", tier: .basic, directDamage: 1, criticalChanceBonus: -1)
        let finisher = BattleCardCombatEngine.deal(ability, owner: .hero, context: &state)
        let seed = state.rng
        #expect(policy.preferredPlayableCard(in: state)?.id == finisher.id)
        #expect(state.roster.enemy.reactions.shatter == 5)
        #expect(state.hand.cards.contains { $0.id == support.id })
        #expect(state.rng == seed)
        _ = try state.playCard(cardID: finisher.id)
        #expect(state.isEnemyDefeated)
    }

    @Test func `non damaging control releases Toxic Shock only on a fresh successful Stun`() {
        var state = battle()
        state.roster.mutateRuntime(for: state.enemy) { $0.reactions.toxicShock = 5 }
        let partial = state.recordingEvents { context in
            await context.applyControlMeter(10, keyword: .stun, to: context.enemy, sourceActorID: context.hero.id)
        }
        #expect(reactions(partial).isEmpty)
        #expect(state.roster.enemy.reactions.toxicShock == 5)
        let triggered = state.recordingEvents { context in
            await context.applyControlMeter(10, keyword: .stun, to: context.enemy, sourceActorID: context.companion.id)
        }
        #expect(reactions(triggered) == [.toxicShock])
        #expect(state.roster.enemy.currentHealth == 95)
        #expect(state.roster.enemy.reactions.rupture == 1)
        #expect(state.roster.enemy.reactions.toxicShock == 0)
        state.roster.mutateRuntime(for: state.enemy) { $0.reactions.toxicShock = 3 }
        let alreadyStunned = state.recordingEvents { context in
            await context.applyControlMeter(20, keyword: .stun, to: context.enemy, sourceActorID: context.hero.id)
        }
        #expect(reactions(alreadyStunned).isEmpty)
        #expect(state.roster.enemy.reactions.toxicShock == 3)
    }

    @Test func `a natural Poison tick can earn its pair before its own successful Stun releases Toxic Shock`() {
        var state = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: .withTriggers { $0.poisonThresholdStunAmount = 1 },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        state.insertEffect(.poison(16), to: state.enemy, sourceID: state.hero.id, remainingTurns: 0)
        let first = state.recordingEvents { context in await EffectTurnEngine.advanceEffects(on: context.enemy, context: &context) }
        #expect(reactions(first).isEmpty)
        #expect(state.roster.hasControlStatus(for: state.enemy, keyword: .stun))
        ActiveEffectMutation.removeMatching(from: state.enemy, in: &state) { $0.keyword == .stun }
        state.turnCount += 1
        let second = state.recordingEvents { context in await EffectTurnEngine.advanceEffects(on: context.enemy, context: &context) }
        #expect(reactions(second) == [.toxicShock])
        #expect(state.roster.enemy.reactions.toxicShock == 0)
        #expect(second.filter { $0.kind == .abilityDamage && $0.abilityName == "Toxic Shock" }.map(\.amount) == [5])
        #expect(state.roster.enemy.currentHealth == 74)
    }
}
