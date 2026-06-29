import SwiftUI

enum AppTab: String, CaseIterable {
    case play
    case collection
    case homestead
    case search

    var symbolName: String {
        switch self {
        case .play: return "map.fill"
        case .collection: return "person.2.fill"
        case .homestead: return "house.fill"
        case .search: return "magnifyingglass"
        }
    }

    var displayName: String {
        switch self {
        case .play: return "Play"
        case .collection: return "Collection"
        case .homestead: return "Homestead"
        case .search: return "Search"
        }
    }
}

enum LaunchScreen: Equatable {
    case heroDetail(String)
    case petDetail(String)
    case itemDetail(String)
    case options
    case battle
}

enum BattleLaunchPreset: String {
    case fresh
    case oneShot = "oneShot"
}
