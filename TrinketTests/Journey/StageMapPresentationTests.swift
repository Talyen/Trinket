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

    @Test func aspectRowsHideClearedFloorsAndEndWithBossBeforeCompletion() throws {
        let aspect = try #require(GameContent.aspect(id: .ironVein))
        let floors = GameContent.aspectFloors(for: aspect.id)
        var progress = PlayerAspectsState.freshStart
        _ = progress.markFloorCleared(1, aspectID: aspect.id.rawValue)
        _ = progress.markFloorCleared(2, aspectID: aspect.id.rawValue)

        let rows = StageSelectRowPresentation<AspectFloor>.aspectRows(
            for: aspect,
            floors: floors,
            progress: progress
        )

        #expect(rows.map(\.item.floor) == Array(3 ... aspect.floorCount))
        #expect(rows.first?.isActive == true)
        #expect(rows.dropFirst().allSatisfy { !$0.isActive })
        #expect(rows.first?.activeEyebrow == "Floor 3 · Battle")
        #expect(rows.first?.activeDetailLines.isEmpty == true)
        #expect(rows.last?.encounterTypeTitle == "Boss")

        for floor in 3 ... aspect.floorCount {
            _ = progress.markFloorCleared(floor, aspectID: aspect.id.rawValue)
        }
        let completedRows = StageSelectRowPresentation<AspectFloor>.aspectRows(
            for: aspect,
            floors: floors,
            progress: progress
        )
        #expect(completedRows.isEmpty)
    }

    @Test func labyrinthNodeAndConnectorStatesFollowReachabilitySelectionAndCompletion() {
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
        #expect(
            LabyrinthMapPresentation.connectorState(
                from: source,
                to: target,
                selectedNodeID: nil,
                in: state
            ) == .reachable
        )
        #expect(
            LabyrinthMapPresentation.connectorState(
                from: source,
                to: target,
                selectedNodeID: target.id,
                in: state
            ) == .selected
        )

        var clearedTarget = target
        clearedTarget.isCleared = true
        state.nodes[target.id] = clearedTarget
        #expect(LabyrinthMapPresentation.state(for: clearedTarget, in: state) == .cleared)
        #expect(
            LabyrinthMapPresentation.connectorState(
                from: source,
                to: clearedTarget,
                selectedNodeID: nil,
                in: state
            ) == .cleared
        )
    }
}
