import TrinketContent
import TrinketCore

extension EffectApplication {
    func applyDrawCards(in context: inout BattleState) -> EffectApplyOutcome {
        guard case let .drawCards(count) = effect, count > 0 else {
            return EffectApplyOutcome(didApply: false)
        }
        let drawTarget = drawRecipient(in: context)
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
        let drawnCards = collectDrawnCards(
            targetCount: count, firstOwner: firstOwner,
            allowFallback: count > 1,
            in: &context,
        )
        guard !drawnCards.isEmpty else {
            return EffectApplyOutcome(didApply: false)
        }

        emit(.cardsDrawn, amount: drawnCards.count, keyword: .physical, origin: .automatic, in: &context)
        context.resolution.enter(.draw)
        defer { context.resolution.leave(.draw) }
        let played = await context.withAutomaticPlay { context in
            var criticalAttackActorIDs: Set<String> = []
            for card in drawnCards {
                guard let played = try? await BattleCardCombatEngine.resolveDrawnCard(card, context: &context) else { continue }
                criticalAttackActorIDs.formUnion(played)
            }
            return criticalAttackActorIDs
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
            let owner = index.isMultiple(of: 2) ? firstOwner : otherOwner
            let fallback: BattleParticipant = owner == .hero ? .companion : .hero
            let candidate: BattleParticipant
            if canDrawAndPlay(owner, in: context) {
                candidate = owner
            } else if allowFallback, canDrawAndPlay(fallback, in: context) {
                candidate = fallback
            } else {
                // Collection cannot restore exhausted or blocked decks.
                break
            }
            guard let card = BattleCardCombatEngine.drawOne(for: candidate, context: &context) else { break }
            drawnCards.append(card)
        }

        return drawnCards
    }

    private func canDrawAndPlay(_ owner: BattleParticipant, in context: BattleState) -> Bool {
        guard BattleCardCombatEngine.canDrawFromDeck(for: owner, in: context) else { return false }
        guard !context.ownersSkippingThisPlayerTurn.contains(owner) else { return false }
        let ability = BattleCardCombatEngine.firstDeckAbility(for: owner, in: context)
        guard let ability else { return false }
        let actor = context.roster[owner].combatant
        return BattleAbilityRules.canPayHealthCost(ability, actor: actor, in: context)
            && BattleAbilityRules.canPayBlockCost(ability, actor: actor, in: context)
    }
}
