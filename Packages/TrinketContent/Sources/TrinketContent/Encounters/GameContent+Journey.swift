import Foundation
import TrinketCore

public extension GameContent {
    static let chapters: [Chapter] = GameContentChaptersGenerated.chapters

    static func chapter(containing stage: Stage) -> Chapter {
        chapters.first { $0.id == stage.chapterID } ?? chapters[0]
    }

    static func chapter(id: String) -> Chapter? {
        chapters.first { $0.id == id }
    }

    static let stages: [Stage] = chapters.flatMap(\.stages)

    static func stage(id: String) -> Stage? {
        GameContentStagesIndexGenerated.stagesByID[id]
    }
}
