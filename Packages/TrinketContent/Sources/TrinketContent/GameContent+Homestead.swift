import Foundation
import TrinketCore

public extension GameContent {
    static let homesteadNodes: [HomesteadNodeDefinition] = GameContentHomesteadGenerated.homesteadNodes

    static func homesteadNode(matching id: HomesteadNodeID) -> HomesteadNodeDefinition? {
        homesteadNodes.first { $0.id == id }
    }
}
