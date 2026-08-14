import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func atPlayerTurnStart(in context: inout BattleState) -> [ActionEvent] {
        context.cardsPlayedThisTurn = [:]
        context.spendManaDrawOwnersThisTurn = []
        context.healthLossDrawOwnersThisTurn = []

        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            let runtime = context.roster[owner]
            guard runtime.isAlive else { continue }
            let actor = runtime.combatant
            let triggers = context.modifiers(for: actor.id).triggers

            if triggers.goldPerTurn > 0 {
                events.append(contentsOf: context.grantGoldEvent(
                    triggers.goldPerTurn,
                    to: actor,
                    abilityName: "Merchant's Favor"
                ))
            }
            if triggers.healthPerTurn > 0 {
                events.append(contentsOf: HealingEngine.resolveHeal(
                    HealRequest(
                        amount: triggers.healthPerTurn,
                        target: actor,
                        sourceActorID: actor.id,
                        logAs: .instantHeal(
                            actorName: actor.name,
                            abilityName: "Grove's Favor",
                            keyword: .health,
                            displayAmount: triggers.healthPerTurn
                        )
                    ),
                    in: &context
                ).events)
            }
            if context.turnCount.isMultiple(of: 2), triggers.drawEveryOtherTurn > 0 {
                events.append(contentsOf: drawCards(
                    triggers.drawEveryOtherTurn,
                    for: owner,
                    actor: actor,
                    abilityName: "Tattered Pages",
                    in: &context
                ))
            }
            if triggers.companionCardsPerTurn > 0 {
                events.append(contentsOf: drawCards(
                    triggers.companionCardsPerTurn,
                    for: .companion,
                    actor: actor,
                    abilityName: "Companion's Collar",
                    in: &context
                ))
            }
        }
        return events
    }

    static func afterCardPlayed(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        guard triggers.cardsPlayedManaThreshold > 0, triggers.cardsPlayedManaFlat > 0 else { return [] }
        let count = context.cardsPlayedThisTurn[owner, default: 0] + 1
        context.cardsPlayedThisTurn[owner] = count
        guard count == triggers.cardsPlayedManaThreshold else { return [] }

        let restored = context.restoreMana(triggers.cardsPlayedManaFlat, to: actor)
        guard restored > 0 else { return [] }
        var events = [context.nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: actor.name,
            abilityName: "Resonant Chimes",
            target: actor,
            amount: restored,
            keyword: .mana
        )]
        events.append(contentsOf: afterGainMana(by: actor, in: &context))
        return events
    }

    static func drawAfterSpendMana(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return [] }
        let count = context.modifiers(for: actor.id).triggers.drawOnSpendMana
        guard count > 0, context.spendManaDrawOwnersThisTurn.insert(owner).inserted else { return [] }
        return drawCards(count, for: owner, actor: actor, abilityName: "Runic Quill", in: &context)
    }

    static func drawAfterHealthLoss(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return [] }
        let count = context.modifiers(for: actor.id).triggers.drawOnHealthLoss
        guard count > 0, context.healthLossDrawOwnersThisTurn.insert(owner).inserted else { return [] }
        return drawCards(count, for: owner, actor: actor, abilityName: "Bone Charm", in: &context)
    }

    static func afterHealthRestored(
        _ amount: Int,
        to actor: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let percent = context.modifiers(for: actor.id).triggers.healthRestoredPoisonPercent
        guard amount > 0, percent > 0, context.roster.enemy.isAlive, !context.isResolvingTrinketReaction else {
            return []
        }
        let damage = CombatRounding.scaled(amount, multiplier: percent)
        guard damage > 0 else { return [] }
        context.isResolvingTrinketReaction = true
        defer { context.isResolvingTrinketReaction = false }
        return context.resolveDamage(
            DamageRequest(
                amount: damage,
                target: context.roster.enemy.combatant,
                keyword: .poison,
                sourceActorID: actor.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isRetaliation: true
                )
            )
        ).events
    }

    static func afterBlockGained(
        _ amount: Int,
        by actor: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let percent = context.modifiers(for: actor.id).triggers.blockGainThornsPercent
        let gained = CombatRounding.scaled(amount, multiplier: percent)
        guard amount > 0, gained > 0 else { return [] }

        var effects = context.roster.activeEffects(for: actor)
        let existing = effects.reduce(0) { total, active in
            if case let .thorns(stacks) = active.effect {
                return total + stacks
            }
            return total
        }
        effects.removeAll {
            if case .thorns = $0.effect {
                return true
            }
            return false
        }
        let total = existing + gained
        effects.append(ActiveEffect(
            id: context.consumeNextEffectID(),
            effect: .thorns(total),
            remainingTurns: 0,
            sourceActorID: actor.id
        ))
        context.roster.setActiveEffects(effects, for: actor)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .thornsApplied,
            actorName: actor.name,
            abilityName: "Ironwood Buckler",
            target: actor,
            amount: total,
            keyword: .physical
        )]
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

    private static func drawCards(
        _ count: Int,
        for owner: BattleParticipant,
        actor: Combatant,
        abilityName: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let drawn = BattleCardCombatEngine.drawCards(count: count, for: owner, context: &context)
        guard drawn > 0 else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: actor.name,
            abilityName: abilityName,
            target: actor,
            amount: drawn,
            keyword: .physical
        )]
    }
}
