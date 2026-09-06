import Foundation
import os
import TrinketContent
import TrinketCore

private let restorationLogger = Logger(
    subsystem: "com.trinket.battle",
    category: "RestorationHandlers",
)

struct InstantHealHandler: BattleEffectHandler {
    let kind: EffectKind = .instantHeal

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .instantHeal(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        var request = HealRequest(
            amount: amount, target: target, sourceActorID: source.id,
            logAs: .instantHeal(actorName: source.name, abilityName: ability.name, keyword: keyword),
        )
        request.isDirectCardHeal = context.hasHeroCard(for: source.id)
        let outcome = HealingEngine.resolveHeal(request, in: &context)
        guard outcome.healthRestored > 0 else {
            return EffectApplyOutcome(events: outcome.events, didApply: false)
        }
        return EffectApplyOutcome(events: outcome.events, didApply: true)
    }
}

struct ResourceGainHandler: BattleEffectHandler {
    let kind: EffectKind = .resourceGain

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .resourceGain(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        switch keyword {
        case .mana:
            let bonus = amount > 0 ? CombatTriggerEngine.heroCardManaBonus(source: source, target: target, in: &context) : 0
            let restored = context.restoreMana(
                context.paced(amount, sourceActorID: source.id) + bonus,
                to: target,
            )
            CombatTriggerEngine.afterHeroCardMana(source: source, restored: restored, in: &context)
            let event = context.nextEvent(
                kind: .effect,
                effectKind: .resourceGain,
                actorName: source.name,
                abilityName: ability.name,
                target: target,
                amount: restored,
                keyword: keyword,
            )
            var events = [event]
            if restored > 0 {
                events.append(contentsOf: CombatTriggerEngine.afterGainMana(by: target, in: &context))
            }
            return EffectApplyOutcome(events: events, didApply: true)
        case .gold:
            let bonus = CombatTriggerEngine.heroCardGoldBonus(source: source, amount: amount, in: &context)
            return EffectApplyOutcome(
                events: context.grantGoldEvent(amount + bonus, to: source, abilityName: ability.name),
                didApply: true,
            )
        default:
            return EffectApplyOutcome(events: [], didApply: false)
        }
    }
}

struct DrawCardsHandler: BattleEffectHandler {
    let kind: EffectKind = .drawCards

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .drawCards(count) = effect, count > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let drawTarget = target
        guard let owner = context.roster.participant(for: drawTarget), owner.isPartyMember else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let drawn = BattleCardCombatEngine.drawCards(count: count, for: owner, context: &context)
        guard drawn > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: source.name,
            abilityName: ability.name,
            target: drawTarget,
            amount: drawn,
            keyword: .physical,
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct DrawAndPlayCardsHandler: BattleEffectHandler {
    let kind: EffectKind = .drawAndPlayCards

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .drawAndPlayCards(count) = effect, count > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        guard context.drawAndPlayDepth < BattleState.maxDrawAndPlayDepth else {
            return EffectApplyOutcome(events: [], didApply: false)
        }

        let drawnCards = collectDrawnCards(targetCount: count, in: &context)
        guard !drawnCards.isEmpty else {
            return EffectApplyOutcome(events: [], didApply: false)
        }

        var events = [
            context.nextEvent(
                kind: .effect,
                effectKind: .cardsDrawn,
                actorName: source.name,
                abilityName: ability.name,
                target: target,
                amount: drawnCards.count,
                keyword: .physical,
            ),
        ]
        events.append(contentsOf: autoPlayDrawnCards(drawnCards, in: &context))
        return EffectApplyOutcome(events: events, didApply: true)
    }

    private func collectDrawnCards(targetCount: Int, in context: inout BattleState) -> [BattleCard] {
        var drawnCards: [BattleCard] = []

        for index in 0 ..< targetCount {
            let owner: BattleParticipant = index.isMultiple(of: 2) ? .hero : .companion
            guard canDrawAndPlay(owner, in: context),
                  let card = BattleCardCombatEngine.drawOne(for: owner, context: &context)
            else { continue }
            drawnCards.append(card)
        }

        return drawnCards
    }

    private func canDrawAndPlay(_ owner: BattleParticipant, in context: BattleState) -> Bool {
        guard context.roster[owner].isAlive else { return false }
        guard !context.ownersSkippingThisPlayerTurn.contains(owner) else { return false }
        let deckCount = owner == .hero ? context.heroDeck.count : context.companionDeck.count
        return deckCount > 0
    }

    private func autoPlayDrawnCards(
        _ drawnCards: [BattleCard],
        in context: inout BattleState,
    ) -> [ActionEvent] {
        context.drawAndPlayDepth += 1
        defer { context.drawAndPlayDepth -= 1 }
        guard context.drawAndPlayDepth <= BattleState.maxDrawAndPlayDepth else { return [] }

        var events: [ActionEvent] = []
        for card in drawnCards {
            guard BattleCardCombatEngine.isCardPlayable(card, in: context) else { continue }
            do {
                let played = try BattleCardCombatEngine.playDrawnCard(card, context: &context)
                events.append(contentsOf: played)
            } catch {
                restorationLogger.info(
                    "Draw-and-play card \(card.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)",
                )
            }
        }
        return events
    }
}
