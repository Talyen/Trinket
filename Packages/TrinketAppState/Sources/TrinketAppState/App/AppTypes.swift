import TrinketBattleFeature
import TrinketFeatureSupport

public enum AppTab: String, CaseIterable, Sendable {
    case play
    case collection
    case homestead
    case options

    public var symbolName: String {
        switch self {
        case .play: "map.fill"
        case .collection: "person.2.fill"
        case .homestead: "house.fill"
        case .options: "gearshape.fill"
        }
    }

    public var displayName: String {
        switch self {
        case .play: "Play"
        case .collection: "Collection"
        case .homestead: "Homestead"
        case .options: "Options"
        }
    }
}

public enum LaunchScreen: Equatable, Sendable {
    case heroDetail(String)
    case companionDetail(String)
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
