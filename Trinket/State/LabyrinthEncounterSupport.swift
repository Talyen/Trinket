import Foundation
import TrinketContent

enum LabyrinthEncounterSupport {
    static func syntheticStage(nodeID: String, encounter: StageEncounter) -> Stage {
        Stage(
            id: nodeID,
            chapterID: "labyrinth",
            chapterNumber: 0,
            stageNumber: 0,
            flavorText: "A path in the Wanderer's Labyrinth.",
            encounter: encounter,
            rewards: .empty
        )
    }
}
