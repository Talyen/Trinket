import TrinketContent
import TrinketCore

/// Support steps called by the ordered turn-start driver. The driver owns the
/// survival checks between steps; each step retains its original reaction order.
extension CombatTriggerEngine {
    static func startOfTurnRegen(
        runtime: CombatantRuntime,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard !context.isBattleOver, context.health(of: actor) > 0 else { return [] }
        var events: [ActionEvent] = []
        if triggers.goldPerTurn > 0 {
            events.append(contentsOf: emitGold(
                "goldPerTurn", "Merchant's Favor", amount: triggers.goldPerTurn, to: actor, in: &context,
            ))
        }
        guard !context.isBattleOver, context.health(of: actor) > 0 else { return events }
        if triggers.healthPerTurn > 0, context.isPlayerTurn(every: 2, startingAt: 1) {
            let target = BattleActionContext(actor: actor, in: context).target(.lowestHealthAlly, in: context)
            events.append(contentsOf: emitHeal(
                "healthPerTurn", "Grove's Favor",
                amount: triggers.healthPerTurn, to: target, source: actor, in: &context,
            ))
        }
        guard !context.isBattleOver, context.health(of: actor) > 0 else { return events }
        if let blessing = runtime.talents.timed.lingeringBlessing,
           let source = context.roster.combatant(for: blessing.sourceActorID) {
            let amount = blessing.amount
            var request = HealRequest(
                amount: amount,
                target: actor,
                sourceActorID: source.id,
                origin: .periodic, logAs: .instantHeal(
                    actorName: source.name,
                    abilityName: "Lingering Blessing",
                    keyword: .health,
                ),
            )
            request.amountBasis = .resolved
            request.suppressTalentReactions = true
            events.append(contentsOf: HealingEngine.resolveHeal(request, in: &context).events)
            context.roster.mutateRuntime(for: actor) {
                guard var current = $0.talents.timed.lingeringBlessing else { return }
                current.turnsRemaining -= 1
                $0.talents.timed.lingeringBlessing = current.turnsRemaining > 0 ? current : nil
            }
        }
        return events
    }

    static func startOfTurnRecovery(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.goldEveryNTurnsInterval > 0,
           context.turnCount > 0,
           context.isPlayerTurn(every: triggers.goldEveryNTurnsInterval) {
            events.append(contentsOf: emitGold(
                "goldEveryNTurnsAmount", "Dig for Treasure",
                amount: triggers.goldEveryNTurnsAmount, to: actor, in: &context,
            ))
        }
        if triggers.healthRegenFirstTurnsDuration > 0,
           context.turnCount < triggers.healthRegenFirstTurnsDuration {
            events.append(contentsOf: emitHeal(
                "healthRegenFirstTurnsAmount", "Sprite Touch",
                amount: triggers.healthRegenFirstTurnsAmount, to: actor, source: actor, in: &context,
            ))
        }
        if triggers.healthRegenAboveHalfHealth > 0,
           context.roster.maxHealth(for: actor) > 0,
           context.roster.health(for: actor) * 2 > context.roster.maxHealth(for: actor) {
            events.append(contentsOf: emitHeal(
                "healthRegenAboveHalfHealth", "Safe Perch",
                amount: triggers.healthRegenAboveHalfHealth, to: actor, source: actor, in: &context,
            ))
        }
        return events
    }

    static func startOfTurnMana(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.startTurnFullManaDrawCards > 0,
           let runtime = context.roster.runtime(for: actor),
           runtime.maxMana > 0,
           runtime.currentMana >= runtime.maxMana {
            events.append(contentsOf: drawCards(
                triggers.startTurnFullManaDrawCards,
                for: owner,
                actor: actor,
                abilityName: triggerAbilityName(
                    "startTurnFullManaDrawCards",
                    for: actor,
                    fallback: "Arcane Surge",
                    in: context,
                ),
                in: &context,
            ))
        }
        if triggers.bonusManaOnTurns.contains(context.playerTurnNumber) {
            events.append(contentsOf: emitMana(
                "bonusManaOnTurns", "Aetherial Surge", amount: 1, to: actor, in: &context,
            ))
        }
        return events
    }

    static func startOfTurnDrawCadence(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.extraCardDrawWhileEnemyBleeding, context.roster.enemy.isAlive,
           context.roster.hasAffliction(.bleed, on: context.enemy) {
            events.append(contentsOf: drawCards(
                1,
                for: owner,
                actor: actor,
                abilityName: triggerAbilityName(
                    "extraCardDrawWhileEnemyBleeding",
                    for: actor,
                    fallback: "Frenzied Tail",
                    in: context,
                ),
                in: &context,
            ))
        }
        if triggers.extraCardDrawBelowEnemyHealthPercent > 0, context.roster.enemy.isAlive,
           context.roster.maxHealth(for: context.roster.enemy.combatant) > 0,
           Double(context.roster.health(for: context.roster.enemy.combatant))
           / Double(context.roster.maxHealth(for: context.roster.enemy.combatant))
           < triggers.extraCardDrawBelowEnemyHealthPercent {
            events.append(contentsOf: drawCards(
                1,
                for: owner,
                actor: actor,
                abilityName: triggerAbilityName(
                    "extraCardDrawBelowEnemyHealthPercent",
                    for: actor,
                    fallback: "Feral Frenzy",
                    in: context,
                ),
                in: &context,
            ))
        }
        return events
    }
}
