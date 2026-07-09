import Foundation
import TrinketContent

/// Shell-session token for resuming an in-progress battle after background / cold launch.
enum ActiveBattleResumeToken: Equatable {
    case journey(stageID: String)
    case aspect(aspectID: AspectID, floor: Int)
    case labyrinth(nodeID: String)
}
