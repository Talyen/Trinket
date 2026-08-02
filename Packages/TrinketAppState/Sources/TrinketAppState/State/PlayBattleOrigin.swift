import Foundation
import TrinketBattleContracts
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts

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
}

/// App-owned completion capability for one active battle route.
///
/// BattleFeature only receives the opaque run key. Play registers the matching
/// typed origin and mode-owned persistence closure before preparing or starting
/// the run, so completion never has to decode a string or guess its owner.
@MainActor
struct PlayBattleRoute {
    let origin: PlayBattleOrigin
    let complete: @MainActor (BattleRunConfiguration, BattlePresentationContext?, Int, [ResourceAmount]?) -> Bool
}

/// Complete metadata for one prepared or active Play battle.
///
/// Route, presentation, and restart-only modifiers are committed as one value
/// so a run can never become visible with only half of its completion data.
@MainActor
struct PlayBattleRunRegistration {
    let route: PlayBattleRoute
    let presentation: BattlePresentationContext
    let universalModifiers: [AffixModifier]
}
