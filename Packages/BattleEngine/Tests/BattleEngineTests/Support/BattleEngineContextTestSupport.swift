import BattleEngine
import TrinketCore

extension BattleEngineContext {
    @discardableResult
    mutating func applyTestDamage(
        _ amount: Int,
        to target: Combatant,
        keyword: Keyword? = nil,
        sourceActorID: String? = nil,
        applyStatBonus: Bool = true,
        applyItemBonus: Bool = true,
        applyDodge: Bool = true,
        isRetaliation: Bool = false
    ) -> (healthLost: Int, events: [ActionEvent]) {
        let outcome = resolveDamage(
            DamageRequest(
                amount: amount,
                target: target,
                keyword: keyword,
                sourceActorID: sourceActorID,
                options: DamageOptions(
                    applyStatBonus: applyStatBonus,
                    applyItemBonus: applyItemBonus,
                    applyDodge: applyDodge,
                    isRetaliation: isRetaliation
                )
            )
        )
        return (outcome.healthLost, outcome.events)
    }

    mutating func applyTestHeal(_ amount: Int, to target: Combatant, sourceActorID: String? = nil) {
        _ = resolveHeal(HealRequest(amount: amount, target: target, sourceActorID: sourceActorID))
    }

    @discardableResult
    mutating func applyTestDoTDamage(
        _ amount: Int,
        keyword: Keyword,
        to target: Combatant,
        sourceActorID: String?
    ) -> (healthLost: Int, events: [ActionEvent]) {
        let outcome = resolveDoTTick(
            basePotency: amount,
            keyword: keyword,
            target: target,
            sourceActorID: sourceActorID
        )
        return (outcome.healthLost, outcome.events)
    }
}
