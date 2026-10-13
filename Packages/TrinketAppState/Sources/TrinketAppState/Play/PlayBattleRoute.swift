import BattleEngine
import TrinketPersistence

typealias PlayBattleRoute = BattleCompletionDestination

extension BattleCompletionDestination {
    var mode: PlayBattleMode {
        origin.mode
    }

    var origin: PlayBattleOrigin {
        switch self {
        case let .journey(stage): .journey(stageID: stage.id)
        case let .spire(floor): .spire(spireID: floor.spireID, floor: floor.floor)
        case let .labyrinth(nodeID, _): .labyrinth(nodeID: nodeID)
        case let .contract(offerID): .contract(offerID: offerID)
        case let .voyage(runID, nodeID, _, _): .voyage(runID: runID, nodeID: nodeID)
        }
    }

    static func matches(_ route: Self?, runKey: BattleRunKey?, missingLog: String) -> Bool {
        guard let runKey else { return route == nil }
        guard let route, route.origin.runKey == runKey else {
            appStateLogger.error("\(missingLog, privacy: .public)")
            return false
        }
        return true
    }
}
