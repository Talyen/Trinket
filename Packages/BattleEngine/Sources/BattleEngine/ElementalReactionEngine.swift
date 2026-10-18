import TrinketContent
import TrinketCore

struct ElementalReactionState: Hashable {
    var shatter = 0
    var frostfire = 0
    var rupture = 0
    var freezeGeneration = 0
    var stunGeneration = 0
    var pendingPoisonTick: Int?
    var lastPoisonPhase: Int?
    var toxicShock = 0
    var consecratedBy: String?

    var hasStatusPreparation: Bool {
        shatter != 0 || frostfire != 0 || rupture != 0 || consecratedBy != nil
    }

    mutating func expire(with effects: [ActiveEffect]) {
        if shatter != 0 || frostfire != 0, !effects.contains(where: { $0.keyword == .freeze && $0.isAwaitingActionSkip }) {
            shatter = 0
            frostfire = 0
        }
        if rupture != 0, !effects.contains(where: { $0.keyword == .stun && $0.isAwaitingActionSkip }) {
            rupture = 0
        }
        if consecratedBy != nil, !effects.contains(where: { $0.effect.isBleed && $0.remainingTurns > 0 }) {
            consecratedBy = nil
        }
    }
}

struct ElementalReactionHit: Equatable {
    let sourceID: String
    let keyword: Keyword
    let before: DamageTargetStatus
    let prepared: ElementalReactionState
    let poison: Int
    var shatter = 0
    var ignited = false
}

struct ToxicShockPayoff {
    let amount: Int
    let sourceID: String?
}

struct NaturalReactionPhase {
    let turn: Int
    var burn = 0
    var poison = 0
    var bleed = 0
    var bleedSourceID: String?
    var consecratedBy: String?
    var beganBleed = false
}

enum ElementalReactionEngine {
    /// Divide before adding: two Int.max facts still receive one exact rounding.
    static func bonus(_ amounts: Int...) -> Int {
        let whole = amounts.reduce(0) { SaturatedArithmetic.saturatingAdd($0, max(0, $1) / 4) }
        let remainder = amounts.reduce(0) { $0 + max(0, $1) % 4 }
        return max(1, SaturatedArithmetic.saturatingAdd(whole, (remainder + 2) / 4))
    }

    static func capture(_ request: DamageRequest, in context: BattleState) -> ElementalReactionHit? {
        guard request.options.canInitiateElementalReaction, request.target == context.enemy,
              let sourceID = request.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.isAlive, source.role != .enemy,
              let keyword = request.keyword else { return nil }
        // Poison only feeds the burn venomflash payoff; skip the scan otherwise.
        let poison = if keyword == .burn {
            context.roster.activeEffects(for: context.enemy).reduce(0) { sum, active in
                guard case let .poison(potency) = active.effect else { return sum }
                return SaturatedArithmetic.saturatingAdd(sum, potency)
            }
        } else {
            0
        }
        return ElementalReactionHit(
            sourceID: sourceID, keyword: keyword,
            before: DamageTargetStatus(for: context.enemy, in: context),
            prepared: context.roster.enemy.reactions, poison: poison,
        )
    }

    static func prepareControl(
        _ keyword: Keyword, target: Combatant, healthDamage: Int, sourceID: String?, in context: inout BattleState,
    ) {
        guard target == context.enemy else { return }
        if keyword == .stun, context.roster.enemy.reactions.toxicShock > 0 {
            context.resolution.pendingToxicShocks.append(ToxicShockPayoff(
                amount: context.roster.enemy.reactions.toxicShock, sourceID: sourceID,
            ))
            context.roster.mutateRuntime(for: target) { $0.reactions.toxicShock = 0 }
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
              context.roster.enemy.reactions.shatter > 0 else { return }
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
        let current = context.roster.enemy.reactions
        var payoffs: [(CombatReaction, Int)] = []
        if hit.shatter > 0 {
            payoffs.append((.shatter, hit.shatter))
        }
        let sameFreeze = current.freezeGeneration == hit.prepared.freezeGeneration
        if hit.keyword == .burn, hit.before.isFrozen, outcome.healthLost > 0,
           sameFreeze, current.frostfire > 0 {
            payoffs.append((.frostfire, current.frostfire))
        } else if hit.keyword == .freeze, !hit.before.isFrozen, hit.before.isBurning,
                  outcome.flags.contains(.controlTriggered), current.frostfire > 0,
                  current.freezeGeneration == SaturatedArithmetic.saturatingAdd(hit.prepared.freezeGeneration, 1) {
            payoffs.append((.frostfire, current.frostfire))
        }
        if hit.keyword == .bleed, outcome.healthLost > 0, hit.before.isStunned,
           current.stunGeneration == hit.prepared.stunGeneration, current.rupture > 0 {
            payoffs.append((.rupture, current.rupture))
        }
        if hit.keyword == .burn, outcome.healthLost > 0, !hit.before.isBurning, hit.poison > 0,
           hit.ignited || context.roster.hasAffliction(.burn, on: context.enemy) {
            payoffs.append((.venomflash, bonus(hit.poison)))
        }
        for (reaction, amount) in payoffs {
            guard !context.isBattleOver, context.roster.combatant(for: hit.sourceID)?.isAlive == true else { break }
            context.roster.mutateRuntime(for: context.enemy) { runtime in
                switch reaction {
                case .shatter, .toxicShock, .consecration, .bloodboil, .venomflash: break
                case .frostfire: runtime.reactions.frostfire = 0
                case .rupture: runtime.reactions.rupture = 0
                }
            }
            await release(reaction, amount: amount, sourceID: hit.sourceID, in: &context)
        }
    }

    static func finishControl(in context: inout BattleState) async {
        guard context.resolution.depth(.damage) == 0, context.resolution.controlDepth == 0,
              !context.uniques.isDrainingOutOfTurnAttacks else { return }
        let pending = context.resolution.pendingToxicShocks
        context.resolution.pendingToxicShocks.removeAll()
        for payoff in pending {
            guard !context.isBattleOver else { break }
            if let sourceID = payoff.sourceID, context.roster.combatant(for: sourceID)?.isAlive != true {
                context.roster.mutateRuntime(for: context.enemy) { runtime in
                    runtime.reactions.toxicShock = SaturatedArithmetic.saturatingAdd(runtime.reactions.toxicShock, payoff.amount)
                }
                continue
            }
            await release(.toxicShock, amount: payoff.amount, sourceID: payoff.sourceID, in: &context)
        }
    }

    static func captureAttachment(
        _ hit: ElementalReactionHit,
        outcome: CombatOutcome,
        in context: inout BattleState,
    ) -> ElementalReactionHit {
        var captured = hit
        captured.ignited = context.roster.hasAffliction(.burn, on: context.enemy)
        guard !outcome.isDodged, !context.isBattleOver,
              context.roster.combatant(for: hit.sourceID)?.isAlive == true else { return captured }
        if hit.keyword == .holy, outcome.healthLost > 0, hit.before.isBleeding,
           context.roster.hasAffliction(.bleed, on: context.enemy) {
            context.roster.mutateRuntime(for: context.enemy) { runtime in
                if runtime.reactions.consecratedBy == nil {
                    runtime.reactions.consecratedBy = hit.sourceID
                }
            }
        }
        return captured
    }

    static func beginBleed(in context: inout BattleState) {
        guard var phase = context.resolution.naturalReactionPhase, !phase.beganBleed else { return }
        phase.beganBleed = true
        phase.consecratedBy = context.roster.enemy.reactions.consecratedBy
        context.roster.mutateRuntime(for: context.enemy) { $0.reactions.consecratedBy = nil }
        context.resolution.naturalReactionPhase = phase
    }

    static func recordNaturalTick(_ keyword: Keyword, amount: Int, sourceID: String?, in context: inout BattleState) {
        guard amount > 0, var phase = context.resolution.naturalReactionPhase else { return }
        if keyword == .burn {
            phase.burn = SaturatedArithmetic.saturatingAdd(phase.burn, amount)
        } else if keyword == .poison {
            phase.poison = SaturatedArithmetic.saturatingAdd(phase.poison, amount)
        } else if keyword == .bleed {
            phase.bleed = SaturatedArithmetic.saturatingAdd(phase.bleed, amount)
            phase.bleedSourceID = sourceID
        }
        context.resolution.naturalReactionPhase = phase
        if keyword == .poison, phase.poison > 0 {
            context.roster.mutateRuntime(for: context.enemy) { runtime in
                guard runtime.reactions.lastPoisonPhase != phase.turn else { return }
                runtime.reactions.lastPoisonPhase = phase.turn
                if let pending = runtime.reactions.pendingPoisonTick {
                    runtime.reactions.toxicShock = SaturatedArithmetic.saturatingAdd(
                        runtime.reactions.toxicShock,
                        bonus(pending, phase.poison),
                    )
                    runtime.reactions.pendingPoisonTick = nil
                } else {
                    runtime.reactions.pendingPoisonTick = phase.poison
                }
            }
        }
    }

    static func finishNaturalPhase(_ phase: NaturalReactionPhase, in context: inout BattleState) async {
        if phase.bleed > 0, let source = phase.consecratedBy {
            await release(.consecration, amount: bonus(phase.bleed), sourceID: source, in: &context)
        }
        if phase.burn > 0, phase.bleed > 0 {
            await release(.bloodboil, amount: bonus(phase.burn, phase.bleed), sourceID: phase.bleedSourceID, in: &context)
        }
    }

    private static func announce(_ reaction: CombatReaction, sourceID: String?, in context: inout BattleState) {
        context.nextEvent(
            kind: .reaction(reaction), source: context.eventSource(actorID: sourceID, fallback: context.enemy),
            abilityName: reaction.displayName, target: context.enemy, amount: 0, keyword: reaction.damageKeyword,
        )
    }

    private static func release(_ reaction: CombatReaction, amount: Int, sourceID: String?, in context: inout BattleState) async {
        guard amount > 0, !context.isBattleOver else { return }
        if reaction != .shatter {
            announce(reaction, sourceID: sourceID, in: &context)
        }
        let outcome = await context.resolveDamage(DamageRequest(
            amount: amount, target: context.enemy, keyword: reaction.damageKeyword,
            sourceActorID: sourceID, options: .elementalReaction,
        ))
        context.nextEvent(
            kind: .abilityDamage, source: context.eventSource(actorID: sourceID, fallback: context.enemy),
            abilityName: reaction.displayName, target: context.enemy, amount: outcome.healthLost, keyword: reaction.damageKeyword,
        )
    }
}
