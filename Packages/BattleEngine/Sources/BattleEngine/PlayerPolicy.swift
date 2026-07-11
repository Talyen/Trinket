import Foundation
import TrinketContent
import TrinketCore

public enum SimAction: Equatable, Sendable {
    case playCard(id: Int)
    case endTurn
}

public protocol PlayerPolicy: Sendable {
    /// Stable ID recorded in sweep reports (e.g. `greedy-v1`).
    var id: String { get }
    func nextAction(in battle: BattleState) -> SimAction
}

/// Prefer lethal damage, then higher ability tiers, then raw direct damage.
public struct GreedyHeuristicPolicy: PlayerPolicy {
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
