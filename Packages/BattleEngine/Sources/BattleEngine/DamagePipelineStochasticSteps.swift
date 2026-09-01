// swiftformat:disable:all
import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    // swiftlint:disable:next function_body_length - critical resolution keeps seeded rolls and events together
    static func applyDodgeGate(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.applyDodge,
              state.amount > 0,
              context.roster.health(for: state.combatant) > 0,
              state.sourceActorID != nil
        else {
            return
        }
        if state.combatant.role == .enemy {
            return
        }
        let hasEvadeNextHit = context.roster.activeEffects(for: state.combatant).contains {
            if case .evadeNextHit = $0.effect {
                return true
            }
            return false
        }
        let profile = context.modifiers(for: state.combatant.id)
        let autoDodge = profile.triggers.autoDodgeAfterFirstHitPerTurn
            && (context.roster.runtime(for: state.combatant)?.hasTakenAttackHitThisTurn ?? false)
        if let damageKeyword = state.damageKeyword, damageKeyword == .holy,
           let sourceActorID = state.sourceActorID {
            let srcTriggers = context.modifiers(for: sourceActorID).triggers
            if srcTriggers.holyIgnoresBlockAndDodge {
                return
            }
            let partyUnbroken = CombatTriggerEngine.livingPartyTriggers(in: context).unbrokenVow
            if srcTriggers.unbrokenVow || partyUnbroken,
               let src = context.roster.combatant(for: sourceActorID),
               DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: src.combatant)) > 0 {
                return
            }
        }
        let dodged: Bool
        if hasEvadeNextHit || autoDodge {
            dodged = true
        } else {
            let chance = dodgeChance(for: state, in: context)
            dodged = BattleChance.succeeds(probability: chance, using: &context.rng)
        }
        guard dodged else {
            return
        }
        if hasEvadeNextHit {
            ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
                if case .evadeNextHit = $0 {
                    return true
                }
                return false
            }
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
            milestone: nil,
        ))
        state.isDodged = true
        if !autoDodge, !state.options.causedByDodge {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterDodge(
                by: state.combatant,
                attackerID: state.sourceActorID,
                in: &context,
            ))
        }
    }

    static func dodgeChance(
        for state: DamageResolutionState,
        in context: BattleState,
    ) -> Double {
        if state.combatant.role == .enemy {
            return 0
        }
        var chance = 0.10
        let profile = context.modifiers(for: state.combatant.id)
        chance += profile.triggers.dodgeChanceBonus
        chance += context.roster.runtime(for: state.combatant)?.bonusDodgeUntilNextTurn ?? 0
        if context.roster.isDeathsDoorActive(for: state.combatant),
           profile.triggers.deathsDoorDodgeAndDebuffImmunity {
            chance += 0.5
        }
        if let attackerID = state.sourceActorID,
           let attacker = context.roster.combatant(for: attackerID),
           context.roster.activeEffects(for: attacker.combatant).contains(where: {
               $0.effect.keyword == .bleed
           }) {
            chance += profile.triggers.dodgeChanceVsBleedingEnemiesBonus
        }
        if profile.triggers.dodgeChanceBelowHealthPercentThreshold > 0,
           profile.triggers.dodgeChanceBelowHealthPercentBonus > 0,
           context.roster.maxHealth(for: state.combatant) > 0 {
            let percent = Double(context.roster.health(for: state.combatant)) /
                Double(context.roster.maxHealth(for: state.combatant))
            if percent < profile.triggers.dodgeChanceBelowHealthPercentThreshold {
                chance += profile.triggers.dodgeChanceBelowHealthPercentBonus
            }
        }
        return min(0.75, max(0, chance))
    }

    static func applyCriticalGate(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard !state.options.isRetaliation || state.options.isAttackHit,
              state.amount > 0,
              let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword,
              damageKeyword.allowsCriticalHits,
              let actor = context.roster.combatant(for: sourceActorID)
        else {
            return
        }
        if actor.role == .enemy {
            return
        }
        if resolveGuaranteedCrit(to: &state, actor: actor, in: &context) {
            return
        }
        guard CriticalChanceEngine.rollSucceeds(
            keyword: damageKeyword,
            actorID: sourceActorID,
            defender: state.combatant,
            abilityBonus: state.options.abilityCriticalChanceBonus,
            countsBleedingDefender: true,
            in: &context,
        )
        else {
            return
        }
        applyCritical(to: &state)
    }

    // swiftlint:disable:next function_body_length - dodge resolution keeps seeded rolls and events together
    private static func resolveGuaranteedCrit(
        to state: inout DamageResolutionState,
        actor: CombatantRuntime,
        in context: inout BattleState,
    ) -> Bool {
        guard let sourceActorID = state.sourceActorID else {
            return false
        }
        if state.options.guaranteedCritical {
            if actor.role == .enemy {
                return false
            }
            applyCritical(to: &state)
            return true
        }
        if state.options.guaranteedCriticalIfEnemyBuffed,
           context.roster.activeEffects(for: state.combatant).contains(where: \.effect.isRemovableBuff) {
            if actor.role == .enemy {
                return false
            }
            applyCritical(to: &state)
            return true
        }
        if state.options.isAttackHit,
           context.modifiers(for: sourceActorID).triggers.firstAttackGuaranteedCritical,
           context.claimBattleGuard(.surpriseStrike, actorID: actor.combatant.id) {
            if actor.role == .enemy {
                return false
            }
            applyCritical(to: &state)
            return true
        }
        if state.options.isAttackHit,
           context.roster.runtime(for: actor.combatant)?.pendingGuaranteedCriticalAfterDodge == true {
            context.roster.mutateRuntime(for: actor.combatant) {
                $0.pendingGuaranteedCriticalAfterDodge = false
            }
            if actor.role == .enemy {
                return false
            }
            applyCritical(to: &state)
            return true
        }
        if state.options.isAttackHit, state.options.isBasicAttackHit,
           context.roster.runtime(for: actor.combatant)?.pendingBasicGuaranteedCrit == true {
            context.roster.mutateRuntime(for: actor.combatant) {
                $0.pendingBasicGuaranteedCrit = false
            }
            if actor.role == .enemy {
                return false
            }
            applyCritical(to: &state)
            return true
        }
        if context.roster.isDeathsDoorActive(for: actor.combatant),
           context.modifiers(for: sourceActorID).triggers.guaranteedCritWhileOnDeathsDoor {
            if actor.role == .enemy {
                return false
            }
            applyCritical(to: &state)
            return true
        }
        if context.modifiers(for: sourceActorID).triggers.warChest,
           state.damageKeyword == .physical,
           context.gold >= 50 {
            if actor.role == .enemy {
                return false
            }
            applyCritical(to: &state)
            return true
        }
        return false
    }

    static func dodgeChanceCap(for _: Combatant) -> Double {
        0.75
    }

    static func criticalChanceCap(for _: Combatant) -> Double {
        0.75
    }

    private static func applyCritical(to state: inout DamageResolutionState) {
        state.isCritical = true
    }
}
