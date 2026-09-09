import TrinketContent
import TrinketCore
@testable import BattleEngine

extension BattleState {
    @discardableResult
    mutating func applyTestDamage(
        _ amount: Int,
        to target: Combatant,
        keyword: Keyword? = nil,
        sourceActorID: String? = nil,
        applyStatBonus: Bool = true,
        applyItemBonus: Bool = true,
        applyDodge: Bool = true,
        isRetaliation: Bool = false,
        abilityCriticalChanceBonus: Double = 0,
        guaranteedCriticalIfEnemyBuffed: Bool = false,
        abilityHasLeech: Bool = false,
    ) -> (healthLost: Int, events: [ActionEvent]) {
        let outcome = resolveDamage(
            DamageRequest(
                amount: amount,
                target: target,
                keyword: keyword,
                sourceActorID: sourceActorID,
                options: isRetaliation ? DamageOperation.reaction(
                    cause: .talent,
                    scaling: applyStatBonus ? .statsAndItems : (applyItemBonus ? .items : .flat),
                    accuracy: applyDodge ? .normal : .unavoidable,
                ) : (!isRetaliation ? DamageOperation.attack(
                    tier: .skill,
                    scaling: applyStatBonus ? .statsAndItems : (applyItemBonus ? .items : .flat),
                    accuracy: applyDodge ? .normal : .unavoidable,
                    abilityCriticalChanceBonus: abilityCriticalChanceBonus,
                    guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed,
                    abilityHasLeech: abilityHasLeech,
                ) : DamageOperation.effect(
                    scaling: applyStatBonus ? .statsAndItems : (applyItemBonus ? .items : .flat),
                    accuracy: applyDodge ? .normal : .unavoidable,
                    abilityCriticalChanceBonus: abilityCriticalChanceBonus,
                    guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed,
                    abilityHasLeech: abilityHasLeech,
                )),
            ),
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
        sourceActorID: String?,
    ) -> (healthLost: Int, events: [ActionEvent]) {
        let outcome = resolveDoTTick(
            basePotency: amount,
            keyword: keyword,
            target: target,
            sourceActorID: sourceActorID,
        )
        return (outcome.healthLost, outcome.events)
    }
}
