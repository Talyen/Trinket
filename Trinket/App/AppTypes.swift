enum AppTab: String, CaseIterable {
    case play
    case collection
    case homestead
    case options

    var symbolName: String {
        switch self {
        case .play: "map.fill"
        case .collection: "person.2.fill"
        case .homestead: "house.fill"
        case .options: "gearshape.fill"
        }
    }

    var displayName: String {
        switch self {
        case .play: "Play"
        case .collection: "Collection"
        case .homestead: "Homestead"
        case .options: "Options"
        }
    }
}

enum LaunchScreen: Equatable {
    case heroDetail(String)
    case petDetail(String)
    case itemDetail(String)
    case options
    case battle
    /// Test-only: stage 1-1 battle already at victory chrome (no live tick loop).
    case battleVictory
    case shop
    case mystery
    case labyrinth
    case labyrinthMap
}
