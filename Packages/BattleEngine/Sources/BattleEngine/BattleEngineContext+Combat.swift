import Foundation
import TrinketCore
import TrinketContent

public extension BattleEngineContext {
    mutating func resolveDamage(_ request: DamageRequest) -> CombatOutcome {
        CombatPipeline.resolveDamage(request, in: &self)
    }

    mutating func resolveHeal(_ request: HealRequest) -> CombatOutcome {
        HealingEngine.resolveHeal(request, in: &self)
    }

    mutating func applyDamage(
        _ amount: Int,
        to combatant: Combatant,
        damageKeyword: Keyword? = nil,
        sourceActorID: String? = nil,
        applyStatBonus: Bool = true,
        applyItemBonus: Bool = true,
        applyDodge: Bool = true
    ) -> (healthLost: Int, damageEvents: [ActionEvent]) {
        let outcome = resolveDamage(
            DamageRequest(
                amount: amount,
                target: combatant,
                keyword: damageKeyword,
                sourceActorID: sourceActorID,
                options: DamageOptions(
                    applyStatBonus: applyStatBonus,
                    applyItemBonus: applyItemBonus,
                    applyDodge: applyDodge
                )
            )
        )
        return (outcome.healthLost, outcome.events)
    }

    mutating func applyHeal(_ amount: Int, to combatant: Combatant, sourceActorID: String? = nil) {
        _ = resolveHeal(
            HealRequest(amount: amount, target: combatant, sourceActorID: sourceActorID)
        )
    }

    mutating func applyLeechFromDamage(_ damage: Int, sourceActorID: String) -> [ActionEvent] {
        HealingEngine.leechFromDamage(damage, sourceActorID: sourceActorID, in: &self).events
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
        DoTDamage.resolveTick(
            basePotency: basePotency,
            keyword: keyword,
            target: target,
            sourceActorID: sourceActorID,
            in: &self
        )
    }

    mutating func applyDoTDamage(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?
    ) -> (healthLost: Int, events: [ActionEvent]) {
        let outcome = resolveDoTTick(
            basePotency: amount,
            keyword: keyword,
            target: combatant,
            sourceActorID: sourceActorID
        )
        return (outcome.healthLost, outcome.events)
    }

    mutating func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool
    ) -> [ActionEvent] {
        DoTApplicator.applyDecayingDoT(
            keyword: keyword,
            potency: potency,
            to: effectTarget,
            sourceActorID: sourceActorID,
            dealImmediateDamage: dealImmediateDamage,
            in: &self
        )
    }

    mutating func applyBleed(
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool
    ) -> [ActionEvent] {
        DoTApplicator.applyBleed(
            potency: potency,
            to: effectTarget,
            sourceActorID: sourceActorID,
            dealImmediateDamage: dealImmediateDamage,
            in: &self
        )
    }
}
