import Foundation
import os
import TrinketContent
import TrinketCore

private let cardDrawLogger = Logger(
    subsystem: "com.trinket.battle",
    category: "CardDrawHandlers",
)

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
            origin: .direct,
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
        guard context.resolution.depth(.draw) < BattleState.maxDrawAndPlayDepth else {
            return EffectApplyOutcome(events: [], didApply: false)
        }

        guard let firstOwner = context.roster.participant(for: target), firstOwner.isPartyMember else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let drawOwner: BattleParticipant = ability.id == Ability.packTactics.id
            ? (firstOwner == .hero ? .companion : .hero)
            : firstOwner
        let drawnCards = collectDrawnCards(
            targetCount: count, firstOwner: drawOwner,
            allowFallback: ability.id == Ability.packTactics.id || count > 1,
            in: &context,
        )
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
        context.recordCardPlay(.cardsDrawn(drawnCards))
        events.append(contentsOf: context.withAutomaticPlay { context in
            autoPlayDrawnCards(drawnCards, in: &context)
        })
        return EffectApplyOutcome(events: events, didApply: true)
    }

    private func collectDrawnCards(
        targetCount: Int,
        firstOwner: BattleParticipant,
        allowFallback: Bool,
        in context: inout BattleState,
    ) -> [BattleCard] {
        var drawnCards: [BattleCard] = []
        let otherOwner: BattleParticipant = firstOwner == .hero ? .companion : .hero

        for index in 0 ..< targetCount {
            let owner = index.isMultiple(of: 2) ? firstOwner : otherOwner
            let fallback: BattleParticipant = owner == .hero ? .companion : .hero
            let candidates = allowFallback ? [owner, fallback] : [owner]
            for candidate in candidates where canDrawAndPlay(candidate, in: context) {
                guard let card = BattleCardCombatEngine.drawOne(for: candidate, context: &context) else { continue }
                drawnCards.append(card)
                break
            }
        }

        return drawnCards
    }

    private func canDrawAndPlay(_ owner: BattleParticipant, in context: BattleState) -> Bool {
        guard context.roster[owner].isAlive else { return false }
        guard !context.ownersSkippingThisPlayerTurn.contains(owner) else { return false }
        let ability = owner == .hero ? context.heroDeck.abilities.first : context.companionDeck.abilities.first
        guard let ability else { return false }
        return BattleAbilityRules.canPayHealthCost(ability, actor: context.roster[owner].combatant, in: context)
    }

    private func autoPlayDrawnCards(
        _ drawnCards: [BattleCard],
        in context: inout BattleState,
    ) -> [ActionEvent] {
        context.resolution.enter(.draw)
        defer { context.resolution.leave(.draw) }
        guard context.resolution.depth(.draw) <= BattleState.maxDrawAndPlayDepth else { return [] }

        var events: [ActionEvent] = []
        for card in drawnCards {
            guard BattleCardCombatEngine.isCardPlayable(card, in: context) else { continue }
            do {
                let played = try BattleCardCombatEngine.playDrawnCard(card, context: &context)
                events.append(contentsOf: played)
            } catch {
                cardDrawLogger.info(
                    "Draw-and-play card \(card.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)",
                )
            }
        }
        return events
    }
}
