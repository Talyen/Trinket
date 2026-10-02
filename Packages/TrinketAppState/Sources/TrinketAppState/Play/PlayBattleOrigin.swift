import BattleEngine
import TrinketContent
import TrinketCore
import TrinketFeatureContracts

public enum PlayBattleOrigin: Hashable, Sendable {
    case journey(stageID: String)
    case spire(spireID: SpireID, floor: Int)
    case labyrinth(nodeID: String)
    case contract(offerID: String)
    case voyage(runID: String, nodeID: String)

    public var runKey: BattleRunKey {
        switch self {
        case let .journey(stageID):
            BattleRunKey("journey|\(stageID)")
        case let .spire(spireID, floor):
            BattleRunKey("spire|\(spireID.rawValue)|\(floor)")
        case let .labyrinth(nodeID):
            BattleRunKey("labyrinth|\(nodeID)")
        case let .voyage(runID, nodeID):
            BattleRunKey("voyage|\(runID)|\(nodeID)")
        case let .contract(offerID):
            BattleRunKey("contract|\(offerID)")
        }
    }

    /// Owner scope for prepared-run pruning: one mode's pruning must never
    /// destroy a sibling mode's warms.
    var isLabyrinth: Bool {
        if case .labyrinth = self {
            return true
        }
        return false
    }
}

@MainActor
struct PlayBattleRunRegistration {
    let route: PlayBattleRoute
    let launch: BattleLaunchAssembly
    var presentation: BattlePresentationContext {
        launch.presentation
    }

    var universalModifiers: [AffixModifier] {
        launch.universalModifiers
    }
}
