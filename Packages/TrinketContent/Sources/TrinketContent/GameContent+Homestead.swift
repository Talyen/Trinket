import Foundation
import TrinketCore

public extension GameContent {
    static let homesteadNodes: [HomesteadNodeDefinition] = GameContentHomesteadGenerated.homesteadNodes

    static let homesteadNodesByID: [HomesteadNodeID: HomesteadNodeDefinition] = Dictionary(
        uniqueKeysWithValues: homesteadNodes.map { ($0.id, $0) },
    )

    static func homesteadNode(matching id: HomesteadNodeID) -> HomesteadNodeDefinition? {
        homesteadNodesByID[id]
    }
}
