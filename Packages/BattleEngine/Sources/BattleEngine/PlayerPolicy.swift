import Foundation
import TrinketContent
import TrinketCore

public enum SimAction: Equatable, Sendable {
    case playCard(id: Int)
    case endTurn
}

/// Prefer lethal damage, then higher ability tiers, then raw direct damage.
/// Stable `id` is recorded in balance-sweep reports (e.g. `greedy-v1`).
public struct GreedyHeuristicPolicy: Sendable {
    public let id = "greedy-v1"

    public init() {}

    public func nextAction(in battle: BattleState) -> SimAction {
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
        let damage = ability.directDamage
        var value = tierScore(ability.tier) + damage
        if damage > 0, damage >= enemyHP {
            value += 10000
        }
        if ability.hasLeech {
            value += 5
        }
        if !ability.targetedEffects.isEmpty {
            value += ability.targetedEffects.count
        }
        return value
    }

    private func tierScore(_ tier: AbilityTier) -> Int {
        switch tier {
        case .ultimate: 300
        case .skill: 200
        case .basic: 100
        }
    }
}
