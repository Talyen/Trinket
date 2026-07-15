import Testing
import TrinketContent
import TrinketPersistence
@testable import Trinket

struct StageMapPresentationTests {
    @Test func stageMapIdentifiersAndLabelsMatchAuthoredContent() throws {
        let chapter = GameContent.chapters[0]
        let stage = try #require(chapter.stages.first)
        #expect(StageMapID.chapterGate(for: chapter) == "chapter-gate-\(chapter.id)")
        #expect(StageMapID.placeholderGate(afterChapterNumber: 2) == "chapter-gate-placeholder-2")

        let gateChapter = Chapter(
            id: StageMapID.placeholderGate(afterChapterNumber: 2),
            number: 2,
            title: "",
            theme: chapter.theme,
            stages: []
        )
        #expect(ChapterJourneyRow.stage(stage, .active).id == stage.id)
        #expect(ChapterJourneyRow.chapterGate(gateChapter).id == StageMapID.chapterGate(for: gateChapter))
        #expect(stage.mapLabel == "Stage \(stage.chapterNumber)-\(stage.stageNumber)")
        #expect(stage.mapMetaLabel == "\(stage.mapLabel) · \(stage.encounterTypeTitle)")
    }

    @Test func chapterRowsKeepAllStagesAndStopProgressAtTheActiveNode() {
        let chapter = GameContent.chapters[0]
        var progress = JourneyProgressState.initial
        progress.completedStageIDs = [chapter.stages[0].id, chapter.stages[1].id]
        progress.lastCompletedStageID = chapter.stages[1].id
        progress.activeStageID = chapter.stages[2].id

        let rows = ChapterStageRowPresentation.rows(for: chapter, progress: progress)

        #expect(rows.count == chapter.stages.count)
        #expect(rows.map(\.stage.id) == chapter.stages.map(\.id))
        #expect(rows[0].state == .completed)
        #expect(rows[1].state == .justCompleted)
        #expect(rows[2].state == .active)
        #expect(rows[3].state == .future)
        #expect(rows[1].connectorAfter == .progressed)
        #expect(rows[2].connectorBefore == .progressed)
        #expect(rows[2].connectorAfter == .future)
        #expect(rows[3].connectorBefore == .future)
    }

    @Test func bossAndRecruitmentPresentationAreDerivedFromLiveContent() {
        let chapter = GameContent.chapters[0]
        let rows = ChapterStageRowPresentation.rows(for: chapter, progress: .initial)

        #expect(rows[1].stage.encounterSubjectName == "Mystery")
        #expect(rows[1].stage.encounterTypeTitle == "Recruit")
        #expect(rows[4].isBoss)
        #expect(rows[4].stage.encounterTypeTitle == "Boss")
    }

    @Test func clearedChapterShowsEveryReadOnlyRowUntilAdvance() {
        let chapter = GameContent.chapters[0]
        var progress = JourneyProgressState.initial
        progress.completedStageIDs = Set(chapter.stages.map(\.id))
        progress.lastCompletedStageID = chapter.stages.last?.id
        progress.activeChapterID = chapter.id
        progress.activeStageID = nil

        let rows = ChapterStageRowPresentation.rows(for: chapter, progress: progress)

        #expect(rows.count == chapter.stages.count)
        #expect(!rows.contains { !$0.isCompleted })
        #expect(rows.allSatisfy { !$0.isActionable })
        #expect(rows.dropLast().allSatisfy { $0.connectorAfter == .progressed })
        #expect(progress.pendingNextChapter()?.id == GameContent.chapters[1].id)
    }
}
