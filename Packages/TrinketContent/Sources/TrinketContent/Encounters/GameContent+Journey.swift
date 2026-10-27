import Foundation
import TrinketCore

public extension GameContent {
    static let chapters: [Chapter] = GameContentChaptersGenerated.chapters

    private static let chaptersByID = Dictionary(chapters.lazy.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    static func chapter(containing stage: Stage) -> Chapter {
        chaptersByID[stage.chapterID] ?? chapters[0]
    }

    static func chapter(id: String) -> Chapter? {
        chaptersByID[id]
    }

    static let stages: [Stage] = chapters.flatMap(\.stages)

    static func stage(id: String) -> Stage? {
        GameContentStagesIndexGenerated.stagesByID[id]
    }
}
