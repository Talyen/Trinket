import Foundation
import TrinketContent
import TrinketFeatureSupport

/// Shell-session token for resuming an in-progress battle after background / cold launch.
public enum ActiveBattleResumeToken: Hashable {
    case journey(stageID: String)
    case spire(spireID: SpireID, floor: Int)
    case labyrinth(nodeID: String)
}
