import Foundation
import TrinketCore
import TrinketContent

/// Working state threaded through the named damage-resolution steps in
/// `CombatPipeline.applyDamage`. Each step mutates this struct in place; the
/// orchestrator reads the final `healthLost` and `damageEvents` once the
/// pipeline completes.
public struct DamageResolutionState {
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

    /// Post-mitigation damage used for prevention buildup. Set after
    /// `ItemReductionStep` from `remaining`.
    public var postMitigationDamage: Int = 0

    /// Stat and item bonus components used by the prevention-buildup step.
    public var statBonus: Int = 0
    public var itemBonus: Int = 0

    /// Working copy of the target's active effects. Read once by
    /// `ShieldAbsorptionStep` (which mutates it), then by `MitigationStep`
    /// (which only reads it), and finally committed back to the roster by
    /// `TakeDamageStep`.
    public var activeEffects: [ActiveEffect] = []

    /// Health actually subtracted by `TakeDamageStep`.
    public var healthLost: Int = 0

    /// Accumulated events emitted by the dodge, shield, and prevention steps.
    public var damageEvents: [ActionEvent] = []

    /// Set to `true` by `DodgeGateStep` when the incoming attack is dodged;
    /// the orchestrator then short-circuits and returns `(0, damageEvents)`.
    public var isDodged: Bool = false
}

/// One step in the `applyDamage` pipeline. Steps are stateless structs
/// invoked in canonical order by `CombatPipeline.applyDamage`. The canonical
/// list lives in `DamageSteps.canonicalNames` and is locked by
/// `CombatPipelineTests.testDamageStepsRunInCanonicalOrder`.
protocol DamageStep {
    mutating func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext)
}

// MARK: - Steps

/// Step 1: gates the entire damage call on a dodge roll. When the roll
/// succeeds, the event stream records a `.dodgeApplied` event and the
/// orchestrator short-circuits.
public struct DodgeGateStep: DamageStep {
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
public struct DamageBonusStep: DamageStep {
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

/// Step 3: iterates the target's active shield effects, absorbing as much
/// of `remaining` as each shield can cover, emitting `.shieldAbsorbed`
/// events, and mutating the effects list. Depleted shields are removed.
public struct ShieldAbsorptionStep: DamageStep {
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

/// Step 4: applies armor (from active `.mitigation` effects) plus passive
/// toughness mitigation, capped at 100%.
public struct MitigationStep: DamageStep {
    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        _ = context
        let armorPct = state.activeEffects.reduce(0.0) { sum, ae in
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

/// Step 5: applies the target's `damageTakenReduction` for the damage
/// keyword, if any. Records `postMitigationDamage` for prevention buildup.
public struct ItemReductionStep: DamageStep {
    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard let damageKeyword = state.damageKeyword, state.remaining > 0 else {
            state.postMitigationDamage = state.remaining
            return
        }
        let reduction = context.modifiers(for: state.combatant.id).damageTakenReduction(for: damageKeyword)
        if reduction > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 - reduction)))
        }
        state.postMitigationDamage = state.remaining
    }
}

/// Step 6: writes the mutated effects list back to the roster and calls
/// `takeRawDamage` on the target runtime.
public struct TakeDamageStep: DamageStep {
    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        context.roster.setActiveEffects(state.activeEffects, for: state.combatant)
        var lost = 0
        context.roster.mutateRuntime(for: state.combatant) { lost = $0.takeRawDamage(state.remaining) }
        state.healthLost = lost
    }
}

/// Step 7: heals the attacker when `healthLost > 0`, leech is active, and
/// the hit was not self-inflicted.
public struct LeechStep: DamageStep {
    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.healthLost > 0,
              let sourceActorID = state.sourceActorID,
              sourceActorID != state.combatant.id
        else { return }
        state.damageEvents.append(contentsOf: CombatPipeline.applyLeechFromDamage(
            state.healthLost,
            sourceActorID: sourceActorID,
            in: &context
        ))
    }
}

/// Step 8: for `.stun` or `.freeze` keywords, applies a prevention
/// buildup against the target using post-mitigation damage.
public struct PreventionBuildupStep: DamageStep {
    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.postMitigationDamage > 0,
              let damageKeyword = state.damageKeyword,
              damageKeyword == .stun || damageKeyword == .freeze,
              context.roster.health(for: state.combatant) > 0
        else { return }
        state.damageEvents.append(contentsOf: CombatPipeline.applyPreventionBuildup(
            state.postMitigationDamage,
            keyword: damageKeyword,
            to: state.combatant,
            sourceActorID: state.sourceActorID,
            in: &context
        ))
    }
}

/// Canonical list of damage-step names, in the order they are invoked by
/// `CombatPipeline.applyDamage`. Used by
/// `CombatPipelineTests.testDamageStepsRunInCanonicalOrder` to lock the
/// order.
public enum DamageSteps {
    public static let canonicalNames: [String] = [
        "DodgeGate",
        "DamageBonus",
        "ShieldAbsorption",
        "Mitigation",
        "ItemReduction",
        "TakeDamage",
        "Leech",
        "PreventionBuildup"
    ]
}
