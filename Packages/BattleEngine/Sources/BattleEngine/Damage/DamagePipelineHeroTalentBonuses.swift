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
        applyBlockAndAttackBonuses(
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
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, triggers.poisonAttackVsBleedingBonus)
        }
        if keyword == .poison, state.targetStatus.isBleeding, triggers.poisonDamageVsBleedingMultiplier > 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.poisonDamageVsBleedingMultiplier)
        }
        if keyword == .poison, state.targetStatus.isBurning, triggers.poisonVsBurningMultiplier > 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.poisonVsBurningMultiplier)
        }
        if keyword == .freeze, state.targetStatus.isPoisoned, context.roster.hero.isAlive {
            let bonus = context.heroModifiers.triggers.coolMossFreezeBonus
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
        }
        let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: keyword, triggers: triggers)
        if keyword == .bleed || sharedKeyword == .bleed,
           state.isCritical, triggers.bleedCriticalBelowHalfMultiplier > 1,
           context.roster.isBelowHalfHealth(for: state.combatant) {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.bleedCriticalBelowHalfMultiplier)
        }
        if keyword == .bleed || sharedKeyword == .bleed,
           state.options.isAttackHit, state.targetStatus.isStunned,
           triggers.bleedAttackVsStunnedMultiplier > 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.bleedAttackVsStunnedMultiplier)
        }
        if keyword == .burn || sharedKeyword == .burn,
           state.targetStatus.isBleeding, triggers.burnDamageVsBleedingMultiplier > 1 {
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
        applyPreparedReactionAttackBonus(to: &state, keyword: keyword, source: source, in: &context)
        let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: keyword, triggers: triggers)
        if keyword == .burn || sharedKeyword == .burn,
           context.roster.isBelowHalfHealth(for: source),
           triggers.burnBelowHalfHealthMultiplier > 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.burnBelowHalfHealthMultiplier)
        }
        if keyword == .burn || sharedKeyword == .burn,
           context.roster.runtime(for: source)?.currentMana == 0, triggers.zeroManaBurnMultiplier > 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.zeroManaBurnMultiplier)
        }
        if keyword == .burn || sharedKeyword == .burn {
            if state.options.isAttackHit,
               let percent = context.consumeTalentPreparation(\.nextBurnAttackPercent, for: source) {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + percent)
            }
        }
        if keyword == .bleed || sharedKeyword == .bleed, state.options.isAttackHit,
           let bonus = context.consumeTalentPreparation(\.nextBleedDamageBonus, for: source) {
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
        }
        if state.isCritical, triggers.manaEmpoweredCriticalMultiplier > 1,
           context.resolution.actionTalents(for: source.id)?.empoweredByMana == true {
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

    private static func applyPreparedReactionAttackBonus(
        to state: inout DamageResolutionState,
        keyword: Keyword,
        source: Combatant,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit, state.amount > 0 else { return }
        let keyPath: WritableKeyPath<CombatantTalentState.Pending, PreparedTalentBonus<Int>?>
        switch keyword {
        case .stun: keyPath = \.nextDodgeStunAttackBonus
        case .freeze: keyPath = \.nextDodgeFreezeAttackBonus
        case .bleed: keyPath = \.nextDodgeBleedAttackBonus
        case .holy: keyPath = \.nextPurgeHolyAttackBonus
        case .poison: keyPath = \.nextLeechCriticalPoisonAttackBonus
        default: return
        }
        guard let bonus = context.consumeTalentPreparation(keyPath, for: source) else { return }
        state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
    }

    private static func applyPreparedPoisonAttackBonus(
        to state: inout DamageResolutionState,
        source: Combatant,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit else { return }
        let bonus = SaturatedArithmetic.saturatingAdd(
            context.consumeTalentPreparation(\.nextPoisonDamageBonus, for: source) ?? 0,
            context.consumeTalentPreparation(\.nextToxicRemedyDamageBonus, for: source) ?? 0,
        )
        state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
    }

    private static func applyBlockAndAttackBonuses(
        to state: inout DamageResolutionState,
        keyword: Keyword,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        guard let source = context.roster.combatant(for: sourceActorID)?.combatant else { return }
        let sourceBlock = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source))
        let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: keyword, triggers: triggers)
        if keyword == .physical || sharedKeyword == .physical,
           triggers.physicalDamageFromBlockPercent > 0, sourceBlock > 0 {
            let bonus = CombatRounding.scaled(sourceBlock, multiplier: triggers.physicalDamageFromBlockPercent)
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
        }
        if keyword == .physical || sharedKeyword == .physical, state.options.isAttackHit,
           let bonus = context.consumeTalentPreparation(\.nextPhysicalDamageBonus, for: source) {
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
        }
        if state.options.isAttackHit,
           let bonus = context.consumeTalentPreparation(\.nextAttackDamageBonus, for: source) {
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
        }
        if keyword == .physical || sharedKeyword == .physical, state.options.isAttackHit,
           context.consumeTalentPreparation(\.doubleNextPhysicalAttack, for: source) == true {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
        }
        if keyword == .stun, triggers.lightningRod, sourceBlock > 0 {
            let bonus = sourceBlock / 2
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
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
        if keyword == .burn || sharedKeyword == .burn,
           state.targetStatus.isFrozen, triggers.burnDamageVsFrozenMultiplier > 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.burnDamageVsFrozenMultiplier)
        }
        if state.isCritical, state.targetStatus.isBurning, triggers.criticalDamageVsBurningMultiplier > 1 {
            state.remaining = CombatRounding.scaled(
                state.remaining, multiplier: triggers.criticalDamageVsBurningMultiplier,
            )
        }
    }
}
