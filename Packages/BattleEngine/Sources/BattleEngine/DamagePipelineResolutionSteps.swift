import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    // MARK: - Resolution steps

    static func applyDamageBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        if let sourceActorID = state.sourceActorID,
           let damageKeyword = state.damageKeyword,
           let actor = context.roster.combatant(for: sourceActorID) {
            state.statBonus = state.applyStatBonus
                ? CombatRounding.scaled(state.amount, multiplier: actor.primaryStats.statDamageBonusPercent(keyword: damageKeyword))
                : 0
            state.itemBonus = state.applyItemBonus
                ? outgoingDamageBonus(
                    for: sourceActorID,
                    keyword: damageKeyword,
                    in: context
                )
                : 0
            if state.qualifiesForAmbush,
               var runtime = context.roster.runtime(for: actor.combatant) {
                let profile = context.modifiers(for: sourceActorID)
                var didUpdateRuntime = false
                if !runtime.hasTriggeredAmbush, profile.triggers.ambushBonusDamage > 0 {
                    state.itemBonus += profile.triggers.ambushBonusDamage
                    runtime.hasTriggeredAmbush = true
                    didUpdateRuntime = true
                }
                if !runtime.hasTriggeredFirstHitBonus, profile.triggers.firstHitDoubleDamage {
                    state.itemBonus += (state.amount + state.statBonus)
                    runtime.hasTriggeredFirstHitBonus = true
                    didUpdateRuntime = true
                }
                if didUpdateRuntime {
                    context.roster.update(runtime)
                }
            }
            if state.applyItemBonus {
                state.itemBonus += CombatTriggerEngine.damageBonus(for: state, in: &context)
            }
        }
        state.remaining = state.amount + state.statBonus + state.itemBonus
        if state.applyItemBonus,
           let sourceActorID = state.sourceActorID,
           let damageKeyword = state.damageKeyword {
            let percent = context.modifiers(for: sourceActorID).damageDealtPercent(for: damageKeyword)
            let percentBonus = CombatRounding.scaled(max(0, state.remaining), multiplier: percent)
            state.itemBonus += percentBonus
            state.remaining += percentBonus
        }
        state.dealt = state.remaining
    }

    static func applyFightPacing(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.remaining > 0 else { return }
        state.remaining = context.paced(state.remaining, sourceActorID: state.sourceActorID)
        state.dealt = state.remaining
    }

    static func outgoingDamageBonus(
        for sourceActorID: String,
        keyword: Keyword,
        in context: BattleState
    ) -> Int {
        let profile = context.modifiers(for: sourceActorID)
        var bonus = profile.damageDealtBonus(for: keyword)
        if sourceActorID == context.roster.companion.id {
            bonus += context.heroModifiers.companionDamageDealtBonus
        }
        if profile.triggers.damageIncreasesEveryOtherTurn {
            bonus += context.turnCount / 2
        }
        return bonus
    }

    static func applyMarkedBonus(
        to state: inout DamageResolutionState,
        in _: inout BattleState
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
        in context: inout BattleState
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
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 - reduction)
        }
        let vulnerability = profile.damageTakenVulnerability(for: damageKeyword)
        if vulnerability > 0 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + vulnerability)
        }
        state.buildupDamage = state.remaining
    }

    static func applyCriticalMultiply(
        to state: inout DamageResolutionState,
        in context: inout BattleState
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

    /// Toughness-based inherent DR: percentage reduction from Toughness (K = 80)
    /// plus flat passive mitigation from traits/affixes.
    static func applyMitigation(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.remaining > 0 else { return }

        let effects = context.roster.activeEffects(for: state.combatant)
        let profile = context.modifiers(for: state.combatant.id)
        var effectivePercent = DefensePoolEngine.effectiveToughnessMitigationPercent(
            for: state.combatant,
            effects: effects,
            profile: profile,
            in: context
        )
        if let sourceActorID = state.sourceActorID {
            let ignorePercent = min(1, context.modifiers(for: sourceActorID).triggers.ignoreEnemyMitigationPercent)
            if ignorePercent > 0 {
                effectivePercent *= (1 - ignorePercent)
            }
        }

        var remaining = state.remaining
        if profile.triggers.passiveMitigationFlat > 0 {
            remaining = max(0, remaining - profile.triggers.passiveMitigationFlat)
        }

        if effectivePercent > 0 {
            remaining = CombatRounding.scaled(remaining, multiplier: 1.0 - effectivePercent)
        }

        state.remaining = remaining
        state.buildupDamage = state.remaining
    }

    static func applyShieldAbsorption(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        var effects = context.roster.activeEffects(for: state.combatant)
        guard let index = effects.firstIndex(where: {
            if case .shield = $0.effect {
                return true
            }; return false
        }),
            case let .shield(keyword, buffer) = effects[index].effect,
            buffer > 0,
            state.remaining > 0,
            !state.isHealthCost
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
                remainingTurns: 0,
                sourceActorID: effects[index].sourceActorID
            )
        }
        context.roster.setActiveEffects(effects, for: state.combatant)
        state.activeEffects = effects
        if blockBroken {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterBlockBroken(
                on: state.combatant,
                in: &context
            ))
            state.activeEffects = context.roster.activeEffects(for: state.combatant)
        }
    }

    static func applyTakeDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        context.roster.setActiveEffects(state.activeEffects, for: state.combatant)
        var lost = 0
        context.roster.mutateRuntime(for: state.combatant) { lost = $0.takeRawDamage(state.remaining) }
        state.healthLost = lost
        if lost > 0 {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterHealthDropped(
                target: state.combatant,
                in: &context
            ))
        }
    }

    static func applyMarkedConsume(
        to state: inout DamageResolutionState,
        in context: inout BattleState
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
        in context: inout BattleState
    ) {
        state.damageEvents.append(contentsOf: DeathsDoorEngine.resolveAfterDamage(
            to: state.combatant,
            in: &context
        ))
    }
}
