import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

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

@MainActor
struct PlayBattleRoute {
    let origin: PlayBattleOrigin
    let complete: @MainActor (
        BattleRunConfiguration,
        BattlePresentationContext?,
        Int,
        [ResourceAmount]?,
        BattleLootPackage?,
    ) -> Bool

    static func matches(_ route: Self?, runKey: BattleRunKey?, missingLog: String) -> Bool {
        guard let runKey else { return route == nil }
        guard let route, route.origin.runKey == runKey else {
            appStateLogger.error("\(missingLog, privacy: .public)")
            return false
        }
        return true
    }
}

@MainActor
struct PlayBattleRunRegistration {
    let route: PlayBattleRoute
    let presentation: BattlePresentationContext
    let universalModifiers: [AffixModifier]
}
