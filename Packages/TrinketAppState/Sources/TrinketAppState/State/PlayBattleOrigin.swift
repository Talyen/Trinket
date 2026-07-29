import Foundation
import TrinketBattleFeature
import TrinketContent
import TrinketFeatureSupport

/// Play-mode origin for an active or prepared battle. Owned by AppState —
/// BattleFeature only sees the opaque `BattleRunKey` and presentation fields.
public enum PlayBattleOrigin: Hashable, Sendable {
    case journey(stageID: String)
    case spire(spireID: SpireID, floor: Int)
    case labyrinth(nodeID: String)

    public var runKey: BattleRunKey {
        switch self {
        case let .journey(stageID):
            BattleRunKey("journey|\(stageID)")
        case let .spire(spireID, floor):
            BattleRunKey("spire|\(spireID.rawValue)|\(floor)")
        case let .labyrinth(nodeID):
            BattleRunKey("labyrinth|\(nodeID)")
        }
    }

    public var defeatPrimaryAction: BattleDefeatPrimaryAction {
        switch self {
        case .labyrinth:
            .retreat
        case .journey, .spire:
            .restart
        }
    }

    public var musicStageID: String? {
        if case let .journey(stageID) = self {
            return stageID
        }
        return nil
    }

    public init?(runKey: BattleRunKey) {
        let parts = runKey.rawValue.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        switch parts.first {
        case "journey" where parts.count == 2:
            self = .journey(stageID: parts[1])
        case "spire" where parts.count == 3:
            guard let floor = Int(parts[2]) else { return nil }
            self = .spire(spireID: SpireID(rawValue: parts[1]), floor: floor)
        case "labyrinth" where parts.count == 2:
            self = .labyrinth(nodeID: parts[1])
        default:
            return nil
        }
    }
}
