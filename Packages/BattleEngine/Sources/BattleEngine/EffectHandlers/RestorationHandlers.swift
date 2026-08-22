import Foundation
import TrinketContent
import TrinketCore

struct InstantHealHandler: BattleEffectHandler {
    let kind: EffectKind = .instantHeal

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .instantHeal(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: target,
                sourceActorID: source.id,
                logAs: .instantHeal(
                    actorName: source.name,
                    abilityName: ability.name,
                    keyword: keyword
                )
            ),
            in: &context
        )
        guard outcome.healthRestored > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
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
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .resourceGain(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        switch keyword {
        case .mana:
            let restored = context.restoreMana(
                context.paced(amount, sourceActorID: source.id),
                to: target
            )
            let event = context.nextEvent(
                kind: .effect,
                effectKind: .resourceGain,
                actorName: source.name,
                abilityName: ability.name,
                target: target,
                amount: restored,
                keyword: keyword
            )
            var events = [event]
            if restored > 0 {
                events.append(contentsOf: CombatTriggerEngine.afterGainMana(by: target, in: &context))
            }
            return EffectApplyOutcome(events: events, didApply: true)
        case .gold:
            return EffectApplyOutcome(
                events: context.grantGoldEvent(amount, to: source, abilityName: ability.name),
                didApply: true
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
        action _: ActionApplyContext,
        in context: inout BattleState
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
            keyword: .physical
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
        action _: ActionApplyContext,
        in context: inout BattleState
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
                keyword: .physical
            ),
        ]
        events.append(contentsOf: autoPlayDrawnCards(drawnCards, in: &context))
        return EffectApplyOutcome(events: events, didApply: true)
    }

    private func collectDrawnCards(targetCount: Int, in context: inout BattleState) -> [BattleCard] {
        var drawnCards: [BattleCard] = []

        if canDrawAndPlay(.hero, in: context),
           let card = BattleCardCombatEngine.drawOneCard(for: .hero, context: &context) {
            drawnCards.append(card)
        }

        if drawnCards.count < targetCount, canDrawAndPlay(.companion, in: context),
           let card = BattleCardCombatEngine.drawOneCard(for: .companion, context: &context) {
            drawnCards.append(card)
        }

        while drawnCards.count < targetCount {
            let drewAny = fillFallbackDraw(targetCount: targetCount, drawnCards: &drawnCards, in: &context)
            if !drewAny {
                break
            }
        }

        return drawnCards
    }

    private func fillFallbackDraw(
        targetCount: Int,
        drawnCards: inout [BattleCard],
        in context: inout BattleState
    ) -> Bool {
        var drewAny = false
        for owner in [BattleParticipant.hero, .companion] {
            guard drawnCards.count < targetCount else { break }
            guard canDrawAndPlay(owner, in: context) else { continue }
            if let card = BattleCardCombatEngine.drawOneCard(for: owner, context: &context) {
                drawnCards.append(card)
                drewAny = true
            }
        }
        return drewAny
    }

    private func canDrawAndPlay(_ owner: BattleParticipant, in context: BattleState) -> Bool {
        guard context.roster[owner].isAlive else { return false }
        guard !context.ownersSkippingThisPlayerTurn.contains(owner) else { return false }
        let deckCount = owner == .hero ? context.heroDeck.count : context.companionDeck.count
        return deckCount > 0
    }

    private func autoPlayDrawnCards(
        _ drawnCards: [BattleCard],
        in context: inout BattleState
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
                // Card play failed due to state mutation or turn constraints
            }
        }
        return events
    }
}
