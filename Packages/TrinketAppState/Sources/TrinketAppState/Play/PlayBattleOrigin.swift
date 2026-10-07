import BattleEngine
import TrinketContent
import TrinketCore
import TrinketFeatureContracts

public enum PlayBattleMode: String, Hashable, CaseIterable, Sendable {
    case journey
    case spire
    case labyrinth
    case contract
    case voyage
}

public enum PlayBattleOrigin: Hashable, Sendable {
    case journey(stageID: String)
    case spire(spireID: SpireID, floor: Int)
    case labyrinth(nodeID: String)
    case contract(offerID: String)
    case voyage(runID: String, nodeID: String)

    public var mode: PlayBattleMode {
        switch self {
        case .journey: .journey
        case .spire: .spire
        case .labyrinth: .labyrinth
        case .contract: .contract
        case .voyage: .voyage
        }
    }

    public func matches(mode: PlayBattleMode) -> Bool {
        self.mode == mode
    }

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
}

@MainActor
struct PlayBattleRunRegistration {
    let route: PlayBattleRoute?
    let launch: BattleLaunchAssembly
    var presentation: BattlePresentationContext {
        launch.presentation
    }

    var universalModifiers: [AffixModifier] {
        launch.universalModifiers
    }
}
