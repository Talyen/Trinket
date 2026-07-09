enum LaunchPresentation: Equatable {
    case collectionCombatant(CombatantDetailContext)
    case collectionItem(String)
}

enum PlayLaunchDestination: Equatable, Hashable {
    case labyrinthMap
}
