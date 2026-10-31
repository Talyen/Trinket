import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyDodgeGate(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) async {
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
        let hasEvadeNextHit = context.roster.activeEffects(for: state.combatant).contains { $0.effect == .evadeNextHit }
        let profile = context.modifiers(for: state.combatant.id)
        let autoDodge = profile.triggers.autoDodgeAfterFirstHitPerTurn
            && (context.roster.runtime(for: state.combatant)?.talents.turn.tookAttackHit ?? false)
        if DefensePoolEngine.shouldIgnoreDodge(
            keyword: state.damageKeyword,
            sourceActorID: state.sourceActorID,
            in: context,
        ) {
            return
        }
        let dodged: Bool
        if hasEvadeNextHit || autoDodge {
            dodged = true
        } else {
            let chance = dodgeChance(for: state.combatant, attackerID: state.sourceActorID, in: context)
            dodged = BattleChance.succeeds(probability: chance, using: &context.rng)
        }
        guard dodged else {
            if state.options.isAttackHit, profile.triggers.improvingOdds {
                context.roster.mutateRuntime(for: state.combatant) { $0.talents.history.dodgeGrowth += 5 }
            }
            return
        }
        if hasEvadeNextHit {
            ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) { $0 == .evadeNextHit }
        }
        context.nextEvent(
            kind: .effect(.dodgeApplied),
            source: .init(state.combatant),
            abilityName: "Dodge",
            target: state.combatant,
            amount: 0,
            keyword: .dodge,
        )
        state.isDodged = true
        await applyWinterWake(to: &state, in: &context)
        if !state.options.causedByDodge {
            await UniqueCombatEngine.afterUniqueDodge(by: state.combatant, attackerID: state.sourceActorID, in: &context)
        }
        CombatTriggerEngine.afterHeroTalentDodge(by: state.combatant, in: &context)
        if !state.options.causedByDodge {
            await CombatTriggerEngine.afterDodge(
                by: state.combatant,
                attackerID: state.sourceActorID,
                allowsCounterattacks: !autoDodge,
                in: &context,
            )
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
        guard combatant.role != .enemy else { return 0 }
        let history = context.roster.runtime(for: combatant)?.talents.history
        var chance = 0.10 + Double(history?.dodgeGrowth ?? 0) / 100
        let profile = context.modifiers(for: combatant.id)
        chance += profile.triggers.dodgeChanceBonus
        let currentHealth = context.roster.health(for: combatant)
        let maxHealth = context.roster.maxHealth(for: combatant)
        let isFullHealth = maxHealth > 0 && currentHealth == maxHealth
        if context.roster.hero.isAlive {
            let grove = context.heroModifiers.triggers
            if isFullHealth {
                chance += grove.quietGroveDodgeAtFullHealth
            }
            if combatant.role == .companion, context.roster.hero.currentMana > 0 {
                chance += grove.groveReserveCompanionDodgeBonus
            }
        }
        if let owner = context.roster.participant(for: combatant) {
            chance += context.roster[owner].uniques.turn.wrenflightDodge
        }
        chance += context.roster.runtime(for: combatant)?.talents.dodgeChanceBonus(atTurn: context.turnCount) ?? 0
        if context.roster.runtime(for: combatant)?.talents.turn.subzeroMistActive == true {
            chance += 0.20
        }
        if context.roster.isDeathsDoorActive(for: combatant), profile.triggers.deathsDoorDodgeAndDebuffImmunity {
            chance += 0.5
        }
        if let attackerID,
           let attacker = context.roster.combatant(for: attackerID),
           context.roster.hasAffliction(.bleed, on: attacker.combatant) {
            chance += profile.triggers.dodgeChanceVsBleedingEnemiesBonus
        }
        if context.roster.hero.isAlive, context.roster.hasAffliction(.burn, on: context.roster.enemy.combatant) {
            chance += context.heroModifiers.triggers.partyDodgeVsBurningBonus
        }
        if profile.triggers.dodgeChanceBelowHealthPercentThreshold > 0,
           profile.triggers.dodgeChanceBelowHealthPercentBonus > 0,
           maxHealth > 0,
           Double(currentHealth) / Double(maxHealth) < profile.triggers.dodgeChanceBelowHealthPercentThreshold {
            chance += profile.triggers.dodgeChanceBelowHealthPercentBonus
        }
        if context.roster.isAboveHalfHealth(for: combatant) {
            chance += profile.triggers.dodgeChanceAboveHalfHealthBonus
        }
        if isFullHealth {
            chance += profile.triggers.dodgeAtFullHealthBonus
        }
        if context.roster.companion.isAlive {
            let companion = context.companionModifiers.triggers
            chance += companion.partyDodgeChanceBonus
            if companion.partyDodgeWhileBlockedBonus > 0,
               DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: combatant)) > 0 {
                chance += companion.partyDodgeWhileBlockedBonus
            }
            if isFullHealth {
                chance += companion.partyDodgeAtFullHealthBonus
            }
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
        if state.options.isAttackHit, state.combatant.role == .enemy, damageKeyword == .bleed,
           context.modifiers(for: sourceActorID).triggers.firstBleedAttackLeechPerTurn,
           context.claimHeroTalent(.carnivore, actorID: sourceActorID) {
            // The granted Leech must qualify this attack's Critical chance riders.
            state.talentAttackHasLeech = true
        }
        var abilityBonus = state.options.abilityCriticalChanceBonus
        if state.options.isAttackHit {
            abilityBonus += context.consumeTalentPreparation(\.nextAttackCriticalBonus, for: actor.combatant) ?? 0
        }
        abilityBonus += consumeSanctifiedCriticalBonus(for: state, actor: actor.combatant, in: &context)
        if state.options.isAttackHit,
           state.hasGuaranteedAttackLeech(in: context)
           || HealingEngine.grantsLeech(
               to: actor, keyword: state.damageKeyword, criticalAttack: false,
               attackHit: true, in: context,
           ),
           context.roster.hasAffliction(.bleed, on: state.combatant) {
            abilityBonus += context.modifiers(for: sourceActorID).triggers.leechCriticalVsBleedingBonus
        }
        if state.options.isAttackHit, state.damageKeyword == .physical, state.targetStatus.isFrozen {
            abilityBonus += context.modifiers(for: sourceActorID).triggers.physicalVsFrozenCritBonus
        }
        abilityBonus += companionAttackCriticalBonus(for: state, actor: actor, in: context)
        abilityBonus += finalCompanionCriticalChanceBonus(for: state, actor: actor, in: &context)
        if state.options.isAttackHit, state.options.isBasicAttackHit,
           let pendingBonus = context.roster.runtime(for: actor.combatant)?.talents.pending.basicCriticalBonus,
           pendingBonus > 0 {
            abilityBonus += pendingBonus
            context.roster.mutateRuntime(for: actor.combatant) { $0.talents.pending.basicCriticalBonus = 0 }
        }
        if resolveGuaranteedCrit(to: &state, actor: actor, in: &context) {
            return
        }
        guard CriticalChanceEngine.rollSucceeds(
            actorID: sourceActorID,
            defender: state.combatant,
            abilityBonus: abilityBonus,
            countsBleedingDefender: true,
            in: &context,
        )
        else {
            return
        }
        state.isCritical = true
    }

    private static func resolveGuaranteedCrit(
        to state: inout DamageResolutionState,
        actor: CombatantRuntime,
        in context: inout BattleState,
    ) -> Bool {
        guard let sourceActorID = state.sourceActorID else { return false }
        let sourceTriggers = context.modifiers(for: sourceActorID).triggers
        var guaranteed = state.options.guaranteedCritical
            || (state.options.guaranteedCriticalIfEnemyBuffed
                && context.roster.activeEffects(for: state.combatant).contains(where: \.effect.isRemovableBuff))
        if state.options.isAttackHit {
            if sourceTriggers.firstAttackGuaranteedCritical,
               context.claimBattleGuard(.surpriseStrike, actorID: actor.combatant.id) {
                guaranteed = true
            }
            if state.damageKeyword == .physical,
               sourceTriggers.firstPhysicalAttackGuaranteedCritical,
               context.claimBattleGuard(.surpriseStrikePhysical, actorID: actor.combatant.id) {
                guaranteed = true
            }
            for (_, member) in CombatTriggerEngine.livingPartyMembers(in: context) {
                guard member.talents.pending.guaranteedCriticalAfterDodge,
                      member.id == sourceActorID
                      || context.modifiers(for: member.id).triggers.onDodgeNextPartyHitGuaranteedCritical
                else { continue }
                context.roster.mutateRuntime(for: member.combatant) {
                    $0.talents.pending.guaranteedCriticalAfterDodge = false
                }
                guaranteed = true
            }
            if state.options.isBasicAttackHit,
               context.roster.runtime(for: actor.combatant)?.talents.pending.basicGuaranteedCritical == true {
                context.roster.mutateRuntime(for: actor.combatant) {
                    $0.talents.pending.basicGuaranteedCritical = false
                }
                guaranteed = true
            }
            if context.consumeTalentPreparation(\.nextAttackGuaranteedCritical, for: actor.combatant) == true
                || (state.damageKeyword == .bleed
                    && context.consumeTalentPreparation(\.guaranteedBleedCritical, for: actor.combatant) == true) {
                guaranteed = true
            }
            if context.consumeTalentPreparation(\.nextStunPreparedCritical, for: actor.combatant) == true {
                guaranteed = true
            }
        }
        if (sourceTriggers.guaranteedCritWhileOnDeathsDoor && context.roster.isDeathsDoorActive(for: actor.combatant))
            || (sourceTriggers.warChest && state.damageKeyword == .physical && context.gold >= 50) {
            guaranteed = true
        }
        if guaranteed {
            state.isCritical = true
        }
        return guaranteed
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
        DefensePoolEngine.steal(enemyBlock, from: state.combatant, to: source.combatant, abilityName: "Master Thief", in: &context)
    }
}
