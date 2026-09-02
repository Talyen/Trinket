import TrinketCore

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
