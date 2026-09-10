import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyPreparedAttackReduction(to state: inout DamageResolutionState, in context: inout BattleState) {
        guard state.options.isAttackHit, !state.options.isRetaliation,
              let action = context.heroTalents.actions.last, action.actorID == state.sourceActorID else { return }
        let reduction = min(max(0, state.remaining), action.blindingReduction)
        state.remaining -= reduction
        context.heroTalents.actions[context.heroTalents.actions.count - 1].blindingReduction -= reduction
    }

    static func applyDamageBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        applyBaseAndScaledDamage(to: &state, in: &context)
        if state.options.isAttackHit, state.amount > 0,
           let action = context.heroTalents.actions.last, action.actorID == state.sourceActorID {
            state.remaining += action.goldDamage
            state.itemBonus += action.goldDamage
            context.heroTalents.actions[context.heroTalents.actions.count - 1].goldDamage = 0
        }
        applyPercentBonus(to: &state, in: &context)
        applyDodgeEmpoweredBonuses(to: &state, in: &context)
        applyStunnedAndTalentMultipliers(to: &state, in: &context)
        applyOneShotEmpowers(to: &state, in: &context)
        applyOutgoingReductions(to: &state, in: &context)
        state.dealt = state.remaining
    }

    private static func applyBaseAndScaledDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        if let sourceActorID = state.sourceActorID,
           let damageKeyword = state.damageKeyword,
           let actor = context.roster.combatant(for: sourceActorID) {
            state.statBonus = state.options.applyStatBonus
                ? CombatRounding.scaled(state.amount, multiplier: context.modifiers(for: sourceActorID).outgoingDamagePercent)
                : 0
            state.itemBonus = state.options.applyItemBonus
                ? outgoingDamageBonus(
                    for: sourceActorID,
                    keyword: damageKeyword,
                    in: context,
                )
                : 0
            if state.options.isAttackHit,
               var runtime = context.roster.runtime(for: actor.combatant) {
                let profile = context.modifiers(for: sourceActorID)
                if !runtime.hasTriggeredFirstHitBonus, profile.triggers.firstHitDoubleDamage {
                    state.itemBonus += (state.amount + state.statBonus)
                    runtime.hasTriggeredFirstHitBonus = true
                    context.roster.update(runtime)
                }
            }
            if state.options.applyItemBonus {
                state.itemBonus += CombatTriggerEngine.damageBonus(for: state, in: &context)
            }
        }
        state.remaining = state.amount + state.statBonus + state.itemBonus
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
        let percent = profile.damageDealtPercent(for: damageKeyword)
        let percentBonus = CombatRounding.scaled(max(0, state.remaining), multiplier: percent)
        state.itemBonus += percentBonus
        state.remaining += percentBonus
    }

    private static func applyDodgeEmpoweredBonuses(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              let runtime = context.roster.runtime(for: source.combatant)
        else { return }
        if runtime.pendingDamageDoubleAfterDodge {
            state.remaining *= 2
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingDamageDoubleAfterDodge = false }
        }
        if runtime.pendingCardDamageBonus > 0 {
            state.remaining += runtime.pendingCardDamageBonus
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingCardDamageBonus = 0 }
        }
        if runtime.pendingCardDamagePercent > 0 {
            state.remaining = CombatRounding.scaled(
                state.remaining,
                multiplier: 1 + runtime.pendingCardDamagePercent,
            )
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingCardDamagePercent = 0 }
        }
        if runtime.pendingDamageAfterDodge > 0 {
            state.remaining += runtime.pendingDamageAfterDodge
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingDamageAfterDodge = 0 }
        }
        if runtime.talentDamagePercentBonus > 0, context.turnCount < runtime.talentDamagePercentUntilTurn {
            state.remaining = CombatRounding.scaled(
                state.remaining,
                multiplier: 1 + runtime.talentDamagePercentBonus,
            )
        }
    }

    private static func applyStunnedAndTalentMultipliers(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        if state.options.isAttackHit,
           let sourceActorID = state.sourceActorID,
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
        applyTalentStatusMultipliers(to: &state, in: &context)
        applyTalentBlockConsumption(to: &state, in: &context)
    }

    private static func applyTalentStatusMultipliers(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let keyword = state.damageKeyword,
              let sourceActorID = state.sourceActorID,
              state.combatant.role == .enemy
        else { return }
        let triggers = context.modifiers(for: sourceActorID).triggers
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
        if keyword == .stun, state.options.isAttackHit, triggers.stolenThunder {
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source.combatant))
            if block > 0, context.claimActionGuard(.stolenThunder, actorID: source.id) {
                DefensePoolEngine.set(0, on: source.combatant, in: &context)
                state.remaining += block
            }
        }
        guard keyword == .physical, state.options.isAttackHit, !state.options.isRetaliation else { return }
        if triggers.batteringRam {
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source.combatant))
            if block > 0, let reduced = DefensePoolEngine.reduce(block, in: context.roster.activeEffects(for: source.combatant)) {
                context.roster.setActiveEffects(reduced.effects, for: source.combatant)
                state.remaining += reduced.absorbed
            }
        }
        var stored = 0
        if CombatTriggerEngine.hasLivingPartyTrigger(\.storedImpact, in: context) {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                if let val = context.storedBlockedDamageByActorID.removeValue(forKey: member.id) {
                    stored += val
                }
            }
            if let extra = context.storedBlockedDamageByActorID.removeValue(forKey: source.id) {
                stored += extra
            }
        } else if triggers.storedImpact {
            stored += context.storedBlockedDamageByActorID.removeValue(forKey: source.id) ?? 0
        }
        if stored > 0 {
            state.remaining += stored
        }
    }

    private static func appendAfflictedAuraLogEvents(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let source = state.partySource(in: context) else { return }
        let target = state.combatant
        let names = CombatTriggerEngine.partyAfflictedDamageAuras(
            targetIsPoisoned: state.targetStatus.isPoisoned,
            targetIsBurning: state.targetStatus.isBurning,
            in: context,
        ).abilityNames
        for name in names {
            state.damageEvents.append(context.nextEvent(
                kind: .ability,
                actorName: source.name,
                abilityName: name,
                target: target,
                amount: 0,
                keyword: state.damageKeyword ?? .physical,
            ))
        }
    }

    private static func applyOneShotEmpowers(
        to state: inout DamageResolutionState,
        in _: inout BattleState,
    ) {
        state.remaining += state.pendingAttackBonus
        if state.damageKeyword == .holy {
            state.remaining += state.pendingHolyBonus
        } else {
            state.additionalHolyDamage += state.pendingHolyBonus
        }
    }

    static func reserveAttackEmpowers(to state: inout DamageResolutionState, in context: inout BattleState) {
        guard state.options.isAttackHit, let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID) else { return }
        context.roster.mutateRuntime(for: source.combatant) { runtime in
            state.pendingAttackBonus = runtime.pendingNextHitBonus + runtime.pendingAttackBonusOnFullHealth + runtime.permanentDamageBonus
            state.pendingHolyBonus = runtime.pendingNextAttackHolyBonus
            runtime.pendingNextHitBonus = 0
            runtime.pendingAttackBonusOnFullHealth = 0
            runtime.pendingNextAttackHolyBonus = 0
        }
    }

    private static func applyOutgoingReductions(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID)?.combatant else { return }
        let sourceIsFrozen = context.roster.hasControlStatus(for: source, keyword: .freeze)
        let sourceIsStunned = context.roster.hasControlStatus(for: source, keyword: .stun)
        let sourceIsPoisoned = context.roster.hasAffliction(.poison, on: source)
        let sourceIsBleeding = context.roster.hasAffliction(.bleed, on: source)
        let sourceIsBurning = context.roster.hasAffliction(.burn, on: source)
        let sourceBleedStacks = context.roster.activeEffects(for: source).count(where: { $0.effect.isBleed })
        var reductionFlat = 0
        var reductionMultiplier = 1.0
        for opponent in BattleActionContext(actor: source, in: context).opponents(in: context)
            where context.roster.health(for: opponent) > 0 {
            let t = context.modifiers(for: opponent.id).triggers
            if sourceIsFrozen {
                reductionFlat += t.frozenEnemyDamageReductionFlat
            }
            if sourceIsBleeding {
                reductionFlat += t.bleedingEnemyDamageReductionFlat
            }
            if sourceIsBurning {
                reductionFlat += t.burningEnemyDamageReductionFlat
            }
            if sourceIsStunned {
                reductionMultiplier *= t.stunnedEnemyNextTurnDamageMultiplier
            }
            if sourceIsPoisoned {
                reductionMultiplier *= (1 - min(1, t.poisonedEnemyAccuracyPenaltyPercent))
            }
            if sourceIsBleeding, t.enemyBleedStacksDamageReductionStacks > 0,
               sourceBleedStacks >= t.enemyBleedStacksDamageReductionStacks {
                reductionMultiplier *= (1 - min(1, t.enemyBleedStacksDamageReductionPercent))
            }
        }
        for active in context.roster.activeEffects(for: source) {
            switch active.effect {
            case let .damageReductionPercent(percent, _):
                reductionMultiplier *= (1 - min(1, percent))
            case let .damageReductionFlat(amount, _):
                reductionFlat += amount
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
        state.dealt = state.remaining
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
            bonus += profile.damageDealtBonus(for: sharedKeyword)
        }
        if sourceActorID == context.roster.companion.id {
            bonus += context.heroModifiers.companionDamageDealtBonus + profile.companionDamageDealtBonus
            if keyword == .bleed || sharedKeyword == .bleed {
                bonus += context.heroModifiers.companionBleedDamageDealtBonus
            }
        }
        if let source = context.roster.combatant(for: sourceActorID) {
            bonus += context.roster.runtime(for: source.combatant)?.keywordDamageRamp[keyword, default: 0] ?? 0
            if let sharedKeyword {
                bonus += context.roster.runtime(for: source.combatant)?.keywordDamageRamp[sharedKeyword, default: 0] ?? 0
            }
        }
        return bonus
    }

    static func applyMarkedBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit, state.sourceActorID != nil else { return }
        for active in context.roster.activeEffects(for: state.combatant) {
            if case let .marked(bonus, _) = active.effect {
                state.remaining += bonus
                state.dealt += bonus
                state.markedBonusApplied = true
                break
            }
        }
    }

    static func applyTakenPercentAdjustments(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0 else {
            state.buildupDamage = 0
            return
        }
        guard let damageKeyword = state.damageKeyword else {
            state.buildupDamage = state.remaining
            return
        }
        let profile = context.modifiers(for: state.combatant.id)
        let reductionMultiplier = DamageDefensePolicy.mitigationMultiplier(state: state, context: context)
        let flatReduction = CombatRounding.scaled(profile.damageTakenFlat(for: damageKeyword), multiplier: reductionMultiplier)
        if flatReduction > 0 {
            state.remaining = max(0, state.remaining - flatReduction)
        }
        let reduction = min(1, profile.damageTakenReduction(for: damageKeyword) + profile.incomingDamageReductionPercent)
        let effectiveReduction = reduction * reductionMultiplier
        if effectiveReduction > 0 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 - effectiveReduction)
        }
        let vulnerability = profile.damageTakenVulnerability(for: damageKeyword)
        if vulnerability > 0 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + vulnerability)
        }
        let defenderTriggers = profile.triggers
        var talentResistance = 0.0
        if damageKeyword == .bleed {
            talentResistance = max(talentResistance, defenderTriggers.bleedResistance, defenderTriggers.afflictionResistance)
        }
        if damageKeyword == .poison {
            talentResistance = max(talentResistance, defenderTriggers.afflictionResistance)
        }
        if damageKeyword == .burn,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: state.combatant)) > 0 {
            talentResistance = max(talentResistance, defenderTriggers.blockedControlBurnResistance)
        }
        if talentResistance > 0 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 - min(1, talentResistance) * reductionMultiplier)
        }
        state.buildupDamage = state.remaining
    }

    static func applyCriticalMultiply(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.isCritical, state.remaining > 0 else {
            state.buildupDamage = state.remaining
            return
        }
        let critMultiplier = criticalMultiplier(for: state.sourceActorID, in: context)
        state.remaining = CombatRounding.scaled(state.remaining, multiplier: critMultiplier)
        state.dealt = state.remaining
        state.buildupDamage = state.remaining
    }

    static func criticalMultiplier(for sourceActorID: String?, in context: BattleState) -> Double {
        var multiplier = 2.0
        if let sourceActorID,
           let source = context.roster.combatant(for: sourceActorID) {
            multiplier += context.roster.runtime(for: source.combatant)?.talentCritMultiplierBonus ?? 0
        }
        return multiplier
    }

    static func applyTakenFlatAdjustments(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0 else { return }

        let profile = context.modifiers(for: state.combatant.id)
        let defenderTriggers = profile.triggers
        let multiplier = DamageDefensePolicy.mitigationMultiplier(state: state, context: context)
        func effectiveReduction(_ amount: Int) -> Int {
            CombatRounding.scaled(amount, multiplier: multiplier)
        }
        var remaining = state.remaining
        if defenderTriggers.passiveMitigationFlat > 0 {
            remaining = max(0, remaining - effectiveReduction(defenderTriggers.passiveMitigationFlat))
        }

        if state.damageKeyword != .physical,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: state.combatant)) > 0,
           defenderTriggers.spellDamageTakenReductionWhileBlocked > 0 {
            remaining = max(0, remaining - effectiveReduction(defenderTriggers.spellDamageTakenReductionWhileBlocked))
        }

        if state.combatant.role == .hero,
           context.roster.companion.isAlive,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: context.roster.companion.combatant)) > 0 {
            let protection = min(1, max(0, context.companionModifiers.triggers.companionBlockProtectsHeroPercent))
            if protection > 0 {
                remaining = CombatRounding.scaled(remaining, multiplier: 1 - protection * multiplier)
            }
        }
        if state.combatant.role == .hero,
           context.roster.companion.isAlive,
           context.companionModifiers.triggers.absorbHeroDamageFlat > 0 {
            remaining = max(0, remaining - effectiveReduction(context.companionModifiers.triggers.absorbHeroDamageFlat))
        }
        if defenderTriggers.damageReductionPerUnspentManaEvery > 0,
           let runtime = context.roster.runtime(for: state.combatant),
           runtime.maxMana > 0,
           runtime.currentMana > 0 {
            remaining = max(0, remaining - effectiveReduction(runtime.currentMana / defenderTriggers.damageReductionPerUnspentManaEvery))
        }

        let flatReductionBonus = context.roster.runtime(for: state.combatant)?.flatDamageReductionBonus ?? 0
        if flatReductionBonus > 0 {
            remaining = max(0, remaining - effectiveReduction(flatReductionBonus))
        }

        state.remaining = remaining
        state.buildupDamage = state.remaining
        assert(
            state.buildupDamage == state.remaining,
            "buildupDamage invariant: \(state.buildupDamage) != remaining \(state.remaining) after applyTakenFlatAdjustments",
        )
    }

    static func applyMarkedConsume(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.markedBonusApplied else { return }

        var markedBonus: Int?
        for active in context.roster.activeEffects(for: state.combatant) {
            if case let .marked(bonus, _) = active.effect {
                markedBonus = bonus
                break
            }
        }
        guard let bonus = markedBonus else { return }

        ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
            if case .marked = $0 {
                return true
            }
            return false
        }
        state.damageEvents.append(context.nextEvent(
            kind: .effect,
            effectKind: .markedConsumed,
            actorName: state.combatant.name,
            abilityName: "Marked",
            target: state.combatant,
            amount: bonus,
            keyword: .physical,
        ))
    }

    static func applyDeathsDoor(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        state.damageEvents.append(contentsOf: DeathsDoorEngine.resolveAfterDamage(
            to: state.combatant,
            in: &context,
        ))
    }
}
