import TrinketContent
import TrinketCore
import TrinketFeatureContracts

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
    case battleVictory
    case shop
    case mystery
    case labyrinth
    case labyrinthMap

    public static func parse(_ raw: String) -> Self? {
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard let kind = parts.first?.lowercased() else { return nil }
        let id = parts.count == 2 ? parts[1] : ""
        switch kind {
        case "hero" where !id.isEmpty: return .heroDetail(id)
        case "companion" where !id.isEmpty: return .companionDetail(id)
        case "item" where !id.isEmpty: return .itemDetail(id)
        case "options": return .options
        case "battle": return .battle
        case "battle-victory": return .battleVictory
        case "shop": return .shop
        case "mystery": return .mystery
        case "labyrinth": return .labyrinth
        case "labyrinth-map": return .labyrinthMap
        default: return nil
        }
    }
}

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

public enum HomesteadRoute: Hashable, Identifiable, Sendable {
    case category(HomesteadNodeCategory)
    case node(HomesteadNodeID)

    public var id: String {
        switch self {
        case let .category(category):
            "category-\(category.rawValue)"
        case let .node(nodeID):
            "node-\(nodeID.rawValue)"
        }
    }
}
