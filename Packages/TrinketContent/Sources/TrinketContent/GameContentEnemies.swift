import Foundation
import TrinketCore

enum GameContentEnemies {
    static let enemies: [Enemy] = GameContentEnemiesGenerated.enemies
    static let enemiesByID: [String: Enemy] = Dictionary(
        uniqueKeysWithValues: enemies.map { ($0.id, $0) }
    )
}
