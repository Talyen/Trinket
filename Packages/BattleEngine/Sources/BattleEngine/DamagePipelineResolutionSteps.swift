import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    // MARK: - Resolution steps

    static func applyDamageBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        if let sourceActorID = state.sourceActorID,
           let damageKeyword = state.damageKeyword,
           let actor = context.roster.combatant(for: sourceActorID) {
            state.statBonus = state.applyStatBonus
                ? actor.primaryStats.statBonusForDamage(keyword: damageKeyword)
                : 0
            state.itemBonus = state.applyItemBonus
                ? outgoingDamageBonus(
                    for: sourceActorID,
                    keyword: damageKeyword,
                    in: context
                )
                : 0
            if state.qualifiesForAmbush,
               let runtime = context.roster.runtime(for: actor.combatant),
               !runtime.hasTriggeredAmbush {
                let ambushBonus = context.modifiers(for: sourceActorID).ambushBonusDamage
                if ambushBonus > 0 {
                    state.itemBonus += ambushBonus
                    context.roster.mutateRuntime(for: actor.combatant) { $0.hasTriggeredAmbush = true }
                }
            }
            if state.applyItemBonus {
                state.itemBonus += CombatReactionEngine.affixDamageBonus(for: state, in: &context)
            }
        }
        state.remaining = state.amount + state.statBonus + state.itemBonus
        state.dealt = state.remaining
    }

    static func applyHexmark(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        CombatReactionEngine.applyHexmarkIfNeeded(to: &state, in: &context)
    }

    static func outgoingDamageBonus(
        for sourceActorID: String,
        keyword: Keyword,
        in context: BattleEngineContext
    ) -> Int {
        var bonus = context.modifiers(for: sourceActorID).damageDealtBonus(for: keyword)
        if sourceActorID == context.roster.companion.id {
            bonus += context.heroModifiers.companionDamageDealtBonus
        }
        return bonus
    }

    static func applyMarkedBonus(
        to state: inout DamageResolutionState,
        in _: inout BattleEngineContext
    ) {
        guard state.sourceActorID != nil else { return }
        let effects = state.activeEffects
        guard effects.contains(where: {
            if case .marked = $0.effect {
                return true
            }; return false
        }) else {
            return
        }

        guard let index = effects.firstIndex(where: {
            if case .marked = $0.effect {
                return true
            }; return false
        }),
            case let .marked(bonus, _) = effects[index].effect
        else { return }

        state.remaining += bonus
        state.dealt += bonus
        state.markedBonusApplied = true
    }

    static func applyItemReduction(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.remaining > 0 else {
            state.buildupDamage = 0
            return
        }
        guard let damageKeyword = state.damageKeyword else {
            state.buildupDamage = state.remaining
            return
        }
        let profile = context.modifiers(for: state.combatant.id)
        let flatReduction = profile.damageTakenFlat(for: damageKeyword)
        if flatReduction > 0 {
            state.remaining = max(0, state.remaining - flatReduction)
        }
        let reduction = profile.damageTakenReduction(for: damageKeyword)
        if reduction > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 - reduction)))
        }
        let vulnerability = profile.damageTakenVulnerability(for: damageKeyword)
        if vulnerability > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 + vulnerability)))
        }
        state.buildupDamage = state.remaining
    }

    static func applyCriticalMultiply(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        _ = context
        guard state.isCritical, state.remaining > 0 else {
            state.buildupDamage = state.remaining
            return
        }
        state.remaining *= 2
        state.dealt = state.remaining
        state.buildupDamage = state.remaining
    }

    /// Toughness-based inherent DR: reduce by `min(effective, floor(incoming/2))`.
    /// No pool, so nothing decays — the reduction applies on every hit.
    static func applyMitigation(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.remaining > 0 else { return }

        let effects = context.roster.activeEffects(for: state.combatant)
        let profile = context.modifiers(for: state.combatant.id)
        var effective = DefensePoolEngine.effectiveToughnessMitigation(
            for: state.combatant,
            effects: effects,
            profile: profile,
            in: context
        )
        if let sourceActorID = state.sourceActorID {
            let ignorePercent = min(1, context.modifiers(for: sourceActorID).ignoreEnemyMitigationPercent)
            if ignorePercent > 0 {
                effective = Int(floor(Double(effective) * (1 - ignorePercent)))
            }
        }
        let maxReduction = state.remaining / 2
        let reduction = min(effective, maxReduction)
        if reduction > 0 {
            state.remaining -= reduction
        }
        state.buildupDamage = state.remaining
    }

    static func applyShieldAbsorption(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        var effects = context.roster.activeEffects(for: state.combatant)
        guard let index = effects.firstIndex(where: {
            if case .shield = $0.effect {
                return true
            }; return false
        }),
            case let .shield(keyword, buffer) = effects[index].effect,
            buffer > 0,
            state.remaining > 0
        else {
            state.activeEffects = effects
            return
        }

        let absorbed = min(state.remaining, buffer)
        state.remaining -= absorbed
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
        var blockBroken = false
        if newBuffer <= 0 {
            effects.remove(at: index)
            blockBroken = true
        } else {
            effects[index] = ActiveEffect(
                id: effects[index].id,
                effect: .shield(keyword, newBuffer),
                remainingTicks: 0,
                sourceActorID: effects[index].sourceActorID
            )
        }
        context.roster.setActiveEffects(effects, for: state.combatant)
        state.activeEffects = effects
        if blockBroken {
            state.damageEvents.append(contentsOf: CombatReactionEngine.afterBlockBroken(
                on: state.combatant,
                in: &context
            ))
            state.activeEffects = context.roster.activeEffects(for: state.combatant)
        }
    }

    static func applyTakeDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        context.roster.setActiveEffects(state.activeEffects, for: state.combatant)
        var lost = 0
        context.roster.mutateRuntime(for: state.combatant) { lost = $0.takeRawDamage(state.remaining) }
        state.healthLost = lost
        if lost > 0 {
            state.damageEvents.append(contentsOf: CombatReactionEngine.afterHealthDropped(
                target: state.combatant,
                in: &context
            ))
        }
    }

    static func applyMarkedConsume(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.markedBonusApplied else { return }

        var effects = context.roster.activeEffects(for: state.combatant)
        guard let index = effects.firstIndex(where: {
            if case .marked = $0.effect {
                return true
            }; return false
        }),
            case let .marked(bonus, _) = effects[index].effect
        else { return }

        effects.remove(at: index)
        context.roster.setActiveEffects(effects, for: state.combatant)
        state.damageEvents.append(context.nextEvent(
            kind: .effect,
            effectKind: .markedConsumed,
            actorName: state.combatant.name,
            abilityName: "Marked",
            target: state.combatant,
            amount: bonus,
            keyword: .physical
        ))
    }

    static func applyDeathsDoor(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        state.damageEvents.append(contentsOf: DeathsDoorEngine.resolveAfterDamage(
            to: state.combatant,
            in: &context
        ))
    }
}
