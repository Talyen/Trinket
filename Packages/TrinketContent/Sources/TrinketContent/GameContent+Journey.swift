import Foundation

public extension GameContent {
    static let chapters: [Chapter] = GameContentChapters.chapters

    static func chapter(containing stage: Stage) -> Chapter {
        chapters.first { $0.id == stage.chapterID } ?? chapters[0]
    }

    static func chapter(id: String) -> Chapter? {
        chapters.first { $0.id == id }
    }

    static func nextChapter(after chapter: Chapter) -> Chapter? {
        guard let chapterIndex = chapters.firstIndex(where: { $0.id == chapter.id }),
              chapters.indices.contains(chapterIndex + 1)
        else { return nil }
        return chapters[chapterIndex + 1]
    }
}
