import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func consumeSanctifiedCriticalBonus(
        for state: DamageResolutionState,
        actor: Combatant,
        in context: inout BattleState,
    ) -> Double {
        guard state.options.isAttackHit, let pending = context.roster.runtime(for: actor)?.talents.pending,
              pending.nextCleanseCriticalBonus > 0,
              CombatantTalentState.Pending.isLaterAbility(
                  preparedCardSerial: pending.nextCleanseCriticalPreparedCardSerial,
                  currentCardSerial: context.resolution.cardTalents?.playSerial,
              ) else { return 0 }
        context.roster.mutateRuntime(for: actor) {
            $0.talents.pending.nextCleanseCriticalBonus = 0
            $0.talents.pending.nextCleanseCriticalPreparedCardSerial = nil
        }
        return pending.nextCleanseCriticalBonus
    }

    static func companionAttackCriticalBonus(
        for state: DamageResolutionState,
        actor: CombatantRuntime,
        in context: BattleState,
    ) -> Double {
        guard state.options.isAttackHit, let keyword = state.damageKeyword else { return 0 }
        let triggers = context.modifiers(for: actor.id).triggers
        switch keyword {
        case .physical where actor.currentHealth * 2 < actor.maxHealth:
            return triggers.physicalCritChanceBelowHalfBonus
        case .bleed:
            return triggers.bleedAttackCriticalBonus
        case .holy:
            return triggers.holyAttackCriticalBonus
        default:
            return 0
        }
    }

    static func applyPreparedBurnAttackBonus(
        to state: inout DamageResolutionState,
        source: Combatant,
        in context: inout BattleState,
    ) {
        guard state.damageKeyword == .burn, state.options.isAttackHit,
              let pending = context.roster.runtime(for: source)?.talents.pending,
              pending.nextBurnDamageBonus > 0,
              CombatantTalentState.Pending.isLaterAbility(
                  preparedCardSerial: pending.nextBurnDamagePreparedCardSerial,
                  currentCardSerial: context.resolution.cardTalents?.playSerial,
              ) else { return }
        state.remaining += pending.nextBurnDamageBonus
        state.itemBonus += pending.nextBurnDamageBonus
        context.roster.mutateRuntime(for: source) {
            $0.talents.pending.nextBurnDamageBonus = 0
            $0.talents.pending.nextBurnDamagePreparedCardSerial = nil
        }
    }

    static func reserveCompanionBlockIgnore(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit, state.combatant.role == .enemy,
              let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID),
              let pending = context.roster.runtime(for: source.combatant)?.talents.pending
        else { return }
        let cardSerial = context.resolution.cardTalents?.playSerial
        let anyAttack = pending.nextAttackIgnoresBlock && CombatantTalentState.Pending.isLaterAbility(
            preparedCardSerial: pending.nextAttackIgnorePreparedCardSerial, currentCardSerial: cardSerial,
        )
        let freezeAttack = state.damageKeyword == .freeze && pending.nextFreezeIgnoresBlock
            && CombatantTalentState.Pending.isLaterAbility(
                preparedCardSerial: pending.nextFreezeIgnorePreparedCardSerial, currentCardSerial: cardSerial,
            )
        guard anyAttack || freezeAttack else { return }
        state.ignoreBlockFromTalent = true
        context.roster.mutateRuntime(for: source.combatant) {
            if anyAttack {
                $0.talents.pending.nextAttackIgnoresBlock = false
                $0.talents.pending.nextAttackIgnorePreparedCardSerial = nil
            }
            if freezeAttack {
                $0.talents.pending.nextFreezeIgnoresBlock = false
                $0.talents.pending.nextFreezeIgnorePreparedCardSerial = nil
            }
        }
    }

    static func applyCompanionDamageRetaliation(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit || state.options.isPeriodic,
              !state.options.isRetaliation || state.options.isPeriodic, state.healthLost > 0,
              let attackerID = state.sourceActorID,
              let attacker = context.roster.combatant(for: attackerID), attacker.role == .enemy,
              attacker.isAlive
        else { return }
        let defender = state.combatant
        let triggers = context.modifiers(for: defender.id).triggers
        if triggers.onDamageFreezeRetaliationDamage > 0,
           context.claimTalentAbility("Chilling Scales", actorID: defender.id),
           BattleChance.succeeds(
               probability: triggers.onDamageFreezeRetaliationChancePercent, using: &context.rng,
           ) {
            appendNestedDamage(
                amount: triggers.onDamageFreezeRetaliationDamage,
                keyword: .freeze, abilityName: "Chilling Scales",
                target: attacker.combatant, defender: defender, to: &state, in: &context,
            )
        }
        if triggers.onDamageBurnRetaliationDamage > 0,
           context.claimTalentAbility("Blazing Feathers", actorID: defender.id),
           BattleChance.succeeds(
               probability: triggers.onDamageBurnRetaliationChancePercent, using: &context.rng,
           ) {
            appendNestedDamage(
                amount: triggers.onDamageBurnRetaliationDamage,
                keyword: .burn, abilityName: "Blazing Feathers",
                target: attacker.combatant, defender: defender, to: &state, in: &context,
            )
        }
    }

    static func applyCompanionAttackBonuses(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isCardAttack, state.combatant.role == .enemy,
              let keyword = state.damageKeyword,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID), source.role == .companion
        else { return }
        let triggers = context.modifiers(for: sourceActorID).triggers
        if keyword == .bleed, triggers.bleedAttackDamageBonus > 0 {
            state.remaining += triggers.bleedAttackDamageBonus
            state.itemBonus += triggers.bleedAttackDamageBonus
        }
        if keyword == .stun, triggers.firstStunAttackBonusPerTurn > 0,
           context.claimHeroTalent("Ground Slam", actorID: sourceActorID) {
            state.remaining += triggers.firstStunAttackBonusPerTurn
            state.itemBonus += triggers.firstStunAttackBonusPerTurn
        }
        if keyword == .physical, triggers.firstPhysicalAttackBlockDamagePercent > 0,
           context.claimHeroTalent("Battering Ram", actorID: sourceActorID) {
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source.combatant))
            let bonus = CombatRounding.scaled(block, multiplier: triggers.firstPhysicalAttackBlockDamagePercent)
            state.remaining += bonus
            state.itemBonus += bonus
        }
    }

    static func applyCompanionStatusMultipliers(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let sourceActorID = state.sourceActorID,
              context.roster.combatant(for: sourceActorID)?.role == .companion
        else { return }
        let triggers = context.modifiers(for: sourceActorID).triggers
        if state.options.isAttackHit, state.targetStatus.isBleeding,
           context.roster.health(for: state.combatant) * 2 < context.roster.maxHealth(for: state.combatant),
           triggers.attackVsBleedingBelowHalfMultiplier > 1 {
            state.remaining = CombatRounding.scaled(
                state.remaining, multiplier: triggers.attackVsBleedingBelowHalfMultiplier,
            )
        }
        if state.damageKeyword == .bleed, state.options.isAttackHit, state.isCritical,
           triggers.bleedCriticalDamageMultiplier > 1 {
            state.remaining = CombatRounding.scaled(
                state.remaining, multiplier: triggers.bleedCriticalDamageMultiplier,
            )
        }
        if state.damageKeyword == .bleed, state.options.isAttackHit,
           let source = context.roster.combatant(for: sourceActorID),
           let pending = context.roster.runtime(for: source.combatant)?.talents.pending,
           pending.doubleNextBleedAttack,
           CombatantTalentState.Pending.isLaterAbility(
               preparedCardSerial: pending.nextBleedAttackPreparedCardSerial,
               currentCardSerial: context.resolution.cardTalents?.playSerial,
           ) {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 2)
            context.roster.mutateRuntime(for: source.combatant) {
                $0.talents.pending.doubleNextBleedAttack = false
                $0.talents.pending.nextBleedAttackPreparedCardSerial = nil
            }
        }
        if state.options.isAttackHit, state.damageKeyword == .physical, state.targetStatus.isStunned,
           triggers.physicalDamageVsStunnedMultiplier > 1 {
            state.remaining = CombatRounding.scaled(
                state.remaining, multiplier: triggers.physicalDamageVsStunnedMultiplier,
            )
        }
        if state.damageKeyword == .poison, state.targetStatus.isStunned,
           triggers.poisonDamageVsStunnedMultiplier > 1 {
            state.remaining = CombatRounding.scaled(
                state.remaining, multiplier: triggers.poisonDamageVsStunnedMultiplier,
            )
        }
        if state.damageKeyword == .bleed,
           context.roster.health(for: state.combatant) * 2 < context.roster.maxHealth(for: state.combatant),
           triggers.bleedDamageBelowHalfMultiplier > 1 {
            state.remaining = CombatRounding.scaled(
                state.remaining, multiplier: triggers.bleedDamageBelowHalfMultiplier,
            )
        }
    }

    static func applyCompanionFlatDefense(
        to state: inout DamageResolutionState,
        in context: BattleState,
    ) {
        guard state.damageKeyword == .physical,
              DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: state.combatant)) > 0
        else { return }
        let flat = context.modifiers(for: state.combatant.id).triggers.physicalMitigationWhileBlockedFlat
        let reduction = CombatRounding.scaled(
            flat, multiplier: DamageDefensePolicy.mitigationMultiplier(state: state, context: context),
        )
        state.remaining = max(0, state.remaining - reduction)
    }

    static func companionBleedResistance(
        for target: Combatant,
        keyword: Keyword,
        in context: BattleState,
    ) -> Double {
        guard keyword == .bleed,
              DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: target)) > 0
        else { return 0 }
        return 1 - context.modifiers(for: target.id).triggers.bleedDamageMultiplierWhileBlocked
    }

    static func applyCompanionDefenseMultipliers(
        to state: inout DamageResolutionState,
        in context: BattleState,
    ) {
        let triggers = context.modifiers(for: state.combatant.id).triggers
        let manaMultiplier = (context.roster.runtime(for: state.combatant)?.currentMana ?? 0) > 0
            ? triggers.manaHeldDamageMultiplier : 1
        let doorMultiplier = context.roster.isDeathsDoorActive(for: state.combatant)
            ? triggers.deathsDoorIncomingDamageMultiplier : 1
        let multiplier = manaMultiplier * doorMultiplier
        if multiplier < 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: multiplier)
        }
    }

    static func applyPreparedIncomingProtection(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0, state.combatant.role != .enemy,
              let pending = context.roster.runtime(for: state.combatant)?.talents.pending,
              pending.nextIncomingDamageMultiplier < 1,
              CombatantTalentState.Pending.isLaterAbility(
                  preparedCardSerial: pending.nextIncomingDamagePreparedCardSerial,
                  currentCardSerial: context.resolution.cardTalents?.playSerial,
              ) else { return }
        state.remaining = CombatRounding.scaled(
            state.remaining, multiplier: pending.nextIncomingDamageMultiplier,
        )
        context.roster.mutateRuntime(for: state.combatant) {
            $0.talents.pending.nextIncomingDamageMultiplier = 1
            $0.talents.pending.nextIncomingDamagePreparedCardSerial = nil
        }
    }

    static func applyCompanionLeechCriticalBlock(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit, state.isCritical,
              let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.role == .companion,
              context.roster.hero.isAlive
        else { return }
        let triggers = context.modifiers(for: sourceID).triggers
        guard triggers.leechCriticalAllyBlock > 0 else { return }
        let lowHealthBleed = state.damageKeyword == .bleed
            && triggers.bleedAttackLeechBelowHealthThreshold > 0
            && source.currentHealth > 0 && source.maxHealth > 0
            && Double(source.currentHealth) / Double(source.maxHealth)
            < triggers.bleedAttackLeechBelowHealthThreshold
        let criticalBleedLeech = state.damageKeyword == .bleed && triggers.bleedCriticalHasLeech
        guard state.didLeech || state.options.abilityHasLeech || lowHealthBleed || criticalBleedLeech else { return }
        state.damageEvents.append(contentsOf: context.applyBlock(
            triggers.leechCriticalAllyBlock,
            to: context.roster.hero.combatant,
            source: source.combatant,
            abilityName: "Vitality Infusion",
        ))
    }
}
