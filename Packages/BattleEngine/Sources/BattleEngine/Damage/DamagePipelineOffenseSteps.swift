import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyDamageBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        applyBaseAndScaledDamage(to: &state, in: &context)
        applyCompanionAttackBonuses(to: &state, in: &context)
        if state.options.isAttackHit, state.amount > 0 {
            let bonus = context.resolution.consumeGoldDamage(for: state.sourceActorID)
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
        }
        if state.amount > 0 {
            let bonus = SaturatedArithmetic.saturatingAdd(
                context.resolution.consumePartyCardDamage(from: state.provenance),
                context.resolution.consumePartyDamage(from: state.provenance),
            )
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
        }
        QuietAffixRules.applyAttackBonuses(to: &state, in: &context)
        applyPercentBonus(to: &state, in: &context)
        applyDodgeEmpoweredBonuses(to: &state, in: &context)
        applyStunnedAndTalentMultipliers(to: &state, in: &context)
        applyBurnDamageMultipliers(to: &state, in: &context)
        applyOneShotEmpowers(to: &state)
        applyOutgoingReductions(to: &state, in: &context)
        applyDamageRolls(to: &state, in: &context)
    }

    private static func applyDamageRolls(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0, let keyword = state.damageKeyword,
              let sourceActorID = state.sourceActorID else { return }
        let triggers = context.modifiers(for: sourceActorID).triggers
        if triggers.loadedStrike, state.options.isAttackHit {
            let doubled = context.resolution.loadedStrikeDouble(for: sourceActorID, using: &context.rng)
            if doubled {
                applyDoubledOrCeilHalved(to: &state, doubled: true)
            }
        }
        let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: keyword, triggers: triggers)
        guard triggers.standardDeviation, keyword == .physical || sharedKeyword == .physical else { return }
        let doubled: Bool
        if context.hasHeroCard(for: sourceActorID) {
            if let stored = context.resolution.cardTalents?.standardDeviationDouble {
                doubled = stored
            } else {
                doubled = Bool.random(using: &context.rng)
                context.mutateHeroCard { $0.standardDeviationDouble = doubled }
            }
        } else {
            doubled = Bool.random(using: &context.rng)
        }
        applyDoubledOrCeilHalved(to: &state, doubled: doubled)
    }

    /// Legacy Standard Deviation halves with upward rounding.
    private static func applyDoubledOrCeilHalved(to state: inout DamageResolutionState, doubled: Bool) {
        state.remaining = doubled ? SaturatedArithmetic.saturatingMul(state.remaining, 2)
            : state.remaining / 2 + state.remaining % 2
    }

    private static func applyBurnDamageMultipliers(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0,
              let sourceActorID = state.sourceActorID else { return }
        let triggers = context.modifiers(for: sourceActorID).triggers
        let sharedKeyword = state.damageKeyword.flatMap { UniqueCombatEngine.sharedDamageKeyword(for: $0, triggers: triggers) }
        guard state.damageKeyword == .burn || sharedKeyword == .burn else { return }
        if state.options.isAttackHit, state.damageKeyword == .burn, state.targetStatus.isBleeding {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: triggers.burnAttackDamageVsBleedingMultiplier)
        }
        if BattleChance.succeeds(probability: triggers.burnDamageDoubleChancePercent, using: &context.rng) {
            state.remaining = SaturatedArithmetic.saturatingMul(state.remaining, 2)
        }
        if state.options.isAttackHit,
           !state.options.isRetaliation || state.options.isCounterattack || state.options.isCardAttack,
           triggers.burnAttackDoubleChancePercent > 0,
           context.claimTalentAbility(.burnAttackDoubleChance, actorID: sourceActorID),
           BattleChance.succeeds(probability: triggers.burnAttackDoubleChancePercent, using: &context.rng) {
            state.remaining = SaturatedArithmetic.saturatingMul(state.remaining, 2)
        }
        if context.roster.hasControlStatus(for: state.combatant, keyword: .freeze),
           BattleChance.succeeds(probability: triggers.burnDoubleVsFrozenChancePercent, using: &context.rng) {
            state.remaining = SaturatedArithmetic.saturatingMul(state.remaining, 2)
        }
    }

    private static func applyBaseAndScaledDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        var statBonus = 0
        var itemBonus = 0
        if let sourceActorID = state.sourceActorID,
           let damageKeyword = state.damageKeyword,
           let actor = context.roster.combatant(for: sourceActorID) {
            let profile = context.modifiers(for: sourceActorID)
            statBonus = state.options.applyStatBonus
                ? CombatRounding.scaled(state.amount, multiplier: profile.outgoingDamagePercent)
                : 0
            itemBonus = state.options.applyItemBonus
                ? outgoingDamageBonus(
                    for: sourceActorID,
                    keyword: damageKeyword,
                    in: context,
                )
                : 0
            if state.options.isAttackHit, profile.triggers.firstHitDoubleDamage,
               !actor.hasTriggeredFirstHitBonus {
                itemBonus = SaturatedArithmetic.saturatingAdd(
                    itemBonus, SaturatedArithmetic.saturatingAdd(state.amount, statBonus),
                )
                context.roster.mutateRuntime(for: actor.combatant) { $0.hasTriggeredFirstHitBonus = true }
            }
            if state.options.applyItemBonus {
                itemBonus = SaturatedArithmetic.saturatingAdd(
                    itemBonus,
                    CombatTriggerEngine.damageBonus(for: state, in: &context),
                )
            }
        }
        state.remaining = SaturatedArithmetic.saturatingAdd(
            SaturatedArithmetic.saturatingAdd(state.amount, statBonus), itemBonus,
        )
        applyConditionalDamageBonuses(to: &state, in: context)
    }

    private static func applyPercentBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.applyItemBonus,
              let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword
        else { return }
        let profile = context.modifiers(for: sourceActorID)
        var percent = profile.damageDealtPercent(for: damageKeyword)
        if let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: damageKeyword, triggers: profile.triggers) {
            percent += profile.damageDealtPercents[sharedKeyword, default: 0]
        }
        percent = max(0, percent)
        let percentBonus = CombatRounding.scaled(max(0, state.remaining), multiplier: percent)
        state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, percentBonus)
    }

    private static func applyDodgeEmpoweredBonuses(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID)?.combatant else { return }
        let cardSerial = context.resolution.cardTalents?.playSerial
        let actionID = context.resolution.actionID
        let turn = context.turnCount
        // No reactions run between these preparations; borrow their owner once.
        context.roster.mutateRuntime(for: source) { runtime in
            if runtime.talents.pending.doubleDamageAfterDodge {
                state.remaining = SaturatedArithmetic.saturatingMul(state.remaining, 2)
                runtime.talents.pending.doubleDamageAfterDodge = false
            }
            if runtime.talents.pending.doubleNextAttackAfterDeathsDoor {
                state.remaining = SaturatedArithmetic.saturatingMul(state.remaining, 2)
                runtime.talents.pending.doubleNextAttackAfterDeathsDoor = false
            }
            let preparedDamage = SaturatedArithmetic.saturatingAdd(
                runtime.talents.pending.cardDamageBonus, runtime.talents.pending.feintStrikeDamageBonus,
            )
            if preparedDamage > 0 {
                state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, preparedDamage)
                runtime.talents.pending.cardDamageBonus = 0
                runtime.talents.pending.feintStrikeDamageBonus = 0
            }
            if runtime.talents.pending.cardDamagePercent > 0 {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + runtime.talents.pending.cardDamagePercent)
                runtime.talents.pending.cardDamagePercent = 0
            }
            if let percent = runtime.talents.pending.overchargePercent?.availableValue(cardSerial: cardSerial, actionID: actionID) {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + percent)
                runtime.talents.pending.overchargePercent = nil
            }
            if runtime.talents.pending.damageAfterDodge > 0 {
                state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, runtime.talents.pending.damageAfterDodge)
                runtime.talents.pending.damageAfterDodge = 0
            }
            if runtime.talents.timed.damage.amount > 0, turn < runtime.talents.timed.damage.expiresAtTurn {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + runtime.talents.timed.damage.amount)
            }
        }
    }

    private static func applyStunnedAndTalentMultipliers(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        if let sourceActorID = state.sourceActorID,
           state.targetStatus.isStunned {
            let profile = context.modifiers(for: sourceActorID)
            let multiplier = profile.triggers.stunnedDamageMultiplier
            if multiplier > 1 {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: multiplier)
            }
        }
        if state.options.applyItemBonus {
            let talentMultiplier = CombatTriggerEngine.damageMultiplier(for: state, in: context)
            if talentMultiplier != 1 {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: talentMultiplier)
                appendAfflictedAuraLogEvents(to: &state, in: &context)
            }
        }
        applyHallowbreak(to: &state, in: context)
        applyTalentStatusMultipliers(to: &state, in: &context)
        applyCompanionStatusMultipliers(to: &state, in: &context)
        applyTalentBlockConsumption(to: &state, in: &context)
    }

    private static func applyTalentBlockConsumption(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let keyword = state.damageKeyword,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              state.combatant.role == .enemy
        else { return }
        let triggers = context.modifiers(for: sourceActorID).triggers
        let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: keyword, triggers: triggers)
        if keyword == .stun, state.options.isAttackHit, triggers.stolenThunder {
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source.combatant))
            if block > 0, context.claimActionGuard(.stolenThunder, actorID: source.id) {
                DefensePoolEngine.set(0, on: source.combatant, in: &context)
                state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, block)
            }
        }
        guard keyword == .physical || sharedKeyword == .physical, state.options.isAttackHit, !state.options.isRetaliation else { return }
        var stored = 0
        if CombatTriggerEngine.hasLivingPartyTrigger(\.storedImpact, in: context) {
            for owner in BattleParticipant.party {
                stored = SaturatedArithmetic.saturatingAdd(stored, context.roster[owner].talents.battle.storedBlockedDamage)
                context.roster[owner].talents.battle.storedBlockedDamage = 0
            }
        }
        if stored > 0 {
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, stored)
        }
    }

    private static func appendAfflictedAuraLogEvents(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let source = state.partySource(in: context) else { return }
        let target = state.combatant
        let names = CombatTriggerEngine.partyAfflictedDamageNames(
            targetIsPoisoned: state.targetStatus.isPoisoned,
            targetIsBurning: state.targetStatus.isBurning,
            in: context,
        )
        for name in names {
            context.nextEvent(
                kind: .ability,
                source: .init(source),
                abilityName: name,
                target: target,
                amount: 0,
                keyword: state.damageKeyword ?? .physical,
            )
        }
    }

    private static func applyOneShotEmpowers(
        to state: inout DamageResolutionState,
    ) {
        state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, state.pendingAttackBonus)
        if state.damageKeyword == .holy {
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, state.pendingHolyBonus)
        } else {
            state.additionalHolyDamage = SaturatedArithmetic.saturatingAdd(state.additionalHolyDamage, state.pendingHolyBonus)
        }
    }

    static func reserveAttackEmpowers(to state: inout DamageResolutionState, in context: inout BattleState) {
        guard state.options.isAttackHit, let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID) else { return }
        let fullHealthBonus = context.consumeTalentPreparation(\.attackBonusOnFullHealth, for: source.combatant) ?? 0
        context.roster.mutateRuntime(for: source.combatant) { runtime in
            let bonuses = runtime.talents.pending.reserveAttackBonuses()
            state.pendingAttackBonus = SaturatedArithmetic.saturatingAdd(
                SaturatedArithmetic.saturatingAdd(bonuses.damage, fullHealthBonus), runtime.talents.battle.damageBonus,
            )
            state.pendingHolyBonus = bonuses.holy
        }
    }

    private static func applyOutgoingReductions(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID)?.combatant else { return }
        let sourceEffects = context.roster.activeEffects(for: source)
        let sourceStatus = DamageTargetStatus(for: source, in: context)
        let sourceBleedStacks = sourceEffects.count(where: \.effect.isBleed)
        var reductionFlat = 0
        var reductionMultiplier = 1.0
        for opponent in BattleActionContext(actor: source, in: context).opponents(in: context)
            where context.roster.health(for: opponent) > 0 {
            let t = context.modifiers(for: opponent.id).triggers
            if sourceStatus.isFrozen {
                reductionFlat = SaturatedArithmetic.saturatingAdd(reductionFlat, t.frozenEnemyDamageReductionFlat)
            }
            if sourceStatus.isBleeding {
                reductionFlat = SaturatedArithmetic.saturatingAdd(reductionFlat, t.bleedingEnemyDamageReductionFlat)
                reductionMultiplier *= t.bleedingEnemyOutgoingDamageMultiplier
            }
            if sourceStatus.isBurning {
                reductionFlat = SaturatedArithmetic.saturatingAdd(reductionFlat, t.burningEnemyDamageReductionFlat)
            }
            if sourceStatus.isPoisoned {
                reductionMultiplier *= (1 - min(1, t.poisonedEnemyAccuracyPenaltyPercent))
            }
            if sourceStatus.isBleeding, t.enemyBleedStacksDamageReductionStacks > 0,
               sourceBleedStacks >= t.enemyBleedStacksDamageReductionStacks {
                reductionMultiplier *= (1 - min(1, t.enemyBleedStacksDamageReductionPercent))
            }
        }
        for active in sourceEffects {
            switch active.effect {
            case let .damageReductionPercent(percent, _):
                reductionMultiplier *= (1 - min(1, percent))
            case let .damageReductionFlat(amount, _):
                reductionFlat = SaturatedArithmetic.saturatingAdd(reductionFlat, amount)
            default:
                continue
            }
        }
        state.remaining = max(0, CombatRounding.scaled(state.remaining, multiplier: reductionMultiplier) - reductionFlat)
    }

    static func applyFightPacing(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0 else { return }
        state.remaining = context.paced(state.remaining, sourceActorID: state.sourceActorID)
    }

    static func outgoingDamageBonus(
        for sourceActorID: String,
        keyword: Keyword,
        in context: BattleState,
    ) -> Int {
        let profile = context.modifiers(for: sourceActorID)
        var bonus = profile.damageDealtBonus(for: keyword)
        let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: keyword, triggers: profile.triggers)
        if let sharedKeyword {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, profile.damageDealtBonus(for: sharedKeyword))
        }
        if sourceActorID == context.roster.companion.id {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, context.heroModifiers.companionDamageDealtBonus)
            bonus = SaturatedArithmetic.saturatingAdd(bonus, profile.companionDamageDealtBonus)
            if keyword == .physical || sharedKeyword == .physical {
                bonus = SaturatedArithmetic.saturatingAdd(bonus, context.heroModifiers.companionPhysicalDamageDealtBonus)
                bonus = SaturatedArithmetic.saturatingAdd(bonus, profile.companionPhysicalDamageDealtBonus)
            }
            if keyword == .bleed || sharedKeyword == .bleed {
                bonus = SaturatedArithmetic.saturatingAdd(bonus, context.heroModifiers.companionBleedDamageDealtBonus)
                bonus = SaturatedArithmetic.saturatingAdd(bonus, profile.companionBleedDamageDealtBonus)
            }
        }
        if let source = context.roster.combatant(for: sourceActorID) {
            bonus = SaturatedArithmetic.saturatingAdd(
                bonus,
                source.talents.battle.keywordDamageRamp[keyword, default: 0],
            )
            if let sharedKeyword {
                bonus = SaturatedArithmetic.saturatingAdd(
                    bonus,
                    source.talents.battle.keywordDamageRamp[sharedKeyword, default: 0],
                )
            }
        }
        return bonus
    }

    static func applyCriticalMultiply(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.isCritical, state.remaining > 0 else {
            return
        }
        let critMultiplier = criticalMultiplier(for: state.sourceActorID, in: context)
        let bonus = state.sourceActorID.map { context.modifiers(for: $0).criticalDamageBonus } ?? 0
        let percent = state.sourceActorID.map { context.modifiers(for: $0).criticalDamagePercent } ?? 0
        let criticalDamage = SaturatedArithmetic.saturatingAdd(
            CombatRounding.scaled(state.remaining, multiplier: critMultiplier), bonus,
        )
        state.remaining = CombatRounding.scaled(criticalDamage, multiplier: 1 + percent)
        if state.options.isAttackHit, let keyword = state.damageKeyword, let sourceActorID = state.sourceActorID {
            let triggers = context.modifiers(for: sourceActorID).triggers
            let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: keyword, triggers: triggers)
            if keyword == .burn || sharedKeyword == .burn {
                state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, triggers.burnCriticalDamageBonus)
            }
            if keyword == .poison {
                state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, triggers.poisonCriticalDamageBonus)
            }
        }
    }

    static func criticalMultiplier(for sourceActorID: String?, in context: BattleState) -> Double {
        var multiplier = 2.0
        if let sourceActorID,
           let source = context.roster.combatant(for: sourceActorID) {
            multiplier += source.talents.battle.criticalMultiplierBonus
        }
        return multiplier
    }

    static func applyConditionalDamageBonuses(to state: inout DamageResolutionState, in context: BattleState) {
        guard state.amount > 0, state.combatant.role == .enemy,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID), source.role != .enemy
        else { return }
        let triggers = context.modifiers(for: sourceActorID).triggers
        var bonus = 0
        if state.damageKeyword == .poison, state.targetStatus.isBleeding {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.poisonDamageVsBleedingFlat)
        }
        if state.options.isThornsDamage, state.targetStatus.isPoisoned {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.thornsDamageVsPoisonedFlat)
        }
        if state.damageKeyword == .burn, state.targetStatus.isBleeding {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.burnDamageVsBleedingFlat)
        }
        if state.damageKeyword == .burn, state.targetStatus.isPoisoned {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.burnDamageVsPoisonedFlat)
        }
        if state.damageKeyword == .bleed, state.targetStatus.isBurning {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.bleedDamageVsBurningFlat)
        }
        if state.damageKeyword == .bleed, state.targetStatus.isPoisoned {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.bleedDamageVsPoisonedFlat)
        }
        if state.options.isAttackHit {
            if state.damageKeyword == .holy, state.targetStatus.isPoisoned {
                bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.holyAttackDamageVsPoisonedFlat)
            }
            if state.damageKeyword == .physical, state.targetStatus.isBurning || state.targetStatus.isFrozen {
                bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.physicalAttackDamageVsBurningOrFrozenFlat)
            }
        }
        state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
    }

    static func applyHallowbreak(to state: inout DamageResolutionState, in context: BattleState) {
        guard state.damageKeyword == .holy, state.targetStatus.isStunned,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID), source.role != .enemy
        else { return }
        let bonus = context.modifiers(for: sourceActorID).triggers.holyDamageVsStunnedPercent
        if bonus > 0 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + bonus)
        }
    }

    static func applyMarkedBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit, state.sourceActorID != nil else { return }
        for active in context.roster.activeEffects(for: state.combatant) {
            if case let .marked(bonus, _) = active.effect {
                state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
                state.markedBonusApplied = true
                break
            }
        }
    }
}
