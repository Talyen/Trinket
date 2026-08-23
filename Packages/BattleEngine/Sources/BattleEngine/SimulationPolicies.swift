import BattleEngine
import Foundation

/// Sweep-harness action vocabulary consumed by `BattleSimulator`.
package enum SimAction: Equatable, Sendable {
    case playCard(id: Int)
    case endTurn
}

package extension SimulationPlayPolicy {
    func nextAction(in battle: BattleState) -> SimAction {
        guard let best = preferredPlayableCard(in: battle) else {
            return .endTurn
        }
        return .playCard(id: best.id)
    }
}

/// Resolves sweep `--policy` IDs to implementations. Lives beside the other
/// sweep tooling; the shipped library only exposes the policy types themselves.
public enum SimulationPolicies {
    public static func make(id: String) -> (any SimulationPlayPolicy)? {
        switch id {
        case GreedyHeuristicPolicy.id:
            GreedyHeuristicPolicy()
        case SetupAwareHeuristicPolicy.id:
            SetupAwareHeuristicPolicy()
        default:
            nil
        }
    }
}
