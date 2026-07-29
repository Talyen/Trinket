import Testing
import TrinketContent
import TrinketPersistence
@testable import TrinketFeatureSupport

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
        #expect(rows[1].stage.encounterCombatantArtReference == nil)
        #expect(rows[1].stage.encounterArtReference != nil)
        #expect(abs(rows[1].stage.encounter.artAspectRatio - (4.0 / 3.0)) < 0.000_1)
        let bossRows = rows.filter(\.isBoss)
        #expect(bossRows.count == 1)
        #expect(bossRows[0].stage.encounterTypeTitle == "Boss")
    }

    @Test func battleStagesPreferEnemyArtOverEncounterArt() throws {
        let stage = try #require(GameContent.chapters[0].stages.first { $0.id == "chapter-1-stage-1" })

        #expect(GameContent.encounterArtID(for: stage) == nil)
        #expect(stage.encounterArtReference == nil)
        _ = try #require(stage.encounterCombatantArtReference)
        #expect(stage.encounterSubjectName == "Slime")
    }

    @Test func shopStagesFallBackToMerchantSubjectName() {
        let stage = Stage(
            id: "test-shop",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            encounter: .shop,
            rewards: .empty
        )

        #expect(GameContent.encounterArtID(for: stage) == nil)
        #expect(stage.encounterSubjectName == "Merchant")
    }

    @Test func mappedEventStagesResolveEncounterArtWithoutPinningCatalogIDs() throws {
        let stage = try #require(GameContent.chapters[1].stages.first { $0.id == "chapter-2-stage-8" })

        #expect(GameContent.encounterArtID(for: stage) != nil)
        _ = try #require(stage.encounterArtReference)
        #expect(!(stage.encounterSubjectName.isEmpty))
    }

    @Test func spireRowsHideClearedFloorsAndEndWithBossBeforeCompletion() throws {
        let spire = try #require(GameContent.spire(id: .ironVein))
        let floors = GameContent.spireFloors(for: spire.id)
        var progress = PlayerSpiresState.freshStart
        _ = progress.markFloorCleared(1, spireID: spire.id.rawValue)
        _ = progress.markFloorCleared(2, spireID: spire.id.rawValue)

        let rows = StageSelectRowPresentation<SpireFloor>.spireRows(
            for: spire,
            floors: floors,
            progress: progress
        )

        #expect(rows.map(\.item.floor) == Array(3 ... spire.floorCount))
        #expect(rows.first?.isActive == true)
        #expect(rows.dropFirst().allSatisfy { !$0.isActive })
        #expect(rows.first?.activeEyebrow == "Floor 3 · Battle")
        #expect(rows.first?.activeDetailLines.isEmpty == true)
        #expect(rows.last?.encounterTypeTitle == "Boss")

        for floor in 3 ... spire.floorCount {
            _ = progress.markFloorCleared(floor, spireID: spire.id.rawValue)
        }
        let completedRows = StageSelectRowPresentation<SpireFloor>.spireRows(
            for: spire,
            floors: floors,
            progress: progress
        )
        #expect(completedRows.isEmpty)
    }

    @Test func labyrinthNodeStatesFollowReachabilityAndCompletion() {
        let source = LabyrinthNode(
            id: "source",
            type: .battle,
            depth: 1,
            clusterID: "floor",
            gridPosition: LabyrinthGridPosition(row: 0, column: 1),
            outgoingIDs: ["target"],
            isCleared: true,
            isRevealed: true
        )
        let target = LabyrinthNode(
            id: "target",
            type: .shop,
            depth: 1,
            clusterID: "floor",
            gridPosition: LabyrinthGridPosition(row: 1, column: 1),
            isRevealed: true
        )
        let locked = LabyrinthNode(
            id: "locked",
            type: .mystery,
            depth: 1,
            clusterID: "floor",
            gridPosition: LabyrinthGridPosition(row: 1, column: 2),
            isRevealed: true
        )
        var state = PlayerLabyrinthState(
            hasEntered: true,
            nodes: [source.id: source, target.id: target, locked.id: locked]
        )

        #expect(LabyrinthMapPresentation.state(for: target, in: state) == .reachable)
        #expect(LabyrinthMapPresentation.state(for: locked, in: state) == .locked)

        var clearedTarget = target
        clearedTarget.isCleared = true
        state.nodes[target.id] = clearedTarget
        #expect(LabyrinthMapPresentation.state(for: clearedTarget, in: state) == .cleared)
    }
}
