import TrinketContent
import TrinketCore

package extension BattleState {
    @discardableResult
    mutating func emitBlock(
        _ amount: Int,
        to target: Combatant,
        from source: Combatant,
        abilityKey: String,
        fallback: String,
    ) -> [ActionEvent] {
        guard amount > 0 else { return [] }
        return applyBlock(
            amount,
            to: target,
            source: source,
            abilityName: CombatTriggerEngine.triggerAbilityName(abilityKey, for: source, fallback: fallback, in: self),
        )
    }

    @discardableResult
    mutating func emitHeal(
        _ amount: Int,
        to target: Combatant,
        from source: Combatant,
        abilityKey: String,
        fallback: String,
    ) -> [ActionEvent] {
        guard amount > 0 else { return [] }
        return healEmitting(
            amount: amount,
            target: target,
            source: source,
            abilityName: CombatTriggerEngine.triggerAbilityName(abilityKey, for: source, fallback: fallback, in: self),
        )
    }

    @discardableResult
    mutating func emitGold(
        _ amount: Int,
        to target: Combatant,
        abilityKey: String,
        fallback: String,
    ) -> [ActionEvent] {
        guard amount > 0 else { return [] }
        return grantGoldEvent(
            amount,
            to: target,
            abilityName: CombatTriggerEngine.triggerAbilityName(abilityKey, for: target, fallback: fallback, in: self),
        )
    }

    @discardableResult
    mutating func emitMana(
        _ amount: Int,
        to target: Combatant,
        abilityKey: String,
        fallback: String,
    ) -> [ActionEvent] {
        guard amount > 0 else { return [] }
        return restoreManaEmitting(
            amount,
            to: target,
            abilityName: CombatTriggerEngine.triggerAbilityName(abilityKey, for: target, fallback: fallback, in: self),
        )
    }

    @discardableResult
    mutating func emitDraw(
        _ count: Int,
        for owner: BattleParticipant,
        from source: Combatant,
        abilityKey: String,
        fallback: String,
    ) -> [ActionEvent] {
        guard count > 0 else { return [] }
        let member = roster[owner]
        guard member.isAlive else { return [] }
        return CombatTriggerEngine.drawCards(
            count,
            for: owner,
            actor: source,
            abilityName: CombatTriggerEngine.triggerAbilityName(abilityKey, for: source, fallback: fallback, in: self),
            in: &self,
        )
    }

    @discardableResult
    mutating func emitDoT(
        keyword: Keyword,
        potency: Int,
        to target: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool = true,
    ) -> [ActionEvent] {
        CombatTriggerEngine.applyDoT(
            keyword: keyword,
            potency: potency,
            to: target,
            sourceActorID: sourceActorID,
            dealImmediateDamage: dealImmediateDamage,
            in: &self,
        )
    }
}
