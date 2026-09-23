import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyFinalCompanionEnemyAttackReduction(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.role == .enemy,
              source.talents.pending.nextOutgoingAttackMultiplier < 1 else { return }
        state.remaining = CombatRounding.scaled(
            state.remaining, multiplier: source.talents.pending.nextOutgoingAttackMultiplier,
        )
        context.roster.mutateRuntime(for: source.combatant) {
            $0.talents.pending.nextOutgoingAttackMultiplier = 1
        }
    }

    static func applyFinalCompanionOutgoingBonuses(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0, let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID),
              let keyword = state.damageKeyword else { return }
        if source.role == .enemy {
            if keyword == .physical, context.roster.companion.isAlive,
               context.roster.hasAffliction(.bleed, on: source.combatant) {
                state.remaining = CombatRounding.scaled(
                    state.remaining,
                    multiplier: context.companionModifiers.triggers.bleedingEnemyPhysicalDamageMultiplier,
                )
            }
            return
        }
        guard state.combatant.role == .enemy else { return }
        let triggers = context.modifiers(for: sourceID).triggers
        if state.options.isAttackHit, keyword == .bleed, triggers.firstBleedAttackLeechPerTurn,
           context.claimHeroTalent("Carnivore", actorID: sourceID) {
            state.talentAttackHasLeech = true
        }
        applyFinalCompanionFlatAndPreparedBonuses(to: &state, source: source.combatant, triggers: triggers, in: &context)
        var multiplier = finalCompanionStatusMultiplier(for: state, source: source.combatant, triggers: triggers, in: context)
        multiplier *= finalCompanionKeywordMultiplier(for: state, source: source.combatant, triggers: triggers, in: &context)
        multiplier *= consumeFinalCompanionPreparedMultiplier(for: state, source: source.combatant, in: &context)
        if multiplier != 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: multiplier)
        }
        state.dealt = state.remaining
    }

    private static func applyFinalCompanionFlatAndPreparedBonuses(
        to state: inout DamageResolutionState,
        source: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit else { return }
        if let pending = context.roster.runtime(for: source)?.talents.pending,
           pending.nextManaSpendAttackBonus > 0,
           CombatantTalentState.Pending.isLaterAbility(
               preparedCardSerial: pending.nextManaSpendAttackPreparedCardSerial,
               currentCardSerial: context.resolution.cardTalents?.playSerial,
           ),
           CombatantTalentState.Pending.isLaterAction(
               preparedActionID: pending.nextManaSpendAttackPreparedActionID,
               currentActionID: context.resolution.actionID,
           ) {
            state.remaining += pending.nextManaSpendAttackBonus
            context.roster.mutateRuntime(for: source) {
                $0.talents.pending.nextManaSpendAttackBonus = 0
                $0.talents.pending.nextManaSpendAttackPreparedCardSerial = nil
                $0.talents.pending.nextManaSpendAttackPreparedActionID = nil
            }
        }
        if state.damageKeyword == .holy, triggers.firstHolyAttackBonusPerTurn > 0,
           context.claimHeroTalent("Sunlight Spark", actorID: source.id) {
            state.remaining += triggers.firstHolyAttackBonusPerTurn
        }
        if state.damageKeyword == .physical, triggers.firstPhysicalAttackBattleMultiplier > 1,
           context.claimHeroTalent("Alpha Strike", actorID: source.id, battle: true) {
            state.remaining = CombatRounding.scaled(
                state.remaining, multiplier: triggers.firstPhysicalAttackBattleMultiplier,
            )
        }
        if state.damageKeyword == .physical, triggers.physicalAttackBurstChancePercent > 0,
           context.claimTalentAbility("Feral Frenzy", actorID: source.id),
           BattleChance.succeeds(probability: triggers.physicalAttackBurstChancePercent, using: &context.rng) {
            state.remaining = CombatRounding.scaled(
                state.remaining, multiplier: triggers.physicalAttackBurstMultiplier,
            )
        }
    }

    private static func finalCompanionStatusMultiplier(
        for state: DamageResolutionState,
        source: Combatant,
        triggers: CombatTraitTriggers,
        in context: BattleState,
    ) -> Double {
        var multiplier = 1.0
        if state.damageKeyword == .bleed, state.targetStatus.isPoisoned {
            multiplier *= triggers.bleedDamageVsPoisonedMultiplier
        }
        if state.damageKeyword == .burn, state.targetStatus.isFrozen {
            multiplier *= triggers.burnDamageVsFrozenMultiplier
        }
        if state.damageKeyword == .holy, state.targetStatus.isStunned {
            multiplier *= triggers.holyDamageVsStunnedMultiplier
        }
        if state.damageKeyword == .holy,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source)) > 0 {
            multiplier *= triggers.holyDamageMultiplierWhileBlocked
        }
        if state.damageKeyword == .stun,
           context.roster.activeEffects(for: source).contains(where: {
               $0.effect.kind == .thorns && ($0.effect.potency ?? 0) > 0
           }) {
            multiplier *= triggers.stunDamageMultiplierWhileThorns
        }
        if state.options.isAttackHit, state.targetStatus.isStunned {
            multiplier *= triggers.attackDamageVsStunnedMultiplier
        }
        let attackHasLeech = state.options.abilityHasLeech || state.talentAttackHasLeech
            || triggers.borrowedLife && context.roster.isDeathsDoorActive(for: source)
        if state.options.isAttackHit, state.targetStatus.isBleeding, attackHasLeech {
            multiplier *= triggers.leechAttackDamageVsBleedingMultiplier
        }
        if state.options.isAttackHit, state.isCritical, state.damageKeyword == .physical {
            if state.targetStatus.isBleeding {
                multiplier *= triggers.physicalCriticalDamageVsBleedingMultiplier
            }
            if state.targetStatus.isPoisoned {
                multiplier *= triggers.physicalCriticalDamageVsPoisonedMultiplier
            }
        }
        return multiplier
    }

    private static func finalCompanionKeywordMultiplier(
        for state: DamageResolutionState,
        source: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> Double {
        var multiplier = 1.0
        if state.options.isAttackHit, state.isCritical {
            if state.damageKeyword == .freeze {
                multiplier *= triggers.freezeCriticalDamageMultiplier
            }
            if state.damageKeyword == .burn {
                multiplier *= triggers.burnCriticalDamageMultiplier
            }
        }
        if state.damageKeyword == .holy, triggers.firstHolyHitDamageMultiplierPerTurn > 1,
           context.resolution.claim(
               .heroTalent("Crownfall"), actorID: source.id, cadence: .turn(context.turnCount),
           ) {
            multiplier *= triggers.firstHolyHitDamageMultiplierPerTurn
        }
        if context.roster.companion.isAlive, state.damageKeyword == .holy {
            multiplier *= context.companionModifiers.triggers.partyHolyDamageMultiplier
        }
        if context.roster.runtime(for: source)?.talents.action.empoweredByMana == true {
            if context.roster.runtime(for: source)?.talents.action.arcaneBurst == true {
                multiplier *= triggers.manaEmpowerDamageMultiplier
            }
            if state.damageKeyword == .burn || state.damageKeyword == .freeze {
                multiplier *= triggers.manaEmpowerBurnFreezeDamageMultiplier
            }
        }
        return multiplier
    }

    private static func consumeFinalCompanionPreparedMultiplier(
        for state: DamageResolutionState,
        source: Combatant,
        in context: inout BattleState,
    ) -> Double {
        guard let pending = context.roster.runtime(for: source)?.talents.pending else { return 1 }
        let serial = context.resolution.cardTalents?.playSerial
        var multiplier = 1.0
        if state.damageKeyword == .holy, pending.nextHolyHitDouble,
           CombatantTalentState.Pending.isLaterAbility(
               preparedCardSerial: pending.nextHolyHitPreparedCardSerial, currentCardSerial: serial,
           ) {
            context.roster.mutateRuntime(for: source) {
                $0.talents.pending.nextHolyHitDouble = false
                $0.talents.pending.nextHolyHitPreparedCardSerial = nil
            }
            multiplier *= 2
        }
        if state.damageKeyword == .stun, state.options.isAttackHit, pending.nextStunAttackDouble,
           CombatantTalentState.Pending.isLaterAbility(
               preparedCardSerial: pending.nextStunAttackPreparedCardSerial, currentCardSerial: serial,
           ) {
            context.roster.mutateRuntime(for: source) {
                $0.talents.pending.nextStunAttackDouble = false
                $0.talents.pending.nextStunAttackPreparedCardSerial = nil
            }
            multiplier *= 2
        }
        if state.options.isAttackHit, state.damageKeyword == .bleed, pending.nextBleedAttackMultiplier > 1,
           CombatantTalentState.Pending.isLaterAbility(
               preparedCardSerial: pending.nextBleedMultiplierPreparedCardSerial, currentCardSerial: serial,
           ) {
            multiplier *= pending.nextBleedAttackMultiplier
            context.roster.mutateRuntime(for: source) {
                $0.talents.pending.nextBleedAttackMultiplier = 1
                $0.talents.pending.nextBleedMultiplierPreparedCardSerial = nil
            }
        }
        if state.options.isAttackHit, state.damageKeyword == .physical, pending.nextPhysicalAttackMultiplier > 1,
           CombatantTalentState.Pending.isLaterAbility(
               preparedCardSerial: pending.nextPhysicalAttackPreparedCardSerial, currentCardSerial: serial,
           ) {
            multiplier *= pending.nextPhysicalAttackMultiplier
            context.roster.mutateRuntime(for: source) {
                $0.talents.pending.nextPhysicalAttackMultiplier = 1
                $0.talents.pending.nextPhysicalAttackPreparedCardSerial = nil
            }
        }
        if state.options.isAttackHit, state.isCritical, pending.nextCriticalHitMultiplier > 1,
           CombatantTalentState.Pending.isLaterAbility(
               preparedCardSerial: pending.nextCriticalHitPreparedCardSerial, currentCardSerial: serial,
           ) {
            multiplier *= pending.nextCriticalHitMultiplier
            context.roster.mutateRuntime(for: source) {
                $0.talents.pending.nextCriticalHitMultiplier = 1
                $0.talents.pending.nextCriticalHitPreparedCardSerial = nil
            }
        }
        return multiplier
    }
}
