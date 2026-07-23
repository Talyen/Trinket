import Foundation
import TrinketContent

/// Shell-session token for resuming an in-progress battle after background / cold launch.
enum ActiveBattleResumeToken: Hashable {
    case journey(stageID: String)
    case spire(spireID: SpireID, floor: Int)
    case labyrinth(nodeID: String)
}
