import TrinketContent
import TrinketCore

package extension BattleState {
    mutating func resolveDamage(_ request: DamageRequest) -> CombatOutcome {
        guard request.amount > 0 else { return .empty }

        talentReactionDepth += 1
        defer { talentReactionDepth -= 1 }
        var resolved = request
        if talentReactionDepth > 2 {
            resolved.options.isRetaliation = true
        }

        var state = DamageResolutionState(
            amount: resolved.amount,
            combatant: resolved.target,
            sourceActorID: resolved.sourceActorID,
            damageKeyword: resolved.keyword,
            applyStatBonus: resolved.options.applyStatBonus,
            applyItemBonus: resolved.options.applyItemBonus,
            applyDodge: resolved.options.applyDodge,
            abilityCriticalChanceBonus: resolved.options.abilityCriticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: resolved.options.guaranteedCriticalIfEnemyBuffed,
            guaranteedCritical: resolved.options.guaranteedCritical,
            isRetaliation: resolved.options.isRetaliation,
            applyControlMeter: resolved.options.applyControlMeter,
            qualifiesForAmbush: resolved.options.qualifiesForAmbush,
            isAttackHit: resolved.options.isAttackHit,
            isBasicAttackHit: resolved.options.isBasicAttackHit,
            abilityHasLeech: resolved.options.abilityHasLeech,
            isHealthCost: resolved.options.isHealthCost,
            causedByDodge: resolved.options.causedByDodge
        )
        state.activeEffects = roster.activeEffects(for: request.target)

        DamagePipeline.run(state: &state, in: &self)

        return CombatOutcome.fromDamage(state: state)
    }

    mutating func resolveHeal(_ request: HealRequest) -> CombatOutcome {
        HealingEngine.resolveHeal(request, in: &self)
    }

    mutating func applyControlMeter(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?
    ) -> [ActionEvent] {
        ControlMeterEngine.applyMeterCharge(
            amount,
            keyword: keyword,
            to: combatant,
            sourceActorID: sourceActorID,
            in: &self
        )
    }

    mutating func resolveDoTTick(
        basePotency: Int,
        keyword: Keyword,
        target: Combatant,
        sourceActorID: String?
    ) -> CombatOutcome {
        DoTDamage.resolveTurnDamage(
            basePotency: basePotency,
            keyword: keyword,
            target: target,
            sourceActorID: sourceActorID,
            in: &self
        )
    }

    mutating func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool,
        suppressAffixReactions: Bool = false
    ) -> [ActionEvent] {
        DoTApplicator.applyDecayingDoT(
            keyword: keyword,
            potency: potency,
            to: effectTarget,
            sourceActorID: sourceActorID,
            dealImmediateDamage: dealImmediateDamage,
            suppressAffixReactions: suppressAffixReactions,
            in: &self
        )
    }
}
