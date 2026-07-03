import Foundation
import TrinketCore
import TrinketContent

/// Working state threaded through the named damage-resolution steps in
/// `CombatPipeline.resolveDamage`. Each step mutates this struct in place; the
/// orchestrator reads the final `healthLost` and `damageEvents` once the
/// pipeline completes.
package struct DamageResolutionState {
    public let amount: Int
    public let combatant: Combatant
    public let sourceActorID: String?
    public let damageKeyword: Keyword?
    public let applyStatBonus: Bool
    public let applyItemBonus: Bool
    public let applyDodge: Bool

    /// Damage remaining after each step. `BonusStep` initializes this to
    /// `amount + statBonus + itemBonus`; each subsequent step decrements it.
    public var remaining: Int = 0

    /// Total damage after stat + item bonuses, before shields and mitigation.
    public var dealt: Int = 0

    /// Post-mitigation damage used for stun/freeze buildup. Set after
    /// `ItemReductionStep` from `remaining`, before shields absorb damage.
    public var buildupDamage: Int = 0

    /// Stat and item bonus components used by the prevention-buildup step.
    public var statBonus: Int = 0
    public var itemBonus: Int = 0

    /// Working copy of the target's active effects. `ShieldAbsorptionStep`
    /// mutates this copy after mitigation and item reduction; `TakeDamageStep`
    /// commits it back to the roster.
    public var activeEffects: [ActiveEffect] = []

    /// Health actually subtracted by `TakeDamageStep`.
    public var healthLost: Int = 0

    /// Accumulated events emitted by the dodge, shield, and prevention steps.
    public var damageEvents: [ActionEvent] = []

    /// Set to `true` by `DodgeGateStep` when the incoming attack is dodged;
    /// the orchestrator then short-circuits and returns `(0, damageEvents)`.
    public var isDodged: Bool = false
}

/// One step in the damage pipeline. Steps are stateless structs registered
/// in `DamagePipeline.steps` and executed in canonical order.
protocol DamageStep {
    static var stepName: String { get }
    static var phase: DamagePhase { get }
    init()
    mutating func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext)
}

// MARK: - Steps

/// Step 1: gates the entire damage call on a dodge roll. When the roll
/// succeeds, the event stream records a `.dodgeApplied` event and the
/// orchestrator short-circuits.
package struct DodgeGateStep: DamageStep {
    public static let stepName = "DodgeGate"
    public static let phase: DamagePhase = .stochastic

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.applyDodge,
              state.amount > 0,
              context.roster.health(for: state.combatant) > 0,
              state.sourceActorID != nil
        else { return }
        let chance = state.combatant.primaryStats.dodgeChance
        if Double.random(in: 0 ... 1, using: &context.rng) < chance {
            state.damageEvents.append(context.nextEvent(
                kind: .effect,
                effectKind: .dodgeApplied,
                actorName: state.combatant.name,
                abilityName: "Dodge",
                target: state.combatant,
                amount: 0,
                keyword: .dodge,
                appliedEffectSummaries: [],
                milestone: nil
            ))
            state.isDodged = true
        }
    }
}

/// Step 2: computes `statBonus` (per-stat contribution) and `itemBonus`
/// (item-modifier contribution) and adds both to `remaining`.
package struct DamageBonusStep: DamageStep {
    public static let stepName = "DamageBonus"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        if let sourceActorID = state.sourceActorID,
           let damageKeyword = state.damageKeyword,
           let actor = context.roster.combatant(for: sourceActorID) {
            state.statBonus = state.applyStatBonus
                ? actor.primaryStats.statBonusForDamage(keyword: damageKeyword)
                : 0
            state.itemBonus = state.applyItemBonus
                ? context.modifiers(for: sourceActorID).damageDealtBonus(for: damageKeyword)
                : 0
        }
        state.remaining = state.amount + state.statBonus + state.itemBonus
        state.dealt = state.remaining
    }
}

/// Step 5: iterates the target's active shield effects, absorbing as much
/// of `remaining` as each shield can cover, emitting `.shieldAbsorbed`
/// events, and mutating the effects list. Depleted shields are removed.
package struct ShieldAbsorptionStep: DamageStep {
    public static let stepName = "ShieldAbsorption"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        var effects = context.roster.activeEffects(for: state.combatant)
        var shieldIndexes: [Int] = []

        for (index, ae) in effects.enumerated() {
            if case let .shield(keyword, buffer, _) = ae.effect {
                let absorbed = min(state.remaining, buffer)
                state.remaining -= absorbed
                if absorbed > 0 {
                    state.damageEvents.append(context.nextEvent(
                        kind: .effect,
                        effectKind: .shieldAbsorbed,
                        actorName: keyword.rawValue,
                        abilityName: keyword.rawValue,
                        target: state.combatant,
                        amount: absorbed,
                        keyword: keyword,
                        appliedEffectSummaries: [],
                        milestone: nil
                    ))
                    let newBuffer = buffer - absorbed
                    let newEffect: Effect = .shield(keyword, newBuffer, ae.effect.durationTicks)
                    effects[index] = ActiveEffect(
                        id: ae.id,
                        effect: newEffect,
                        remainingTicks: ae.remainingTicks
                    )
                    if newBuffer <= 0 {
                        shieldIndexes.append(index)
                    }
                }
            }
        }

        for index in shieldIndexes.reversed() {
            effects.remove(at: index)
        }
        state.activeEffects = effects
    }
}

/// Step 3: applies armor (from active `.mitigation` effects) plus passive
/// toughness mitigation, capped at 100%. Runs before item reduction and shields.
package struct MitigationStep: DamageStep {
    public static let stepName = "Mitigation"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        let effects = context.roster.activeEffects(for: state.combatant)
        let armorPct = effects.reduce(0.0) { sum, ae in
            if case let .mitigation(_, p, _) = ae.effect { return sum + p }
            return sum
        }
        let toughnessPct = state.combatant.primaryStats.toughnessMitigationPct
        let combinedPct = max(0, min(1, armorPct + toughnessPct))
        if combinedPct > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 - combinedPct)))
        }
    }
}

/// Step 4: applies the target's `damageTakenReduction` for the damage
/// keyword, if any. Records `buildupDamage` for stun/freeze buildup after
/// mitigation and item reduction, but before shields absorb damage.
package struct ItemReductionStep: DamageStep {
    public static let stepName = "ItemReduction"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        _ = context
        guard state.remaining > 0 else {
            state.buildupDamage = 0
            return
        }
        guard let damageKeyword = state.damageKeyword else {
            state.buildupDamage = state.remaining
            return
        }
        let reduction = context.modifiers(for: state.combatant.id).damageTakenReduction(for: damageKeyword)
        if reduction > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 - reduction)))
        }
        state.buildupDamage = state.remaining
    }
}

/// Step 6: writes the mutated effects list back to the roster and calls
/// `takeRawDamage` on the target runtime.
package struct TakeDamageStep: DamageStep {
    public static let stepName = "TakeDamage"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        context.roster.setActiveEffects(state.activeEffects, for: state.combatant)
        var lost = 0
        context.roster.mutateRuntime(for: state.combatant) { lost = $0.takeRawDamage(state.remaining) }
        state.healthLost = lost
    }
}

/// Step 7: heals the attacker when `healthLost > 0`, leech is active, and
/// the hit was not self-inflicted.
package struct LeechStep: DamageStep {
    public static let stepName = "Leech"
    public static let phase: DamagePhase = .post

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.healthLost > 0,
              let sourceActorID = state.sourceActorID,
              sourceActorID != state.combatant.id
        else { return }
        let leechOutcome = HealingEngine.leechFromDamage(
            state.healthLost,
            sourceActorID: sourceActorID,
            in: &context
        )
        state.damageEvents.append(contentsOf: leechOutcome.events)
    }
}

/// Step 8: for `.stun` or `.freeze` keywords, applies a prevention
/// buildup against the target using post-mitigation, pre-shield damage.
package struct ControlMeterStep: DamageStep {
    public static let stepName = "ControlMeter"
    public static let phase: DamagePhase = .post

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.buildupDamage > 0,
              let damageKeyword = state.damageKeyword,
              damageKeyword == .stun || damageKeyword == .freeze,
              context.roster.health(for: state.combatant) > 0
        else { return }
        state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
            state.buildupDamage,
            keyword: damageKeyword,
            to: state.combatant,
            sourceActorID: state.sourceActorID,
            in: &context
        ))
    }
}

/// Backward-compatible alias for `DamagePipeline.canonicalNames`.
package enum DamageSteps {
    public static var canonicalNames: [String] {
        DamagePipeline.canonicalNames
    }
}
