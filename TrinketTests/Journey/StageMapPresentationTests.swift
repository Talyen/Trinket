import TrinketContent
import TrinketPersistence
import Testing
@testable import Trinket

@Suite
struct StageMapPresentationTests {
    @Test func chapterGateIDUsesChapterIdentifier() {
        let chapter = GameContent.chapters[0]

        #expect(StageMapID.chapterGate(for: chapter) == "chapter-gate-\(chapter.id)")
    }

    @Test func placeholderGateIDUsesChapterNumber() {
        #expect(StageMapID.placeholderGate(afterChapterNumber: 2) == "chapter-gate-placeholder-2")
    }

    @Test func chapterJourneyRowIDMatchesStageOrGate() throws {
        let stage = try #require(GameContent.chapters[0].stages.first)
        let gateChapter = Chapter(
            id: StageMapID.placeholderGate(afterChapterNumber: 2),
            number: 2,
            title: "",
            theme: GameContent.chapters[0].theme,
            stages: []
        )

        #expect(ChapterJourneyRow.stage(stage == .active).id, stage.id)
        #expect(ChapterJourneyRow.chapterGate(gateChapter).id == StageMapID.chapterGate(for: gateChapter))
    }

    @Test func stageMapLabelFormatsChapterAndStageNumber() throws {
        let stage = try #require(GameContent.chapters[0].stages.first)

        #expect(stage.mapLabel == "Stage \(stage.chapterNumber)-\(stage.stageNumber)")
    }
}
