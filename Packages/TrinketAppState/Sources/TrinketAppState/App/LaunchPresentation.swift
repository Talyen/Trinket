import TrinketContent
import TrinketFeatureContracts
import TrinketPersistence

public enum LaunchPresentation: Equatable {
    case collectionCombatant(CombatantDetailContext)
    case collectionItem(String)
}

public enum PlayLaunchDestination: Equatable, Hashable, Identifiable {
    case campaign
    case explore
    case spiresHub
    case labyrinthMap
    case spireClimb(SpireID)

    public var id: String {
        switch self {
        case .campaign:
            "campaign"
        case .explore:
            "explore"
        case .spiresHub:
            "spiresHub"
        case .labyrinthMap:
            "labyrinthMap"
        case let .spireClimb(spireID):
            "spireClimb-\(spireID.rawValue)"
        }
    }

    static func returning(from origin: PlayBattleOrigin?) -> Self? {
        switch origin {
        case .none:
            nil
        case .journey:
            .campaign
        case let .spire(spireID, _):
            .spireClimb(spireID)
        case .labyrinth:
            .labyrinthMap
        }
    }
}
