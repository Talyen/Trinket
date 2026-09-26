import Foundation
import TrinketCore

public extension GameContent {
    static func syntheticLabyrinthStage(
        nodeID: String,
        encounter: StageEncounter,
    ) -> Stage {
        Stage(
            id: nodeID,
            chapterID: "labyrinth",
            chapterNumber: 0,
            stageNumber: 0,
            encounter: encounter,
            rewards: .empty,
        )
    }
}
