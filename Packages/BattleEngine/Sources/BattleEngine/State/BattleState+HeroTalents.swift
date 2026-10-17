import TrinketContent
import TrinketCore

/// Claim and cadence guards over `CombatResolution` for hero-talent reactions.
package extension BattleState {
    internal mutating func consumeTalentPreparation<Value>(
        _ keyPath: WritableKeyPath<CombatantTalentState.Pending, PreparedTalentBonus<Value>?>,
        for actor: Combatant,
    ) -> Value? {
        let cardSerial = resolution.cardTalents?.playSerial
        let actionID = resolution.actionID
        var consumed: Value?
        roster.mutateRuntime(for: actor) { runtime in
            guard let preparation = runtime.talents.pending[keyPath: keyPath],
                  let value = preparation.availableValue(cardSerial: cardSerial, actionID: actionID) else { return }
            consumed = value
            runtime.talents.pending[keyPath: keyPath] = nil
        }
        return consumed
    }

    internal mutating func prepareAttackBonus(
        _ amount: Int,
        _ keyPath: WritableKeyPath<CombatantTalentState.Pending, PreparedTalentBonus<Int>?>,
        for actor: Combatant,
    ) {
        guard amount > 0, roster.runtime(for: actor)?.isAlive == true else { return }
        let bonus = PreparedTalentBonus(
            value: amount, cardSerial: resolution.cardTalents?.playSerial, actionID: resolution.actionID,
        )
        roster.mutateRuntime(for: actor) { $0.talents.pending[keyPath: keyPath] = bonus }
    }

    var allowsHeroTalentReaction: Bool {
        resolution.depth(.heroReaction) == 0
    }

    mutating func claimHeroTalent(_ claim: CombatActivationClaim, actorID: String, battle: Bool = false) -> Bool {
        guard allowsHeroTalentReaction else { return false }
        return resolution.claim(.heroTalent(claim), actorID: actorID, cadence: battle ? .battle : .turn(turnCount))
    }

    mutating func mutateHeroCard(_ body: (inout HeroTalentCardFacts) -> Void) {
        guard allowsHeroTalentReaction else { return }
        resolution.mutateCardTalents(body)
    }

    func hasHeroCard(for actorID: String) -> Bool {
        allowsHeroTalentReaction && resolution.attackOrigin != .counterattack && resolution.cardTalents?.actorID == actorID
    }

    mutating func claimHeroCardBonus(_ claim: CombatActivationClaim, actorID: String) -> Bool {
        guard hasHeroCard(for: actorID), let card = resolution.cardTalents else { return false }
        return resolution.claim(.heroCard(claim), actorID: actorID, cadence: .card(card.playSerial))
    }

    mutating func claimTalentAbility(_ claim: CombatActivationClaim, actorID: String) -> Bool {
        guard allowsHeroTalentReaction else { return false }
        let cadence: CombatResolution.Cadence = if hasHeroCard(for: actorID),
                                                   let serial = resolution.cardTalents?.playSerial {
            .card(serial)
        } else if let actionID = resolution.actionID {
            .action(actionID)
        } else if let restorationID = resolution.standaloneRestorationID {
            .standaloneRestoration(restorationID)
        } else {
            .standaloneAction(actionCount)
        }
        return resolution.claim(.heroTalent(claim), actorID: actorID, cadence: cadence)
    }

    mutating func claimActionGuard(_ kind: CombatActivationClaim, actorID: String) -> Bool {
        let cadence = resolution.actionID.map(CombatResolution.Cadence.action) ?? .standaloneAction(actionCount)
        return resolution.claim(.talent(kind), actorID: actorID, cadence: cadence)
    }

    mutating func claimBattleGuard(_ kind: CombatActivationClaim, actorID: String) -> Bool {
        resolution.claim(.talent(kind), actorID: actorID, cadence: .battle)
    }

    mutating func claimTurnGuard(_ kind: CombatActivationClaim, actorID: String) -> Bool {
        resolution.claim(.talent(kind), actorID: actorID, cadence: .turn(turnCount))
    }

    func hasTalentDebuff(on target: Combatant) -> Bool {
        roster.activeEffects(for: target).contains { $0.effect.isRemovableDebuff }
    }

    mutating func removeTalentPoints(_ count: Int, kind: EffectKind, from target: Combatant) {
        guard count > 0, roster.health(for: target) > 0 else { return }
        var remaining = count
        roster.mutateEffects(for: target) { effects in
            ActiveEffectMutation.update(&effects) { active in
                guard remaining > 0, active.effect.kind == kind else { return active }
                let amount: Int
                switch active.effect {
                case let .burn(value), let .poison(value), let .thorns(value), let .shield(_, value): amount = max(0, value)
                default: return active
                }
                let removed = min(remaining, amount)
                remaining -= removed
                let retained = amount - removed
                guard retained > 0 else { return nil }
                var updated = active
                switch active.effect {
                case .burn: updated.effect = .burn(retained)
                case .poison: updated.effect = .poison(retained)
                case .thorns: updated.effect = .thorns(retained)
                case let .shield(keyword, _): updated.effect = .shield(keyword, retained)
                default: break
                }
                return updated
            }
        }
    }
}
