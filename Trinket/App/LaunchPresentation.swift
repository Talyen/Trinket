import TrinketContent
import TrinketPersistence

enum LaunchPresentation: Equatable {
    case collectionCombatant(CombatantDetailContext)
    case collectionItem(String)
}

/// Deep-link / return target on the Play tab (launch args or post-battle).
///
/// The route is intentionally flat and `PlayView` expands it into a
/// hierarchical path (`Explore → Spires → Climb`, for example). Keeping the
/// value Hashable makes it safe to use with `NavigationStack(path:)`.
enum PlayLaunchDestination: Equatable, Hashable, Identifiable {
    case campaign
    case explore
    case spiresHub
    case labyrinthMap
    case spireClimb(SpireID)

    var id: String {
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

    /// Maps a battle origin token to a Play return destination.
    /// Journey battles return to the Campaign stage screen (Mode Hub peer).
    static func returning(from token: ActiveBattleResumeToken?) -> PlayLaunchDestination? {
        switch token {
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
