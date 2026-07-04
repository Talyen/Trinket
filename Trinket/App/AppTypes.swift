import SwiftUI


enum AppTab: String, CaseIterable {
    case play
    case collection
    case homestead
    case search
    case options

    var symbolName: String {
        switch self {
        case .play: return "map.fill"
        case .collection: return "person.2.fill"
        case .homestead: return "house.fill"
        case .search: return "magnifyingglass"
        case .options: return "gearshape.fill"
        }
    }

    var displayName: String {
        switch self {
        case .play: return "Play"
        case .collection: return "Collection"
        case .homestead: return "Homestead"
        case .search: return "Search"
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
}
