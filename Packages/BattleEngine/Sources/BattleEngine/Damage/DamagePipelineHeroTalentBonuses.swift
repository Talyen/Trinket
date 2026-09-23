import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyOvercharge(
        to state: inout DamageResolutionState,
        source: Combatant,
        in context: inout BattleState,
    ) {
        guard let pending = context.roster.runtime(for: source)?.talents.pending,
              pending.overchargePercent > 0,
              CombatantTalentState.Pending.isLaterAttack(
                  preparedCardSerial: pending.overchargePreparedCardSerial,
                  currentCardSerial: context.resolution.cardTalents?.playSerial,
              ) else { return }
        state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + pending.overchargePercent)
        context.roster.mutateRuntime(for: source) {
            $0.talents.pending.overchargePercent = 0
            $0.talents.pending.overchargePreparedCardSerial = nil
        }
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
        if keyword == .freeze, state.targetStatus.isPoisoned, triggers.coolMossFreezeBonus > 0 {
            state.remaining += triggers.coolMossFreezeBonus
            state.itemBonus += triggers.coolMossFreezeBonus
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
               let percent = context.roster.runtime(for: source)?.talents.pending.nextBurnAttackPercent,
               percent > 0,
               CombatantTalentState.Pending.isLaterAttack(
                   preparedCardSerial: context.roster.runtime(for: source)?.talents.pending.nextBurnAttackPreparedCardSerial,
                   currentCardSerial: context.resolution.cardTalents?.playSerial,
               ) {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + percent)
                context.roster.mutateRuntime(for: source) {
                    $0.talents.pending.nextBurnAttackPercent = 0
                    $0.talents.pending.nextBurnAttackPreparedCardSerial = nil
                }
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
            if state.options.isAttackHit,
               let bonus = context.roster.runtime(for: source)?.talents.pending.nextPoisonDamageBonus,
               bonus > 0 {
                state.remaining += bonus
                state.itemBonus += bonus
                context.roster.mutateRuntime(for: source) { $0.talents.pending.nextPoisonDamageBonus = 0 }
            }
            if context.roster.runtime(for: source)?.talents.pending.doubleNextPoisonDamage == true {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
                context.roster.mutateRuntime(for: source) { $0.talents.pending.doubleNextPoisonDamage = false }
            }
            if state.options.isAttackHit,
               context.roster.runtime(for: source)?.talents.pending.doubleNextPoisonAttack == true {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
                context.roster.mutateRuntime(for: source) { $0.talents.pending.doubleNextPoisonAttack = false }
            }
        }
        if keyword == .burn, state.options.isAttackHit,
           let bonus = context.roster.runtime(for: source)?.talents.pending.nextBurnDamageBonus,
           bonus > 0 {
            state.remaining += bonus
            state.itemBonus += bonus
            context.roster.mutateRuntime(for: source) { $0.talents.pending.nextBurnDamageBonus = 0 }
        }
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
           let pending = context.roster.runtime(for: source)?.talents.pending,
           pending.doubleNextPhysicalAttack,
           CombatantTalentState.Pending.isLaterAttack(
               preparedCardSerial: pending.nextPhysicalPreparedCardSerial,
               currentCardSerial: context.resolution.cardTalents?.playSerial,
           ) {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
            context.roster.mutateRuntime(for: source) {
                $0.talents.pending.doubleNextPhysicalAttack = false
                $0.talents.pending.nextPhysicalPreparedCardSerial = nil
            }
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
        if keyword == .poison, state.targetStatus.isStunned, triggers.toxicComa {
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
