import TrinketContent
import TrinketCore

struct ElementalReactionState: Hashable {
    var shatter = 0
    var frostfire = 0
    var rupture = 0
    var freezeGeneration = 0
    var stunGeneration = 0
    var naturalDamage: [Keyword: Int] = [:]
    var weakenNextAttack = false
    var ruptureEffectID: Int?
    var ruptureAppliedTurn: Int?

    var hasStatusPreparation: Bool {
        shatter != 0 || frostfire != 0 || rupture != 0
    }

    mutating func expire(with effects: [ActiveEffect]) {
        if !effects.contains(where: { $0.keyword == .freeze && $0.isAwaitingActionSkip }) {
            shatter = 0
            frostfire = 0
        }
        if !effects.contains(where: { $0.keyword == .stun && $0.isAwaitingActionSkip }) {
            rupture = 0
        }
    }
}

struct ElementalReactionHit: Equatable {
    let sourceID: String
    let keyword: Keyword
    let before: DamageTargetStatus
    let prepared: ElementalReactionState
    let hasPreparedDoT: Bool
    var shatter = 0
}

struct ToxicShockPayoff {
    let amount: Int
    let sourceID: String?
}

struct NaturalReactionPhase {
    let turn: Int
}

enum ElementalReactionEngine {
    /// Divide before adding so large damage pools receive one exact rounding.
    static func bonus(_ amounts: Int...) -> Int {
        var whole = 0
        var remainder = 0
        for amount in amounts {
            let nonnegative = max(0, amount)
            whole = SaturatedArithmetic.saturatingAdd(whole, nonnegative / 4)
            remainder += nonnegative % 4
        }
        return max(1, SaturatedArithmetic.saturatingAdd(whole, (remainder + 2) / 4))
    }

    static func capture(_ request: DamageRequest, in context: BattleState) -> ElementalReactionHit? {
        guard request.options.canInitiateElementalReaction, request.target == context.enemy,
              context.resolution.canReleaseReaction,
              let sourceID = request.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.isAlive, source.role != .enemy,
              let keyword = request.keyword else { return nil }
        let preparation: Keyword? = switch keyword {
        case .freeze: .burn
        case .bleed, .holy: .bleed
        case .burn: .poison
        default: nil
        }
        return ElementalReactionHit(
            sourceID: sourceID, keyword: keyword,
            before: DamageTargetStatus(for: context.enemy, in: context), prepared: context.roster.enemy.reactions,
            hasPreparedDoT: preparation.map { isPrepared($0, in: context) } ?? false,
        )
    }

    private static func isPrepared(_ keyword: Keyword, in context: BattleState) -> Bool {
        let threshold = max(1, CombatRounding.scaled(context.roster.enemy.maxHealth, multiplier: 0.1))
        let potency = context.roster.activeEffects(for: context.enemy).reduce(0) { total, active in
            active.keyword == keyword
                ? SaturatedArithmetic.saturatingAdd(total, active.effect.potency ?? 0) : total
        }
        return context.roster.enemy.reactions.naturalDamage[keyword, default: 0] >= threshold && potency >= threshold
    }

    static func prepareControl(
        _ keyword: Keyword, target: Combatant, healthDamage: Int, sourceID: String?, in context: inout BattleState,
    ) {
        guard target == context.enemy else { return }
        if keyword == .stun, isPrepared(.poison, in: context) {
            context.resolution.pendingToxicShocks.append(ToxicShockPayoff(amount: bonus(healthDamage), sourceID: sourceID))
        }
        context.roster.mutateRuntime(for: target) { runtime in
            if keyword == .freeze {
                runtime.reactions.freezeGeneration = SaturatedArithmetic.saturatingAdd(runtime.reactions.freezeGeneration, 1)
                runtime.reactions.shatter = bonus(healthDamage)
                runtime.reactions.frostfire = bonus(healthDamage)
            } else if keyword == .stun {
                runtime.reactions.stunGeneration = SaturatedArithmetic.saturatingAdd(runtime.reactions.stunGeneration, 1)
                runtime.reactions.rupture = bonus(healthDamage)
            }
        }
    }

    static func shatter(to state: inout DamageResolutionState, in context: inout BattleState) {
        guard var hit = state.elementalHit, hit.keyword == .physical, state.remaining > 0,
              hit.before.isFrozen, hit.prepared.shatter > 0,
              context.roster.enemy.reactions.freezeGeneration == hit.prepared.freezeGeneration,
              context.roster.enemy.isAlive, context.roster.combatant(for: hit.sourceID)?.isAlive == true,
              context.roster.enemy.reactions.shatter > 0, context.resolution.claimReaction() else { return }
        hit.shatter = hit.prepared.shatter
        state.elementalHit = hit
        context.roster.mutateRuntime(for: context.enemy) { $0.reactions.shatter = 0 }
        announce(.shatter, sourceID: hit.sourceID, in: &context)
        DefensePoolEngine.strip(
            .max, from: context.enemy, source: context.eventSource(actorID: hit.sourceID, fallback: context.enemy),
            abilityName: CombatReaction.shatter.displayName, in: &context,
        )
    }

    static func finish(_ hit: ElementalReactionHit, outcome: CombatOutcome, in context: inout BattleState) async {
        guard !outcome.isDodged, !context.isBattleOver,
              context.roster.combatant(for: hit.sourceID)?.isAlive == true else { return }
        if hit.shatter > 0 {
            await release(.shatter, amount: hit.shatter, sourceID: hit.sourceID, in: &context)
            return
        }
        guard context.resolution.canReleaseReaction, hit.hasPreparedDoT else { return }
        let current = context.roster.enemy.reactions
        if hit.keyword == .freeze, !hit.before.isFrozen, hit.before.isBurning,
           outcome.flags.contains(.controlTriggered), current.frostfire > 0,
           current.freezeGeneration == SaturatedArithmetic.saturatingAdd(hit.prepared.freezeGeneration, 1) {
            await release(.frostfire, amount: current.frostfire, sourceID: hit.sourceID, in: &context)
        } else if hit.keyword == .bleed, outcome.healthLost > 0, hit.before.isStunned,
                  current.stunGeneration == hit.prepared.stunGeneration, current.rupture > 0 {
            await release(.rupture, amount: current.rupture, sourceID: hit.sourceID, in: &context)
        } else if hit.keyword == .holy, outcome.healthLost > 0, hit.before.isBleeding {
            await release(.consecration, amount: bonus(current.naturalDamage[.bleed, default: 0]), sourceID: hit.sourceID, in: &context)
        } else if hit.keyword == .burn, outcome.healthLost > 0, hit.before.isPoisoned {
            await release(.venomflash, amount: bonus(current.naturalDamage[.poison, default: 0]), sourceID: hit.sourceID, in: &context)
        }
    }

    static func finishControl(in context: inout BattleState) async {
        guard context.resolution.depth(.damage) == 0, context.resolution.controlDepth == 0,
              !context.uniques.isDrainingOutOfTurnAttacks else { return }
        let pending = context.resolution.pendingToxicShocks
        context.resolution.pendingToxicShocks.removeAll()
        for payoff in pending {
            guard !context.isBattleOver else { break }
            guard let sourceID = payoff.sourceID, context.roster.combatant(for: sourceID)?.isAlive == true,
                  isPrepared(.poison, in: context) else { continue }
            await release(.toxicShock, amount: payoff.amount, sourceID: sourceID, in: &context)
        }
    }

    static func recordNaturalTick(_ keyword: Keyword, amount: Int, sourceID _: String?, in context: inout BattleState) {
        guard amount > 0, context.resolution.naturalReactionPhase != nil,
              keyword == .burn || keyword == .poison || keyword == .bleed else { return }
        context.roster.mutateRuntime(for: context.enemy) { runtime in
            runtime.reactions.naturalDamage[keyword] = SaturatedArithmetic.saturatingAdd(
                runtime.reactions.naturalDamage[keyword, default: 0], amount,
            )
        }
    }

    private static func announce(_ reaction: CombatReaction, sourceID: String?, in context: inout BattleState) {
        context.nextEvent(
            kind: .reaction(reaction), source: context.eventSource(actorID: sourceID, fallback: context.enemy),
            abilityName: reaction.displayName, target: context.enemy, amount: 0, keyword: reaction.damageKeyword,
        )
    }

    private static func release(_ reaction: CombatReaction, amount: Int, sourceID: String, in context: inout BattleState) async {
        guard amount > 0, !context.isBattleOver, reaction == .shatter || context.resolution.claimReaction() else { return }
        if reaction != .shatter {
            announce(reaction, sourceID: sourceID, in: &context)
        }
        let keywords: Set<Keyword> = switch reaction {
        case .shatter: []
        case .frostfire: [.burn]
        case .rupture, .consecration: [.bleed]
        case .toxicShock: [.poison]
        case .venomflash: [.poison, .burn]
        }
        context.roster.mutateRuntime(for: context.enemy) { runtime in
            for keyword in keywords {
                runtime.reactions.naturalDamage[keyword] = 0
            }
            if reaction == .frostfire {
                runtime.reactions.frostfire = 0
            }
            if reaction == .rupture {
                runtime.reactions.rupture = 0
            }
        }
        context.resolution.reactionPayoff = reaction
        defer { context.resolution.reactionPayoff = nil }
        context.resolution.reactionHealthLost = 0
        await detonate(keywords, sourceID: sourceID, in: &context)
        let detonatedDamage = context.resolution.reactionHealthLost
        if !context.isBattleOver, context.roster.combatant(for: sourceID)?.isAlive == true {
            let outcome = await context.resolveDamage(DamageRequest(
                amount: amount, target: context.enemy, keyword: reaction.damageKeyword,
                sourceActorID: sourceID, options: .elementalReaction,
            ))
            context.resolution.reactionHealthLost = SaturatedArithmetic.saturatingAdd(detonatedDamage, outcome.healthLost)
            context.nextEvent(
                kind: .abilityDamage, source: context.eventSource(actorID: sourceID, fallback: context.enemy),
                abilityName: reaction.displayName, target: context.enemy, amount: outcome.healthLost,
                keyword: reaction.damageKeyword, reactionPayoff: reaction,
            )
        }
        await applyBenefit(reaction, damage: context.resolution.reactionHealthLost, sourceID: sourceID, in: &context)
    }

    private static func detonate(_ keywords: Set<Keyword>, sourceID: String, in context: inout BattleState) async {
        guard !keywords.isEmpty, context.resolution.depth(.detonation) == 0 else { return }
        let effects = context.roster.activeEffects(for: context.enemy).filter {
            keywords.contains($0.keyword) && ($0.effect.isDecayingDoT || $0.effect.isBleed)
        }
        context.resolution.enter(.detonation)
        defer { context.resolution.leave(.detonation) }
        // Keep the ingredients present during payout so their conditional bonuses survive the cash-out.
        for active in effects {
            guard !context.isBattleOver else { break }
            if active.effect.isBleed {
                await CombatTriggerEngine.detonateBleedStacks([active], on: context.enemy, sourceActorID: sourceID, in: &context)
            } else {
                await DecayingDoTDetonation.resolve(active, factor: 1, target: context.enemy, sourceActorID: sourceID, in: &context)
            }
        }
        let ids = Set(effects.map(\.id))
        context.roster.mutateEffects(for: context.enemy) { active in
            active.removeAll { ids.contains($0.id) }
        }
    }

    private static func applyBenefit(_ reaction: CombatReaction, damage: Int, sourceID: String, in context: inout BattleState) async {
        guard let source = context.roster.combatant(for: sourceID)?.combatant else { return }
        switch reaction {
        case .shatter: break
        case .frostfire:
            if let freeze = context.roster.activeEffects(for: context.enemy)
                .first(where: { $0.keyword == .freeze && $0.isAwaitingActionSkip }) {
                context.additionalControlSkipsByEffectID[freeze.id] = SaturatedArithmetic.saturatingAdd(
                    context.additionalControlSkipsByEffectID[freeze.id, default: 0], 1,
                )
            }
        case .rupture:
            if context.insertEffect(.healingReductionPercent(0.5, 2), to: context.enemy, sourceID: sourceID, remainingTurns: 2) {
                let effectID = context.roster.activeEffects(for: context.enemy).last?.id
                let turn = context.turnCount
                context.roster.mutateRuntime(for: context.enemy) {
                    $0.reactions.ruptureEffectID = effectID
                    $0.reactions.ruptureAppliedTurn = turn
                }
            }
        case .toxicShock:
            context.roster.mutateRuntime(for: context.enemy) { $0.reactions.weakenNextAttack = true }
        case .consecration:
            guard damage > 0 else { return }
            let block = bonus(damage)
            for ally in CombatTriggerEngine.livingAllies(in: context) {
                context.applyBlockGain(block, to: ally.combatant, source: source, abilityName: reaction.displayName)
            }
        case .venomflash:
            guard !context.isBattleOver, context.roster.combatant(for: sourceID)?.isAlive == true else { return }
            _ = await EffectRemovalOperation.resolvePurge(
                .randomBuffs(1), source: source, target: context.enemy, abilityName: reaction.displayName, in: &context,
            )
        }
    }
}
