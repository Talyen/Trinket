import TrinketContent
import TrinketCore

package extension BattleState {
    mutating func resolveDamage(_ request: DamageRequest) -> CombatOutcome {
        guard request.amount > 0 else { return .empty }

        var state = DamageResolutionState(
            amount: request.amount,
            combatant: request.target,
            sourceActorID: request.sourceActorID,
            damageKeyword: request.keyword,
            applyStatBonus: request.options.applyStatBonus,
            applyItemBonus: request.options.applyItemBonus,
            applyDodge: request.options.applyDodge,
            abilityCriticalChanceBonus: request.options.abilityCriticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: request.options.guaranteedCriticalIfEnemyBuffed,
            guaranteedCritical: request.options.guaranteedCritical,
            isRetaliation: request.options.isRetaliation,
            applyControlMeter: request.options.applyControlMeter,
            qualifiesForAmbush: request.options.qualifiesForAmbush,
            isAttackHit: request.options.isAttackHit,
            abilityHasLeech: request.options.abilityHasLeech,
            isHealthCost: request.options.isHealthCost
        )
        state.activeEffects = roster.activeEffects(for: request.target)

        DamagePipeline.run(state: &state, in: &self)

        return CombatOutcome.fromDamage(state: state)
    }

    mutating func resolveHeal(_ request: HealRequest) -> CombatOutcome {
        HealingEngine.resolveHeal(request, in: &self)
    }

    mutating func applyLeechFromDamage(
        _ damage: Int,
        sourceActorID: String,
        abilityHasLeech: Bool = false
    ) -> [ActionEvent] {
        HealingEngine.leechFromDamage(
            damage,
            sourceActorID: sourceActorID,
            abilityHasLeech: abilityHasLeech,
            in: &self
        ).events
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
