import BattleEngine
import Foundation

package enum SimAction: Equatable, Sendable {
    case playCard(id: Int)
    case endTurn
}

package extension PlayPolicy {
    func nextAction(in battle: BattleState) -> SimAction {
        guard let best = preferredPlayableCard(in: battle) else {
            return .endTurn
        }
        return .playCard(id: best.id)
    }
}

public enum SimulationPolicies {
    public static func make(id: String) -> PlayPolicy? {
        PlayPolicy(rawValue: id)
    }
}
