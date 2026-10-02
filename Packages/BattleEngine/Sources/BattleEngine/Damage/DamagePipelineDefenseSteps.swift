import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyPreparedAttackReduction(to state: inout DamageResolutionState, in context: inout BattleState) {
        guard state.options.isAttackHit, !state.options.isRetaliation else { return }
        state.remaining -= context.resolution.consumeAttackReduction(for: state.sourceActorID, damage: state.remaining)
        applyFinalCompanionEnemyAttackReduction(to: &state, in: &context)
    }

    static func applyTakenPercentAdjustments(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0 else {
            return
        }
        guard let damageKeyword = state.damageKeyword else {
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
            talentResistance = max(
                talentResistance,
                companionBleedResistance(for: state.combatant, keyword: damageKeyword, in: context),
            )
        }
        if damageKeyword == .poison {
            talentResistance = max(talentResistance, defenderTriggers.afflictionResistance)
        }
        if damageKeyword == .burn,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: state.combatant)) > 0 {
            talentResistance = max(talentResistance, defenderTriggers.blockedControlBurnResistance)
        }
        if defenderTriggers.blockHalvesDoTDamage,
           damageKeyword == .burn || damageKeyword == .poison || damageKeyword == .bleed,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: state.combatant)) > 0 {
            talentResistance = max(talentResistance, 0.5)
        }
        let hasThorns = context.roster.activeEffects(for: state.combatant).contains {
            $0.effect.kind == .thorns && ($0.effect.potency ?? 0) > 0
        }
        if damageKeyword == .poison, hasThorns, defenderTriggers.livingBark {
            talentResistance = max(talentResistance, 0.5)
        }
        if talentResistance > 0 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 - min(1, talentResistance) * reductionMultiplier)
        }
        if state.combatant.role != .enemy, context.roster.hero.isAlive, hasThorns,
           context.roster.health(for: state.combatant) * 2 > context.roster.maxHealth(for: state.combatant) {
            state.remaining = CombatRounding.scaled(
                state.remaining,
                multiplier: context.heroModifiers.triggers.verdantShelterDamageMultiplier,
            )
        }
        applyCompanionDefenseMultipliers(to: &state, in: context)
        applyPreparedIncomingProtection(to: &state, in: &context)
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
        remaining = applyPassiveMitigations(
            remaining, defenderTriggers: defenderTriggers,
            damageKeyword: state.damageKeyword, effectiveReduction: effectiveReduction,
        )
        state.remaining = remaining
        applyCompanionFlatDefense(to: &state, in: context)
        remaining = state.remaining
        remaining = applySpellBlockReduction(
            remaining, state: state, defenderTriggers: defenderTriggers,
            effectiveReduction: effectiveReduction, in: &context,
        )
        applyGuardianBlock(to: &state, in: &context)
        if defenderTriggers.damageReductionPerUnspentManaEvery > 0,
           let runtime = context.roster.runtime(for: state.combatant),
           runtime.maxMana > 0,
           runtime.currentMana > 0 {
            remaining = max(0, remaining - effectiveReduction(runtime.currentMana / defenderTriggers.damageReductionPerUnspentManaEvery))
        }

        let flatReductionBonus = context.roster.runtime(for: state.combatant)?.talents.battle.flatDamageReductionBonus ?? 0
        if flatReductionBonus > 0 {
            remaining = max(0, remaining - effectiveReduction(flatReductionBonus))
        }

        state.remaining = remaining
    }

    private static func applyPassiveMitigations(
        _ remaining: Int,
        defenderTriggers: CombatTraitTriggers,
        damageKeyword: Keyword?,
        effectiveReduction: (Int) -> Int,
    ) -> Int {
        var remaining = remaining
        if defenderTriggers.passiveMitigationFlat > 0 {
            remaining = max(0, remaining - effectiveReduction(defenderTriggers.passiveMitigationFlat))
        }
        if damageKeyword == .physical, defenderTriggers.passivePhysicalMitigationFlat > 0 {
            remaining = max(0, remaining - effectiveReduction(defenderTriggers.passivePhysicalMitigationFlat))
        }
        return remaining
    }

    private static func applySpellBlockReduction(
        _ remaining: Int,
        state: DamageResolutionState,
        defenderTriggers: CombatTraitTriggers,
        effectiveReduction: (Int) -> Int,
        in context: inout BattleState,
    ) -> Int {
        var remaining = remaining
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
                let multiplier = DamageDefensePolicy.mitigationMultiplier(state: state, context: context)
                remaining = CombatRounding.scaled(remaining, multiplier: 1 - protection * multiplier)
            }
        }
        return remaining
    }

    private static func applyGuardianBlock(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.combatant.role == .hero,
              context.roster.companion.isAlive,
              context.companionModifiers.triggers.guardianHeroBlockFlat > 0,
              state.options.isAttackHit, !state.options.isRetaliation,
              context.claimHeroTalent("Guardian", actorID: context.roster.companion.id, battle: true)
        else { return }
        let block = context.companionModifiers.triggers.guardianHeroBlockFlat
        let granted = context.applyBlockGain(
            block,
            to: state.combatant,
            source: context.roster.companion.combatant,
            abilityName: "Guardian",
            origin: .automatic,
        )
        state.damageEvents.append(contentsOf: granted.events)
    }
}
