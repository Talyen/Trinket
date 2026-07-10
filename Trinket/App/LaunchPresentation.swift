import TrinketContent

enum LaunchPresentation: Equatable {
    case collectionCombatant(CombatantDetailContext)
    case collectionItem(String)
}

/// Deep-link / return target on the Play tab (launch args or post-battle restore).
enum PlayLaunchDestination: Equatable, Hashable {
    case labyrinthMap
    case aspectClimb(AspectID)

    /// Maps a battle origin token to a Play return destination.
    /// Journey (and unknown) battles return `nil` so Play stays on the journey map root.
    static func returning(from token: ActiveBattleResumeToken?) -> PlayLaunchDestination? {
        switch token {
        case .none, .journey:
            return nil
        case let .aspect(aspectID, _):
            return .aspectClimb(aspectID)
        case .labyrinth:
            return .labyrinthMap
        }
    }
}
