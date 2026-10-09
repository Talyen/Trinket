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
           context.claimHeroTalent(.carnivore, actorID: sourceID) {
            state.talentAttackHasLeech = true
        }
        if state.options.isAttackHit, HealingEngine.grantsLeech(
            to: source, keyword: keyword, criticalAttack: state.isCritical,
            attackHit: true, in: context,
        ) {
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
        if let bonus = context.consumeTalentPreparation(\.nextManaSpendAttackBonus, for: source) {
            state.remaining += bonus
        }
        if state.damageKeyword == .holy, triggers.firstHolyAttackBonusPerTurn > 0,
           context.claimHeroTalent(.sunlightSpark, actorID: source.id) {
            state.remaining += triggers.firstHolyAttackBonusPerTurn
        }
        if state.damageKeyword == .physical, triggers.firstPhysicalAttackBattleMultiplier > 1,
           context.claimHeroTalent(.alphaStrike, actorID: source.id, battle: true) {
            state.remaining = CombatRounding.scaled(
                state.remaining, multiplier: triggers.firstPhysicalAttackBattleMultiplier,
            )
        }
        if state.damageKeyword == .physical, triggers.physicalAttackBurstChancePercent > 0,
           context.claimTalentAbility(.feralFrenzy, actorID: source.id),
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
        if state.damageKeyword == .holy, state.targetStatus.isStunned {
            multiplier *= triggers.holyDamageVsStunnedMultiplier
        }
        if state.damageKeyword == .holy,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source)) > 0 {
            multiplier *= triggers.holyDamageMultiplierWhileBlocked
        }
        if state.damageKeyword == .stun, state.options.isAttackHit,
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
               .heroTalent(.crownfall), actorID: source.id, cadence: .turn(context.turnCount),
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
        var multiplier = 1.0
        if state.damageKeyword == .holy,
           context.consumeTalentPreparation(\.nextHolyHitDouble, for: source) == true {
            multiplier *= 2
        }
        if state.damageKeyword == .stun, state.options.isAttackHit,
           context.consumeTalentPreparation(\.nextStunAttackDouble, for: source) == true {
            multiplier *= 2
        }
        if state.options.isAttackHit, state.damageKeyword == .bleed,
           let prepared = context.consumeTalentPreparation(\.nextBleedAttackMultiplier, for: source) {
            multiplier *= prepared
        }
        if state.options.isAttackHit, state.damageKeyword == .physical,
           let prepared = context.consumeTalentPreparation(\.nextPhysicalAttackMultiplier, for: source) {
            multiplier *= prepared
        }
        if state.options.isAttackHit, state.isCritical,
           let prepared = context.consumeTalentPreparation(\.nextCriticalHitMultiplier, for: source) {
            multiplier *= prepared
        }
        return multiplier
    }

    static func applyFinalCompanionLeechRewards(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) async {
        guard state.combatant.role == .enemy,
              let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.role == .companion
        else { return }
        let triggers = context.modifiers(for: sourceID).triggers
        let attackHasLeech = state.options.isAttackHit && state.healthLost > 0
            && (state.options.abilityHasLeech || state.talentAttackHasLeech
                || triggers.borrowedLife && context.roster.isDeathsDoorActive(for: source.combatant))
        guard state.didLeech || attackHasLeech else { return }
        if triggers.leechEnemyNextAttackDamageMultiplier < 1, context.roster.enemy.isAlive {
            context.roster.mutateRuntime(for: context.roster.enemy.combatant) {
                $0.talents.pending.nextOutgoingAttackMultiplier = min(
                    $0.talents.pending.nextOutgoingAttackMultiplier,
                    triggers.leechEnemyNextAttackDamageMultiplier,
                )
            }
        }
        if state.isCritical, state.options.isAttackHit,
           triggers.leechCriticalPoisonDamage > 0, context.roster.enemy.isAlive {
            await state.damageEvents.append(contentsOf: CombatTriggerEngine.heroTalentDamage(
                .poison, amount: triggers.leechCriticalPoisonDamage,
                source: source.combatant, name: "Toxic Touch", in: &context,
            ))
        }
    }

    static func applyFinalCompanionHolyHitRewards(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.amount > 0, state.damageKeyword == .holy,
              state.combatant.role == .enemy,
              context.roster.hero.isAlive,
              let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.role == .companion, source.isAlive,
              context.modifiers(for: sourceID).triggers.firstHolyHitAllyBlockPerTurn > 0,
              context.resolution.claim(
                  .heroTalent(.sunGlyph), actorID: sourceID, cadence: .turn(context.turnCount),
              ) else { return }
        state.damageEvents.append(contentsOf: context.applyBlock(
            context.modifiers(for: sourceID).triggers.firstHolyHitAllyBlockPerTurn,
            to: context.roster.hero.combatant,
            source: source.combatant,
            abilityName: "Sun Glyph",
        ))
    }
}
