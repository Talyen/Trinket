enum AppTab: String, CaseIterable {
    case play
    case collection
    case homestead
    case options

    var symbolName: String {
        switch self {
        case .play: return "map.fill"
        case .collection: return "person.2.fill"
        case .homestead: return "house.fill"
        case .options: return "gearshape.fill"
        }
    }

    var displayName: String {
        switch self {
        case .play: return "Play"
        case .collection: return "Collection"
        case .homestead: return "Homestead"
        case .options: return "Options"
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
