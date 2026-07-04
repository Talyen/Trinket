import Foundation

public extension GameContent {
    static func encounterArtID(for stage: Stage) -> String? {
        GameContentEncounterArtGenerated.stageEncounterArt[stage.id]?.id
    }

    static func encounterArtTitle(for stage: Stage) -> String? {
        GameContentEncounterArtGenerated.stageEncounterArt[stage.id]?.title
    }
}
