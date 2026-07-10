import TrinketContent
import TrinketPersistence

enum LaunchPresentation: Equatable {
    case collectionCombatant(CombatantDetailContext)
    case collectionItem(String)
}

/// Deep-link / return target on the Play tab (launch args, last-mode restore, or post-battle).
enum PlayLaunchDestination: Equatable, Hashable, Identifiable {
    case campaign
    case aspectsHub
    case labyrinthMap
    case aspectClimb(AspectID)

    var id: String {
        switch self {
        case .campaign:
            return "campaign"
        case .aspectsHub:
            return "aspectsHub"
        case .labyrinthMap:
            return "labyrinthMap"
        case let .aspectClimb(aspectID):
            return "aspectClimb-\(aspectID.rawValue)"
        }
    }

    /// Maps a battle origin token to a Play return destination.
    /// Journey battles return to the Campaign stage screen (Mode Hub peer).
    static func returning(from token: ActiveBattleResumeToken?) -> PlayLaunchDestination? {
        switch token {
        case .none:
            return nil
        case .journey:
            return .campaign
        case let .aspect(aspectID, _):
            return .aspectClimb(aspectID)
        case .labyrinth:
            return .labyrinthMap
        }
    }

    static func restoring(lastMode: PlayerShellSessionPlayMode) -> PlayLaunchDestination {
        switch lastMode {
        case .campaign:
            return .campaign
        case .aspects:
            return .aspectsHub
        case .labyrinth:
            return .labyrinthMap
        }
    }
}
