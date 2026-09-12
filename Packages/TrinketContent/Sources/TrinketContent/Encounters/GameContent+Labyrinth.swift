import Foundation
import TrinketCore

public extension GameContent {
    static var labyrinthModifiers: [LabyrinthModifierDefinition] {
        LabyrinthCatalog.modifiers
    }

    static func labyrinthModifier(id: LabyrinthModifierID) -> LabyrinthModifierDefinition? {
        LabyrinthCatalog.modifier(id: id)
    }

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
