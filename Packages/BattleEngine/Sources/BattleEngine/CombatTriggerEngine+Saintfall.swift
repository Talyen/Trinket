import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func saintfallAfterBlockBroken(
        on target: Combatant,
        attackerID: String?,
        power: Int,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard power > 0,
              let attackerID,
              let attacker = context.roster.combatant(for: attackerID),
              attacker.isAlive,
              let runtime = context.roster.runtime(for: target),
              !runtime.hasTriggeredSaintfallThisTurn
        else { return [] }
        context.roster.mutateRuntime(for: target) { $0.hasTriggeredSaintfallThisTurn = true }

        var events: [ActionEvent] = []
        for keyword in [Keyword.holy, .stun] where context.roster.health(for: attacker.combatant) > 0 {
            let outcome = context.resolveDamage(
                DamageRequest(
                    amount: power,
                    target: attacker.combatant,
                    keyword: keyword,
                    sourceActorID: target.id,
                    options: DamageOptions(
                        applyStatBonus: false,
                        applyItemBonus: false,
                        applyDodge: false,
                        isRetaliation: true,
                        applyControlMeter: true
                    )
                )
            )
            events.append(contentsOf: outcome.events)
            if keyword == .holy, outcome.healthLost > 0 {
                events.append(contentsOf: afterHolyDamageDealt(
                    to: attacker.combatant,
                    source: target,
                    isAttackHit: false,
                    in: &context
                ))
            }
        }
        events.append(contentsOf: context.healEmitting(
            amount: power,
            target: target,
            source: target,
            abilityName: "Saintfall"
        ))
        return events
    }
}
