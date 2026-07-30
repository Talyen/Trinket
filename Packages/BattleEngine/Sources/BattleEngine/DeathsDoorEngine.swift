import Foundation
import TrinketContent
import TrinketCore

/// Intrinsic battle rule: hero and companion each get one Death's Door proc per battle.
package enum DeathsDoorEngine {
    public static func applies(to combatant: Combatant) -> Bool {
        combatant.role == .hero || combatant.role == .companion
    }

    public static func isActive(for combatant: Combatant, in context: BattleState) -> Bool {
        context.roster.isDeathsDoorActive(for: combatant)
    }

    /// Lethal protection while Death's Door is active, or for the remainder of the tick it expired.
    public static func hasLethalProtection(
        for combatant: Combatant,
        in context: BattleState
    ) -> Bool {
        if isActive(for: combatant, in: context) {
            return true
        }
        guard context.roster.hasConsumedDeathsDoor(for: combatant),
              let runtime = context.roster.runtime(for: combatant),
              let expiredAt = runtime.deathsDoorExpiredAtTurn,
              expiredAt == context.turnCount
        else { return false }
        return true
    }

    public static func resolveAfterDamage(
        to combatant: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard applies(to: combatant) else { return [] }

        let health = context.roster.health(for: combatant)
        if health == 0 {
            if let reviveEvents = tryTraitDeathRevive(on: combatant, in: &context) {
                return reviveEvents
            }
            if !context.roster.hasConsumedDeathsDoor(for: combatant) {
                return trigger(on: combatant, in: &context)
            }
            if hasLethalProtection(for: combatant, in: context) {
                clampToMinimumHP(on: combatant, in: &context)
            }
        } else if hasLethalProtection(for: combatant, in: context), health < 1 {
            clampToMinimumHP(on: combatant, in: &context)
        }
        return []
    }

    /// Policy C: unused trait death-revive fires before Death's Door and does not consume DD.
    private static func tryTraitDeathRevive(
        on combatant: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent]? {
        guard let runtime = context.roster.runtime(for: combatant),
              !runtime.hasTriggeredDeathRevive
        else { return nil }

        let triggers = context.modifiers(for: combatant.id).triggers
        let reviveHealth = triggers.onceDeathReviveHealth
        let reviveBlock = triggers.onceDeathReviveBlock
        guard reviveHealth > 0 || reviveBlock > 0 else { return nil }

        let healthToRestore = max(1, reviveHealth)
        var revivedHealth = 0
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.hasTriggeredDeathRevive = true
            runtime.currentHealth = min(healthToRestore, runtime.maxHealth)
            revivedHealth = runtime.currentHealth
        }

        let abilityName = context.modifiers(for: combatant.id).traitDisplayName ?? "Trait"
        var events = [
            context.nextEvent(
                kind: .effect,
                effectKind: .instantHeal,
                actorName: combatant.name,
                abilityName: abilityName,
                target: combatant,
                amount: revivedHealth,
                keyword: .health
            ),
        ]
        if reviveBlock > 0 {
            events.append(contentsOf: CombatReactionEngine.applyBlock(
                amount: reviveBlock,
                to: combatant,
                source: combatant,
                abilityName: abilityName,
                in: &context
            ))
        }
        return events
    }

    private static func trigger(
        on combatant: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.hasConsumedDeathsDoor = true
            runtime.currentHealth = 1
        }

        let duration = BattleTiming.deathsDoorDurationTurns
        context.prependEffect(
            .deathsDoor,
            to: combatant,
            remainingTurns: duration
        )

        let event = context.nextEvent(
            kind: .effect,
            effectKind: .deathsDoorTriggered,
            actorName: combatant.name,
            abilityName: Keyword.deathsDoor.rawValue,
            target: combatant,
            amount: 0,
            keyword: .deathsDoor
        )
        var events = [event]
        let blockAmount = context.modifiers(for: combatant.id).triggers.blockOnDeathsDoor
        if blockAmount > 0 {
            events.append(contentsOf: CombatReactionEngine.applyBlock(
                amount: blockAmount,
                to: combatant,
                source: combatant,
                abilityName: "Deathgrip",
                in: &context
            ))
        }
        return events
    }

    private static func clampToMinimumHP(
        on combatant: Combatant,
        in context: inout BattleState
    ) {
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.currentHealth = max(1, runtime.currentHealth)
        }
    }
}
