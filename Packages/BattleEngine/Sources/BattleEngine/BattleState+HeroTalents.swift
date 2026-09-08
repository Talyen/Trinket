import TrinketContent
import TrinketCore

extension BattleState {
    var allowsHeroTalentReaction: Bool {
        heroTalents.reactionDepth == 0
    }

    mutating func claimHeroTalent(_ name: String, actorID: String, battle: Bool = false) -> Bool {
        guard allowsHeroTalentReaction else { return false }
        let key = actorID + ":" + name
        if battle {
            return heroTalents.battleClaims.insert(key).inserted
        }
        guard heroTalents.turnClaims[key] != turnCount else { return false }
        heroTalents.turnClaims[key] = turnCount
        return true
    }

    mutating func mutateHeroCard(_ body: (inout HeroTalentCardFacts) -> Void) {
        guard allowsHeroTalentReaction, !heroTalents.cards.isEmpty else { return }
        body(&heroTalents.cards[heroTalents.cards.count - 1])
    }

    func hasHeroCard(for actorID: String) -> Bool {
        allowsHeroTalentReaction && heroTalents.cards.last?.actorID == actorID
    }

    mutating func claimHeroCardBonus(_ name: String, actorID: String) -> Bool {
        guard hasHeroCard(for: actorID), let card = heroTalents.cards.last,
              !card.appliedBonuses.contains(name) else { return false }
        mutateHeroCard { $0.appliedBonuses.insert(name) }
        return true
    }

    func hasTalentStatus(_ kind: EffectKind, on target: Combatant) -> Bool {
        roster.activeEffects(for: target).contains { $0.effect.kind == kind && ($0.effect.potency ?? 1) > 0 }
    }

    func hasTalentDebuff(on target: Combatant) -> Bool {
        roster.activeEffects(for: target).contains { $0.effect.isRemovableDebuff }
    }

    mutating func removeTalentPoint(_ kind: EffectKind, from target: Combatant) {
        guard roster.health(for: target) > 0 else { return }
        var effects = roster.activeEffects(for: target)
        guard let index = effects.firstIndex(where: { $0.effect.kind == kind }) else { return }
        let replacement: Effect
        switch effects[index].effect {
        case let .burn(amount): replacement = .burn(max(0, amount - 1))
        case let .poison(amount): replacement = .poison(max(0, amount - 1))
        case let .thorns(amount): replacement = .thorns(max(0, amount - 1))
        case let .shield(keyword, amount): replacement = .shield(keyword, max(0, amount - 1))
        default: return
        }
        let isEmpty: Bool = if case let .shield(_, amount) = replacement {
            amount == 0
        } else {
            replacement.potency == 0
        }
        if isEmpty {
            effects.remove(at: index)
        } else {
            effects[index].effect = replacement
        }
        roster.setActiveEffects(effects, for: target)
    }
}
