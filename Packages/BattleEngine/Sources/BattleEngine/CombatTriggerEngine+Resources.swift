import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterEnemyDefeated(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []

        if context.roster.hero.isAlive {
            let hero = context.roster.hero.combatant
            let amount = context.heroModifiers.triggers.defeatEnemyGoldFlat
            if amount > 0 {
                events.append(contentsOf: context.grantGoldEvent(amount, to: hero, abilityName: affixName(.bounty)))
            }
        }

        if context.roster.companion.isAlive {
            let companion = context.roster.companion.combatant
            let amount = context.companionModifiers.triggers.defeatEnemyGoldFlat
            if amount > 0 {
                events.append(contentsOf: context.grantGoldEvent(amount, to: companion, abilityName: affixName(.bounty)))
            }
        }

        // Combatant Talent System defeat reactions.
        for owner in [BattleParticipant.hero, .companion] {
            events.append(contentsOf: afterEnemyDefeatedReactions(for: owner, in: &context))
        }
        return events
    }

    private static func afterEnemyDefeatedReactions(
        for owner: BattleParticipant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let runtime = context.roster[owner]
        guard runtime.isAlive else { return [] }
        let actor = runtime.combatant
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []
        if context.lastEnemyDefeatWasCritical {
            events.append(contentsOf: critOnDefeatRewards(
                triggers: triggers,
                actor: actor,
                in: &context
            ))
        }
        return events
    }

    private static func critOnDefeatRewards(
        triggers: CombatTraitTriggers,
        actor: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.critOnDefeatGold > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.critOnDefeatGold,
                to: actor,
                abilityName: "Bounty Hunter"
            ))
        }
        return events
    }

    static func afterVictory(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for actor in [context.roster.hero.combatant, context.roster.companion.combatant] {
            let triggers = context.modifiers(for: actor.id).triggers
            if triggers.victoryGoldFlat > 0 {
                events.append(contentsOf: context.grantGoldEvent(
                    triggers.victoryGoldFlat,
                    to: actor,
                    abilityName: "Smuggler's Map"
                ))
            }
            if triggers.victoryGoldCoin {
                if Bool.random(using: &context.rng) {
                    events.append(contentsOf: context.grantGoldEvent(7, to: actor, abilityName: "Wishing Well Coin"))
                } else {
                    let loss = min(3, max(0, context.gold))
                    guard loss > 0 else { continue }
                    context.gold -= loss
                    events.append(context.nextEvent(
                        kind: .effect,
                        effectKind: .resourceGain,
                        actorName: actor.name,
                        abilityName: "Wishing Well Coin",
                        target: actor,
                        amount: -loss,
                        keyword: .gold
                    ))
                }
            }
        }
        return events
    }

    static func healSelfAfterGoldGain(
        source: Combatant,
        in context: inout BattleState
    ) -> CombatOutcome {
        resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.gainGoldBonusHealSelf,
            source: source,
            target: source,
            in: &context
        )
    }
}
