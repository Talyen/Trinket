import Foundation
import os
import TrinketContent
import TrinketCore

private let cardDrawLogger = Logger(
    subsystem: "com.trinket.battle",
    category: "CardDrawHandlers",
)

extension EffectApplication {
    func applyDrawCards(in context: inout BattleState) -> EffectApplyOutcome {
        guard case let .drawCards(count) = effect, count > 0 else {
            return EffectApplyOutcome(didApply: false)
        }
        let drawTarget: Combatant
        if ability.id == Ability.packTactics.id,
           let sourceOwner = context.roster.participant(for: source), sourceOwner.isPartyMember {
            let allyOwner: BattleParticipant = sourceOwner == .hero ? .companion : .hero
            if BattleCardCombatEngine.canDrawFromDeck(for: allyOwner, in: context),
               !BattleCardCombatEngine.deck(for: allyOwner, in: context).abilities.isEmpty {
                drawTarget = context.roster[allyOwner].combatant
            } else {
                drawTarget = source
            }
        } else {
            drawTarget = target
        }
        guard let owner = context.roster.participant(for: drawTarget), owner.isPartyMember else {
            return EffectApplyOutcome(didApply: false)
        }
        let drawn = BattleCardCombatEngine.drawCards(count: count, for: owner, context: &context)
        guard drawn > 0 else {
            return EffectApplyOutcome(didApply: false)
        }
        emit(.cardsDrawn, amount: drawn, keyword: .physical, target: drawTarget, in: &context)
        return EffectApplyOutcome(didApply: true)
    }

    func applyDrawAndPlayCards(in context: inout BattleState) async -> EffectApplyOutcome {
        guard case let .drawAndPlayCards(count) = effect, count > 0 else {
            return EffectApplyOutcome(didApply: false)
        }
        guard context.resolution.depth(.draw) < BattleState.maxDrawAndPlayDepth else {
            return EffectApplyOutcome(didApply: false)
        }

        guard let firstOwner = context.roster.participant(for: target), firstOwner.isPartyMember else {
            return EffectApplyOutcome(didApply: false)
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
            return EffectApplyOutcome(didApply: false)
        }

        emit(.cardsDrawn, amount: drawnCards.count, keyword: .physical, origin: .automatic, in: &context)
        let played = await context.withAutomaticPlay { context in
            await autoPlayDrawnCards(drawnCards, in: &context)
        }

        return EffectApplyOutcome(didApply: true, criticalAttackActorIDs: played)
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
            let countBefore = drawnCards.count
            let owner = index.isMultiple(of: 2) ? firstOwner : otherOwner
            let fallback: BattleParticipant = owner == .hero ? .companion : .hero
            let candidates = allowFallback ? [owner, fallback] : [owner]
            for candidate in candidates where canDrawAndPlay(candidate, in: context) {
                guard let card = BattleCardCombatEngine.drawOne(for: candidate, context: &context) else { continue }
                drawnCards.append(card)
                break
            }
            // Collection does not resolve cards, so exhausted or blocked decks cannot recover here.
            guard drawnCards.count > countBefore else { break }
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
    ) async -> Set<String> {
        context.resolution.enter(.draw)
        defer { context.resolution.leave(.draw) }
        guard context.resolution.depth(.draw) <= BattleState.maxDrawAndPlayDepth else {
            return []
        }

        var criticalAttackActorIDs: Set<String> = []
        for card in drawnCards {
            guard BattleCardCombatEngine.playError(for: card, in: context, allowsTurnPreparation: true) == nil else { continue }
            do {
                let played = try await BattleCardCombatEngine.resolveDrawnCard(card, context: &context)

                criticalAttackActorIDs.formUnion(played)
            } catch {
                cardDrawLogger.info(
                    "Draw-and-play card \(card.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)",
                )
            }
        }
        return criticalAttackActorIDs
    }
}
