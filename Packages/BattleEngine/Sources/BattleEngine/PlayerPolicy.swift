import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

enum SimAction: Equatable, Sendable {
    case playCard(id: Int)
    case endTurn
}

/// Prefer lethal damage, then higher ability tiers, then raw direct damage.
/// Stable `id` is recorded in balance-sweep reports (e.g. `greedy-v1`).
public struct GreedyHeuristicPolicy: Sendable {
    public let id = "greedy-v1"

    public init() {}

    func nextAction(in battle: BattleState) -> SimAction {
        let playable = battle.hand.cards.filter { battle.isCardPlayable($0) }
        guard let best = playable.max(by: { lhs, rhs in
            score(lhs, in: battle) < score(rhs, in: battle)
        }) else {
            return .endTurn
        }
        return .playCard(id: best.id)
    }

    private func score(_ card: BattleCard, in battle: BattleState) -> Int {
        let ability = card.ability
        let enemyHP = battle.health(of: battle.enemy)
        let ownerCombatant = card.owner == .hero ? battle.hero : battle.companion
        let actorHP = battle.health(of: ownerCombatant)
        let maxHP = max(battle.maxHealth(of: ownerCombatant), 1)
        let hpFraction = Double(actorHP) / Double(maxHP)

        let damage = ability.directDamage
        let selfDamage = ability.damageComponents
            .filter { $0.target == .actor }
            .reduce(0) { $0 + $1.amount }

        // 1. Immediate Lethal Finish
        if damage > 0, damage >= enemyHP {
            return 10000 + damage
        }

        // 2. Fatal Self-Damage Check (prevent suicide)
        if selfDamage > 0, selfDamage >= actorHP {
            return -10000
        }

        // 3. Heavy de-prioritization when HP < 50%
        let selfDamagePenalty = (selfDamage > 0 && hpFraction < 0.5) ? (selfDamage * 10 + 50) : (selfDamage * 2)
        var value = damage - selfDamagePenalty

        if ability.hasLeech {
            value += 5
        }

        for targeted in ability.targetedEffects {
            switch targeted.effect {
            case let .drawCards(count):
                value += count * 3
            case let .shield(_, amount):
                value += amount
            case let .instantHeal(_, amount):
                value += amount
            case let .burn(amount), let .poison(amount), let .bleed(amount):
                value += amount * 2
            default:
                value += 2
            }
        }

        return value
    }
}
