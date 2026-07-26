import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    // MARK: - Stochastic steps

    static func applyDodgeGate(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.applyDodge,
              state.amount > 0,
              context.roster.health(for: state.combatant) > 0,
              state.sourceActorID != nil
        else { return }

        let hasEvadeNextHit = context.roster.activeEffects(for: state.combatant).contains {
            if case .evadeNextHit = $0.effect {
                return true
            }
            return false
        }
        let dodged: Bool
        if hasEvadeNextHit {
            dodged = true
        } else {
            let chance = dodgeChance(for: state, in: context)
            dodged = Double.random(in: 0 ... 1, using: &context.rng) < chance
        }
        guard dodged else { return }

        if hasEvadeNextHit {
            var effects = context.roster.activeEffects(for: state.combatant)
            effects.removeAll {
                if case .evadeNextHit = $0.effect {
                    return true
                }
                return false
            }
            context.roster.setActiveEffects(effects, for: state.combatant)
        }

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
        state.damageEvents.append(contentsOf: CombatReactionEngine.afterDodge(by: state.combatant, in: &context))
    }

    static func dodgeChance(
        for state: DamageResolutionState,
        in context: BattleEngineContext
    ) -> Double {
        var chance = state.combatant.primaryStats.dodgeChance
        let profile = context.modifiers(for: state.combatant.id)
        chance += profile.triggers.dodgeChanceBonus
        return min(0.75, chance)
    }

    static func applyCriticalGate(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.amount > 0,
              let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword,
              damageKeyword.allowsCriticalHits,
              let actor = context.roster.combatant(for: sourceActorID)
        else { return }

        var chance = actor.primaryStats.criticalChance(for: damageKeyword)
        chance += state.abilityCriticalChanceBonus

        let sourceEffects = context.roster.activeEffects(for: actor.combatant)
        for active in sourceEffects {
            if case let .criticalChanceBonus(bonus, _) = active.effect {
                chance += bonus
            }
        }

        // Guaranteed crits bypass the 0.75 soft cap and the RNG roll so
        // "always Criticals if the enemy has a buff" / next-strike critical are actually always.
        if state.guaranteedCritical {
            applyCritical(to: &state)
            return
        }
        if state.guaranteedCriticalIfEnemyBuffed,
           context.roster.activeEffects(for: state.combatant).contains(where: \.effect.isRemovableBuff) {
            applyCritical(to: &state)
            return
        }

        chance = min(0.75, chance)
        guard Double.random(in: 0 ... 1, using: &context.rng) < chance else { return }
        applyCritical(to: &state)
    }

    private static func applyCritical(to state: inout DamageResolutionState) {
        state.isCritical = true
    }
}
