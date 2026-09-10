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
        if DefensePoolEngine.shouldIgnoreDodge(
            keyword: state.damageKeyword,
            sourceActorID: state.sourceActorID,
            in: context
        ) {
            return
        }
        let dodged: Bool
        if hasEvadeNextHit || autoDodge {
            dodged = true
        } else {
            let chance = dodgeChance(for: state, in: context)
            dodged = BattleChance.succeeds(probability: chance, using: &context.rng)
        }
        guard dodged else {
            if state.options.isAttackHit, profile.triggers.improvingOdds {
                context.heroTalents.history[state.combatant.id, default: HeroTalentHistory()].dodgeGrowth += 5
            }
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
        applyWinterWake(to: &state, in: &context)
        if !state.options.causedByDodge {
            state.damageEvents.append(contentsOf: UniqueCombatEngine.afterUniqueDodge(
                by: state.combatant,
                attackerID: state.sourceActorID,
                in: &context,
            ))
        }
        state.damageEvents.append(contentsOf: CombatTriggerEngine.afterHeroTalentDodge(by: state.combatant, in: &context))
        if !state.options.causedByDodge {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterDodge(
                by: state.combatant,
                attackerID: state.sourceActorID,
                allowsCounterattacks: !autoDodge,
                in: &context,
            ))
        }
    }

    static func dodgeChance(
        for state: DamageResolutionState,
        in context: BattleState,
    ) -> Double {
        dodgeChance(for: state.combatant, attackerID: state.sourceActorID, in: context)
    }

    static func dodgeChance(
        for combatant: Combatant,
        attackerID: String?,
        in context: BattleState,
    ) -> Double {
        if combatant.role == .enemy {
            return 0
        }
        let history = context.heroTalents.history[combatant.id]
        var chance = 0.10 + Double(history?.dodgeGrowth ?? 0) / 100
        if history?.falseOpening == true { chance += 0.05 }
        let profile = context.modifiers(for: combatant.id)
        chance += profile.triggers.dodgeChanceBonus
        if let owner = context.roster.participant(for: combatant) {
            chance += context.uniques.owners[owner]?.wrenflightDodge ?? 0
        }
        chance += context.roster.runtime(for: combatant)?.bonusDodgeUntilNextTurn ?? 0
        if context.roster.runtime(for: combatant)?.subzeroMistActive == true { chance += 0.20 }
        if context.roster.isDeathsDoorActive(for: combatant),
           profile.triggers.deathsDoorDodgeAndDebuffImmunity {
            chance += 0.5
        }
        if let attackerID,
           let attacker = context.roster.combatant(for: attackerID),
           context.roster.hasAffliction(.bleed, on: attacker.combatant) {
            chance += profile.triggers.dodgeChanceVsBleedingEnemiesBonus
        }
        if profile.triggers.dodgeChanceBelowHealthPercentThreshold > 0,
           profile.triggers.dodgeChanceBelowHealthPercentBonus > 0,
           context.roster.maxHealth(for: combatant) > 0 {
            let percent = Double(context.roster.health(for: combatant)) /
                Double(context.roster.maxHealth(for: combatant))
            if percent < profile.triggers.dodgeChanceBelowHealthPercentThreshold {
                chance += profile.triggers.dodgeChanceBelowHealthPercentBonus
            }
        }
        if context.roster.health(for: combatant) * 2 > context.roster.maxHealth(for: combatant) {
            chance += profile.triggers.dodgeChanceAboveHalfHealthBonus
        }
        return min(0.75, max(0, chance))
    }

    static func applyCriticalGate(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        if state.options.isPeriodic {
            state.isCritical = state.amount > 0 && state.options.guaranteedCritical
            return
        }
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
        var abilityBonus = state.options.abilityCriticalChanceBonus
        if actor.role != .enemy, state.options.isAttackHit, state.options.isBasicAttackHit,
           let pendingBonus = context.roster.runtime(for: actor.combatant)?.pendingBasicCritBonus,
           pendingBonus > 0 {
            abilityBonus += pendingBonus
            context.roster.mutateRuntime(for: actor.combatant) { $0.pendingBasicCritBonus = 0 }
        }
        if resolveGuaranteedCrit(to: &state, actor: actor, in: &context) {
            return
        }
        guard CriticalChanceEngine.rollSucceeds(
            keyword: damageKeyword,
            actorID: sourceActorID,
            defender: state.combatant,
            abilityBonus: abilityBonus,
            countsBleedingDefender: true,
            in: &context,
        )
        else {
            return
        }
        applyCritical(to: &state)
    }

    private static func resolveGuaranteedCrit(
        to state: inout DamageResolutionState,
        actor: CombatantRuntime,
        in context: inout BattleState,
    ) -> Bool {
        guard let sourceActorID = state.sourceActorID else {
            return false
        }
        var guaranteed = state.options.guaranteedCritical
        if actor.role != .enemy,
           state.options.guaranteedCriticalIfEnemyBuffed,
           context.roster.activeEffects(for: state.combatant).contains(where: \.effect.isRemovableBuff) {
            guaranteed = true
        }
        if state.options.isAttackHit,
           actor.role != .enemy,
           context.modifiers(for: sourceActorID).triggers.firstAttackGuaranteedCritical,
           context.claimBattleGuard(.surpriseStrike, actorID: actor.combatant.id) {
            guaranteed = true
        }
        if actor.role != .enemy, state.options.isAttackHit {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                guard member.isAlive, member.pendingGuaranteedCriticalAfterDodge,
                      member.id == sourceActorID
                        || context.modifiers(for: member.id).triggers.onDodgeNextPartyHitGuaranteedCritical
                else { continue }
                context.roster.mutateRuntime(for: member.combatant) {
                    $0.pendingGuaranteedCriticalAfterDodge = false
                }
                guaranteed = true
            }
        }
        if actor.role != .enemy,
           state.options.isAttackHit, state.options.isBasicAttackHit,
           context.roster.runtime(for: actor.combatant)?.pendingBasicGuaranteedCrit == true {
            context.roster.mutateRuntime(for: actor.combatant) {
                $0.pendingBasicGuaranteedCrit = false
            }
            guaranteed = true
        }
        if actor.role != .enemy,
           context.roster.isDeathsDoorActive(for: actor.combatant),
           context.modifiers(for: sourceActorID).triggers.guaranteedCritWhileOnDeathsDoor {
            guaranteed = true
        }
        if actor.role != .enemy,
           context.modifiers(for: sourceActorID).triggers.warChest,
           state.damageKeyword == .physical,
           context.gold >= 50 {
            guaranteed = true
        }
        if guaranteed {
            applyCritical(to: &state)
        }
        return guaranteed
    }

    private static func applyCritical(to state: inout DamageResolutionState) {
        state.isCritical = true
    }

    static func applyCriticalBlockSteal(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.isCritical,
              state.combatant.role == .enemy,
              let source = state.partySource(in: context),
              context.modifiers(for: source.id).triggers.critStealEnemyBlock
        else { return }
        let enemyBlock = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: state.combatant))
        guard enemyBlock > 0 else { return }
        state.damageEvents.append(contentsOf: DefensePoolEngine.steal(
            enemyBlock,
            from: state.combatant,
            to: source.combatant,
            abilityName: "Master Thief",
            in: &context,
        ))
    }
}
