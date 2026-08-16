import CoreGraphics
import Testing
import TrinketContent
import TrinketFeatureAdapters
import TrinketPersistence
@testable import TrinketFeatureSupport

struct StageMapPresentationTests {
    @Test func stageMapIdentifiersAndLabelsMatchAuthoredContent() throws {
        let chapter = GameContent.chapters[0]
        let stage = try #require(chapter.stages.first)

        #expect(stage.mapLabel == "Stage \(stage.chapterNumber)-\(stage.stageNumber)")
        #expect(stage.mapMetaLabel == "\(stage.mapLabel) · \(stage.encounterTypeTitle)")
        #expect(StageMapID.stageAction(for: stage) == "Stage \(stage.chapterNumber)-\(stage.stageNumber) Action")
    }

    @Test func stageSelectRowsOmitCompletedStages() {
        let chapter = GameContent.chapters[0]
        var progress = JourneyProgressState.initial
        progress.complete(chapter.stages[0], in: GameContent.chapters)

        let rows = StageSelectRowPresentation<Stage>.stageRows(
            for: chapter,
            progress: progress,
            worldSeed: 1
        )

        #expect(!(rows.map(\.item.id).contains(chapter.stages[0].id)))
        #expect(rows.contains { $0.item.id == progress.activeStageID && $0.isActive })
    }

    @Test func bossAndRecruitmentPresentationAreDerivedFromLiveContent() {
        let chapter = GameContent.chapters[0]
        let recruit = chapter.stages[1]
        let bosses = chapter.stages.filter(\.isBossEncounter)

        #expect(recruit.encounterSubjectName == "Mystery")
        #expect(recruit.encounterTypeTitle == "Recruit")
        #expect(recruit.encounterCombatantArtReference == nil)
        #expect(recruit.encounterArtReference != nil)
        #expect(abs(recruit.encounter.artAspectRatio - (4.0 / 3.0)) < 0.000_1)
        #expect(bosses.count == 1)
        #expect(bosses[0].encounterTypeTitle == "Boss")
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

    @Test func seededJourneyMysteryProvidesEncounterArtForUnpinnedStages() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-5"))
        #expect(stage.encounter.mysteryEventID == nil)
        #expect(stage.encounterArtReference == nil)

        let event = GameContent.resolveJourneyMysteryEvent(
            stage: stage,
            worldSeed: 1,
            context: .excludingCorruptionAltar
        )
        #expect(!event.isRecruit)
        if let artID = event.artID {
            #expect(
                ArtCatalog.encounterArtByID[artID] != nil
                    || ArtCatalog.backgroundArtByID[artID] != nil
            )
        }
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

    @Test func labyrinthHexRadiusFillsThreeColumnsAcrossAvailableWidth() {
        let availableWidth: CGFloat = 350
        let radius = LabyrinthMapPresentation.hexRadius(forAvailableWidth: availableWidth)
        let hexWidth = radius * CGFloat(3).squareRoot()
        let outerSpan = hexWidth * CGFloat(LabyrinthMapLayout.fullColumnsAcross)
        #expect(abs(outerSpan - availableWidth) < 0.001)
        #expect(LabyrinthMapPresentation.destinationEncounterArtID(for: .shop) == "destination-merchant-shop")
        #expect(LabyrinthMapPresentation.destinationEncounterArtID(for: .rest) == "destination-campfire")
        #expect(LabyrinthMapPresentation.destinationEncounterArtID(for: .craft) == nil)
        #expect(ArtCatalog.encounterArtByID["destination-merchant-shop"] != nil)
        #expect(ArtCatalog.encounterArtByID["destination-campfire"] != nil)
    }
}
