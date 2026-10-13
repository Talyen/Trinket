import TrinketContent
import TrinketCore
@testable import BattleEngine

extension BattleState {
    /// Resolves one engine action without moving a physical hand card.
    @discardableResult
    mutating func performTestAction(
        _ ability: Ability,
        from source: BattleParticipant = .hero,
        to target: BattleParticipant = .enemy,
    ) -> [ActionEvent] {
        BattleTurnEngine.performAction(
            ability: ability, actor: roster[source].combatant, abilityTarget: roster[target].combatant, context: &self,
        )
    }

    @discardableResult
    mutating func resolveTestDamage(
        _ amount: Int,
        from source: BattleParticipant = .hero,
        to target: BattleParticipant = .enemy,
        keyword: Keyword = .physical,
        options: DamageOperation = .attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
    ) -> CombatOutcome {
        resolveDamage(DamageRequest(
            amount: amount, target: roster[target].combatant, keyword: keyword,
            sourceActorID: roster[source].id, options: options,
        ))
    }

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
                ) : DamageOperation.attack(
                    tier: .skill,
                    scaling: applyStatBonus ? .statsAndItems : (applyItemBonus ? .items : .flat),
                    accuracy: applyDodge ? .normal : .unavoidable,
                    abilityCriticalChanceBonus: abilityCriticalChanceBonus,
                    guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed,
                    abilityHasLeech: abilityHasLeech,
                ),
            ),
        )
        return (outcome.healthLost, outcome.events)
    }
}
