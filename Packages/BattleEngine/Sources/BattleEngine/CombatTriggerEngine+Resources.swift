import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterEnemyDefeated(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []

        if context.roster.hero.isAlive {
            let hero = context.roster.hero.combatant
            let amount = context.heroModifiers.triggers.defeatEnemyGoldFlat
            if amount > 0 {
                events.append(contentsOf: context.grantGoldEvent(
                    amount,
                    to: hero,
                    abilityName: triggerAbilityName("defeatEnemyGoldFlat", for: hero, fallback: "Bounty", in: context),
                ))
            }
        }

        if context.roster.companion.isAlive {
            let companion = context.roster.companion.combatant
            let amount = context.companionModifiers.triggers.defeatEnemyGoldFlat
            if amount > 0 {
                events.append(contentsOf: context.grantGoldEvent(
                    amount,
                    to: companion,
                    abilityName: triggerAbilityName("defeatEnemyGoldFlat", for: companion, fallback: "Bounty", in: context),
                ))
            }
        }

        for owner in [BattleParticipant.hero, .companion] {
            events.append(contentsOf: afterEnemyDefeatedReactions(for: owner, in: &context))
        }
        return events
    }

    private static func afterEnemyDefeatedReactions(
        for owner: BattleParticipant,
        in context: inout BattleState,
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
                in: &context,
            ))
        }
        return events
    }

    private static func critOnDefeatRewards(
        triggers: CombatTraitTriggers,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.critOnDefeatGold > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.critOnDefeatGold,
                to: actor,
                abilityName: triggerAbilityName("critOnDefeatGold", for: actor, fallback: "Bounty Hunter", in: context),
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
                    abilityName: triggerAbilityName("victoryGoldFlat", for: actor, fallback: "Smuggler's Map", in: context),
                ))
            }
            if triggers.victoryGoldCoin {
                if BattleChance.succeeds(probability: 0.5, using: &context.rng) {
                    events.append(contentsOf: context.grantGoldEvent(
                        7,
                        to: actor,
                        abilityName: triggerAbilityName("victoryGoldCoin", for: actor, fallback: "Wishing Well Coin", in: context),
                    ))
                } else {
                    let loss = min(3, max(0, context.gold))
                    guard loss > 0 else { continue }
                    context.gold -= loss
                    events.append(context.nextEvent(
                        kind: .effect,
                        effectKind: .resourceGain,
                        actorName: actor.name,
                        abilityName: triggerAbilityName("victoryGoldCoin", for: actor, fallback: "Wishing Well Coin", in: context),
                        target: actor,
                        amount: -loss,
                        keyword: .gold,
                    ))
                }
            }
        }
        return events
    }

    static func healSelfAfterGoldGain(
        source: Combatant,
        in context: inout BattleState,
    ) -> CombatOutcome {
        resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.gainGoldBonusHealSelf,
            source: source,
            target: source,
            in: &context,
        )
    }
}
