import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyPreparedPoisonDamage(to state: inout DamageResolutionState, in context: inout BattleState) {
        guard state.remaining > 0, state.damageKeyword == .poison, state.combatant.role == .enemy,
              let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID),
              source.talents.pending.doubleNextPoisonDamage else { return }
        state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
        context.roster.mutateRuntime(for: source.combatant) { $0.talents.pending.doubleNextPoisonDamage = false }
    }

    static func applyOvercharge(
        to state: inout DamageResolutionState,
        source: Combatant,
        in context: inout BattleState,
    ) {
        guard let percent = context.consumeTalentPreparation(\.overchargePercent, for: source) else { return }
        state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + percent)
    }

    static func applyTalentStatusMultipliers(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        if state.damageKeyword == .bleed, state.combatant.role == .enemy,
           context.roster.runtime(for: state.combatant)?.talents.pending.doubleNextBleedDamage == true {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
            context.roster.mutateRuntime(for: state.combatant) {
                $0.talents.pending.doubleNextBleedDamage = false
            }
        }
        guard let keyword = state.damageKeyword,
              let sourceActorID = state.sourceActorID,
              state.combatant.role == .enemy else { return }
        let triggers = context.modifiers(for: sourceActorID).triggers
        applyPartyAndTypedStatusBonuses(
            to: &state, keyword: keyword, sourceActorID: sourceActorID, triggers: triggers, in: &context,
        )
        applyPreparedElementalBonuses(
            to: &state, keyword: keyword, sourceActorID: sourceActorID, triggers: triggers, in: &context,
        )
        applyBlockAndHolyBonuses(
            to: &state, keyword: keyword, sourceActorID: sourceActorID, triggers: triggers, in: &context,
        )
        applyLegacyAndWizardBonuses(
            to: &state, keyword: keyword, triggers: triggers,
        )
    }

    private static func applyPartyAndTypedStatusBonuses(
        to state: inout DamageResolutionState,
        keyword: Keyword,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        if sourceActorID == context.roster.companion.id, context.roster.hero.isAlive,
           state.options.isAttackHit {
            let party = context.heroModifiers.triggers
            if state.targetStatus.isPoisoned, party.companionDamageVsPoisonedMultiplier > 1 {
                state.remaining = CombatRounding.scaled(
                    state.remaining, multiplier: party.companionDamageVsPoisonedMultiplier,
                )
            }
            if state.targetStatus.isBleeding, party.companionAttackVsBleedingMultiplier > 1 {
                state.remaining = CombatRounding.scaled(
                    state.remaining, multiplier: party.companionAttackVsBleedingMultiplier,
                )
            }
        }
        if keyword == .poison, state.options.isAttackHit, state.targetStatus.isBleeding,
           triggers.poisonAttackVsBleedingBonus > 0 {
            state.remaining += triggers.poisonAttackVsBleedingBonus
            state.itemBonus += triggers.poisonAttackVsBleedingBonus
        }
        if keyword == .poison, state.targetStatus.isBleeding, triggers.poisonDamageVsBleedingMultiplier > 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.poisonDamageVsBleedingMultiplier)
        }
        if keyword == .poison, state.targetStatus.isBurning, triggers.poisonVsBurningMultiplier > 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.poisonVsBurningMultiplier)
        }
        if keyword == .freeze, state.targetStatus.isPoisoned, context.roster.hero.isAlive {
            let bonus = context.heroModifiers.triggers.coolMossFreezeBonus
            state.remaining += bonus
            state.itemBonus += bonus
        }
        if keyword == .bleed, state.isCritical, triggers.bleedCriticalBelowHalfMultiplier > 1,
           context.roster.health(for: state.combatant) * 2 < context.roster.maxHealth(for: state.combatant) {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.bleedCriticalBelowHalfMultiplier)
        }
        if keyword == .bleed, state.options.isAttackHit, state.targetStatus.isStunned,
           triggers.bleedAttackVsStunnedMultiplier > 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.bleedAttackVsStunnedMultiplier)
        }
        if keyword == .burn, state.targetStatus.isBleeding, triggers.burnDamageVsBleedingMultiplier > 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.burnDamageVsBleedingMultiplier)
        }
    }

    private static func applyPreparedElementalBonuses(
        to state: inout DamageResolutionState,
        keyword: Keyword,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        guard let source = context.roster.combatant(for: sourceActorID)?.combatant else { return }
        if keyword == .burn {
            if context.roster.health(for: source) * 2 < context.roster.maxHealth(for: source),
               triggers.burnBelowHalfHealthMultiplier > 1 {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.burnBelowHalfHealthMultiplier)
            }
            if context.roster.runtime(for: source)?.currentMana == 0, triggers.zeroManaBurnMultiplier > 1 {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.zeroManaBurnMultiplier)
            }
            if state.options.isAttackHit,
               let percent = context.consumeTalentPreparation(\.nextBurnAttackPercent, for: source) {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + percent)
            }
        }
        if keyword == .bleed, state.options.isAttackHit,
           let bonus = context.roster.runtime(for: source)?.talents.pending.nextBleedDamageBonus,
           bonus > 0 {
            state.remaining += bonus
            state.itemBonus += bonus
            context.roster.mutateRuntime(for: source) { $0.talents.pending.nextBleedDamageBonus = 0 }
        }
        if state.isCritical, triggers.manaEmpoweredCriticalMultiplier > 1,
           context.roster.runtime(for: source)?.talents.action.empoweredByMana == true {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.manaEmpoweredCriticalMultiplier)
        }
        if keyword == .poison {
            applyPreparedPoisonAttackBonus(to: &state, source: source, in: &context)
            applyPreparedPoisonDamage(to: &state, in: &context)
            if state.options.isAttackHit,
               context.roster.runtime(for: source)?.talents.pending.doubleNextPoisonAttack == true {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
                context.roster.mutateRuntime(for: source) { $0.talents.pending.doubleNextPoisonAttack = false }
            }
        }
        applyPreparedBurnAttackBonus(to: &state, source: source, in: &context)
    }

    private static func applyPreparedPoisonAttackBonus(
        to state: inout DamageResolutionState,
        source: Combatant,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit,
              let bonus = context.consumeTalentPreparation(\.nextPoisonDamageBonus, for: source) else { return }
        state.remaining += bonus
        state.itemBonus += bonus
    }

    private static func applyBlockAndHolyBonuses(
        to state: inout DamageResolutionState,
        keyword: Keyword,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        guard let source = context.roster.combatant(for: sourceActorID)?.combatant else { return }
        let sourceBlock = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source))
        if keyword == .physical, triggers.physicalDamageFromBlockPercent > 0, sourceBlock > 0 {
            let bonus = CombatRounding.scaled(sourceBlock, multiplier: triggers.physicalDamageFromBlockPercent)
            state.remaining += bonus
            state.itemBonus += bonus
        }
        if keyword == .physical, state.options.isAttackHit,
           let bonus = context.roster.runtime(for: source)?.talents.pending.nextPhysicalDamageBonus,
           bonus > 0 {
            state.remaining += bonus
            state.itemBonus += bonus
            context.roster.mutateRuntime(for: source) { $0.talents.pending.nextPhysicalDamageBonus = 0 }
        }
        if keyword == .physical, state.options.isAttackHit,
           context.consumeTalentPreparation(\.doubleNextPhysicalAttack, for: source) == true {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
        }
        if keyword == .stun, triggers.lightningRod, sourceBlock > 0 {
            let bonus = sourceBlock / 2
            state.remaining += bonus
            state.itemBonus += bonus
        }
        if keyword == .stun, state.isCritical, triggers.stunCriticalDamageMultiplier > 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.stunCriticalDamageMultiplier)
        }
        if keyword == .holy, sourceBlock > 0, triggers.holyDamageWhileBlockedMultiplier > 1 {
            state.remaining = CombatRounding.scaled(
                state.remaining, multiplier: triggers.holyDamageWhileBlockedMultiplier,
            )
        }
        if keyword == .holy, state.options.isAttackHit,
           context.roster.runtime(for: source)?.talents.pending.doubleNextHolyAttack == true {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
            context.roster.mutateRuntime(for: source) { $0.talents.pending.doubleNextHolyAttack = false }
        }
    }

    private static func applyLegacyAndWizardBonuses(
        to state: inout DamageResolutionState,
        keyword: Keyword,
        triggers: CombatTraitTriggers,
    ) {
        let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: keyword, triggers: triggers)
        if keyword == .physical || sharedKeyword == .physical,
           state.isCritical, state.targetStatus.isPoisoned, triggers.pressurePoint {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
        }
        if keyword == .bleed || sharedKeyword == .bleed, state.targetStatus.isPoisoned, triggers.septicemia {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
        }
        if keyword == .freeze, state.targetStatus.isBurning, triggers.elementalParadox {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
        }
        if keyword == .burn, state.targetStatus.isFrozen, triggers.burnDamageVsFrozenMultiplier > 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.burnDamageVsFrozenMultiplier)
        }
        if state.isCritical, state.targetStatus.isBurning, triggers.criticalDamageVsBurningMultiplier > 1 {
            state.remaining = CombatRounding.scaled(
                state.remaining, multiplier: triggers.criticalDamageVsBurningMultiplier,
            )
        }
    }
}
