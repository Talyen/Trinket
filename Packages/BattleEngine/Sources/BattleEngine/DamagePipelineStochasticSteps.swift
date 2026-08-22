import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    // MARK: - Stochastic steps

    static func applyDodgeGate(
        to state: inout DamageResolutionState,
        in context: inout BattleState
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
        let profile = context.modifiers(for: state.combatant.id)
        let autoDodge = profile.triggers.autoDodgeAfterFirstHitPerTurn
            && (context.roster.runtime(for: state.combatant)?.hasTakenAttackHitThisTurn ?? false)
        if let damageKeyword = state.damageKeyword, damageKeyword == .holy,
           let sourceActorID = state.sourceActorID,
           context.modifiers(for: sourceActorID).triggers.holyIgnoresBlockAndDodge {
            return
        }
        let dodged: Bool
        if hasEvadeNextHit || autoDodge {
            dodged = true
        } else {
            let chance = dodgeChance(for: state, in: context)
            dodged = BattleChance.succeeds(probability: chance, using: &context.rng)
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
        // Evasive Pack auto-dodges do not trigger on-Dodge punish talents (Riposte).
        // Hits caused by a dodge must not re-enter afterDodge (Whiplash loops).
        if !autoDodge, !state.causedByDodge {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterDodge(
                by: state.combatant,
                attackerID: state.sourceActorID,
                in: &context
            ))
        }
    }

    static func dodgeChance(
        for state: DamageResolutionState,
        in context: BattleState
    ) -> Double {
        let attackerAgility = state.sourceActorID
            .flatMap { context.roster.combatant(for: $0) }?
            .primaryStats.agility ?? 0

        let baseChance: Double = if state.combatant.role == .enemy {
            state.combatant.primaryStats.contestedEnemyDodgeChance(
                againstAttackerAgility: attackerAgility
            )
        } else {
            state.combatant.primaryStats.contestedDodgeChance(
                againstAttackerAgility: attackerAgility
            )
        }
        var chance = baseChance
        let profile = context.modifiers(for: state.combatant.id)
        chance += profile.triggers.dodgeChanceBonus
        chance += context.roster.runtime(for: state.combatant)?.bonusDodgeUntilNextTurn ?? 0
        // Ashen Ward: +50% Dodge chance while on Death's Door.
        if context.roster.isDeathsDoorActive(for: state.combatant),
           profile.triggers.deathsDoorDodgeAndDebuffImmunity {
            chance += 0.5
        }
        if let attackerID = state.sourceActorID,
           let attacker = context.roster.combatant(for: attackerID),
           context.roster.activeEffects(for: attacker.combatant).contains(where: { $0.effect.keyword == .bleed }) {
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
        return min(dodgeChanceCap(for: state.combatant), max(0, chance))
    }

    static func applyCriticalGate(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard !state.isRetaliation || state.isAttackHit,
              state.amount > 0,
              let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword,
              damageKeyword.allowsCriticalHits,
              let actor = context.roster.combatant(for: sourceActorID)
        else { return }

        if resolveGuaranteedCrit(to: &state, actor: actor, in: &context) {
            return
        }

        var chance = actor.primaryStats.contestedCriticalChance(
            for: damageKeyword,
            againstDefenderToughness: state.combatant.primaryStats.toughness
        )
        chance += state.abilityCriticalChanceBonus
        chance += context.modifiers(for: sourceActorID).triggers.criticalChanceBonus
        chance += partyCritChanceBonus(actor: actor, in: context)
        if context.roster.activeEffects(for: state.combatant).contains(where: { $0.effect.keyword == .bleed }) {
            chance += context.modifiers(for: sourceActorID).triggers.critChancePerBleedingEnemy
        }

        let sourceEffects = context.roster.activeEffects(for: actor.combatant)
        for active in sourceEffects {
            if case let .criticalChanceBonus(bonus, _) = active.effect {
                chance += bonus
            }
        }

        chance = min(criticalChanceCap(for: actor.combatant), max(0, chance))
        guard BattleChance.succeeds(probability: chance, using: &context.rng) else { return }
        applyCritical(to: &state)
    }

    /// Party-wide crit chance bonuses (Pack Bloodlust, Man's Best Friend, Treasure Hoard).
    private static func partyCritChanceBonus(
        actor: CombatantRuntime,
        in context: BattleState
    ) -> Double {
        guard actor.role != .enemy, context.roster.companion.isAlive else { return 0 }
        let companionTriggers = context.companionModifiers.triggers
        var bonus: Double = 0
        if companionTriggers.partyCritChanceWhileCompanionAboveHealthThreshold > 0,
           context.roster.maxHealth(for: context.roster.companion.combatant) > 0,
           Double(context.roster.health(for: context.roster.companion.combatant))
           / Double(context.roster.maxHealth(for: context.roster.companion.combatant))
           >= companionTriggers.partyCritChanceWhileCompanionAboveHealthThreshold {
            bonus += companionTriggers.partyCritChanceWhileCompanionAboveHealthBonus
        }
        if actor.role == .hero, companionTriggers.heroCritChanceWhileCompanionAlive > 0 {
            bonus += companionTriggers.heroCritChanceWhileCompanionAlive
        }
        // Treasure Hoard: while the Retriever carries enough Gold, the party
        // gains bonus Critical Hit chance.
        if companionTriggers.partyCritChanceWhileGoldAbove > 0,
           context.gold >= companionTriggers.partyCritChanceWhileGoldAbove {
            bonus += companionTriggers.partyCritChanceWhileGoldAboveBonus
        }
        return bonus
    }

    /// Guaranteed-crit paths that bypass the soft cap and the RNG roll.
    private static func resolveGuaranteedCrit(
        to state: inout DamageResolutionState,
        actor: CombatantRuntime,
        in context: inout BattleState
    ) -> Bool {
        guard let sourceActorID = state.sourceActorID else { return false }
        // "Always Criticals if the enemy has a buff" / next-strike critical are actually always.
        if state.guaranteedCritical {
            applyCritical(to: &state)
            return true
        }
        if state.guaranteedCriticalIfEnemyBuffed,
           context.roster.activeEffects(for: state.combatant).contains(where: \.effect.isRemovableBuff) {
            applyCritical(to: &state)
            return true
        }
        // Surprise Strike: this combatant's first attack in battle is a guaranteed critical.
        if state.isAttackHit,
           context.modifiers(for: sourceActorID).triggers.firstAttackGuaranteedCritical,
           context.claimBattleGuard(.surpriseStrike, actorID: actor.combatant.id) {
            applyCritical(to: &state)
            return true
        }
        // Flanking Position: a dodge-empowered next party hit is a guaranteed critical.
        if state.isAttackHit,
           context.roster.runtime(for: actor.combatant)?.pendingGuaranteedCriticalAfterDodge == true {
            context.roster.mutateRuntime(for: actor.combatant) { $0.pendingGuaranteedCriticalAfterDodge = false }
            applyCritical(to: &state)
            return true
        }
        // Taste for Blood: this combatant's next basic attack is a guaranteed critical.
        if state.isAttackHit, state.isBasicAttackHit,
           context.roster.runtime(for: actor.combatant)?.pendingBasicGuaranteedCrit == true {
            context.roster.mutateRuntime(for: actor.combatant) { $0.pendingBasicGuaranteedCrit = false }
            applyCritical(to: &state)
            return true
        }
        // Deathly Wrath: guaranteed criticals while on Death's Door.
        if context.roster.isDeathsDoorActive(for: actor.combatant),
           context.modifiers(for: sourceActorID).triggers.guaranteedCritWhileOnDeathsDoor {
            applyCritical(to: &state)
            return true
        }
        return false
    }

    /// Dodge soft cap for the defending combatant (enemy archetype vs player 75%).
    static func dodgeChanceCap(for combatant: Combatant) -> Double {
        guard combatant.role == .enemy else {
            return PrimaryStats.playerChanceCap
        }
        return combatant.growthArchetype.enemyDodgeChanceCap
    }

    /// Crit soft cap for the attacking combatant (enemy archetype vs player 75%).
    static func criticalChanceCap(for combatant: Combatant) -> Double {
        guard combatant.role == .enemy else {
            return PrimaryStats.playerChanceCap
        }
        return combatant.growthArchetype.enemyCriticalChanceCap
    }

    private static func applyCritical(to state: inout DamageResolutionState) {
        state.isCritical = true
    }
}
