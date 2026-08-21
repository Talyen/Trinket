import Testing
import TrinketContent
import TrinketFeatureAdapters
import TrinketPersistence
@testable import TrinketFeatureSupport

struct StageMapPresentationTests {
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

        #expect(recruit.encounterCombatantArtReference(worldSeed: 0) == nil)
        #expect(recruit.encounterArtReference != nil)
        #expect(bosses.count == 1)
    }

    @Test func battleStagesPreferEnemyArtOverEncounterArt() throws {
        let stage = try #require(GameContent.chapters[0].stages.first { $0.id == "chapter-1-stage-1" })

        #expect(GameContent.encounterArtID(for: stage) == nil)
        #expect(stage.encounterArtReference == nil)
        _ = try #require(stage.encounterCombatantArtReference(worldSeed: 0))
        #expect(stage.encounterSubjectName(worldSeed: 0) == "Slime")
    }

    @Test func randomBattleSubjectNameDependsOnWorldSeed() throws {
        let stage = try #require(
            GameContent.chapters.flatMap(\.stages).first { $0.encounter == .randomBattle }
        )
        let names = (1 ... 16).map { stage.encounterSubjectName(worldSeed: UInt64($0)) }
        #expect(Set(names).count > 1)
        #expect(!names.contains("Battle"))
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
        #expect(stage.encounterSubjectName(worldSeed: 0) == "Merchant")
    }

    @Test func mappedEventStagesResolveEncounterArtWithoutPinningCatalogIDs() throws {
        let stage = try #require(GameContent.chapters[1].stages.first { $0.id == "chapter-2-stage-8" })

        #expect(GameContent.encounterArtID(for: stage) != nil)
        _ = try #require(stage.encounterArtReference)
        #expect(!(stage.encounterSubjectName(worldSeed: 0).isEmpty))
    }

    @Test func seededJourneyMysteryProvidesEncounterArtForUnpinnedStages() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
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

    @Test func spiresHubOrdersByClearedFloorsThenUnlockThenCatalog() {
        let progress = PlayerSpiresState(highestClearedFloorBySpireID: [
            SpireID.ironVein.rawValue: 3,
            SpireID.cinderSpire.rawValue: 3,
            SpireID.serpentHollow.rawValue: 10,
            SpireID.aureateChoir.rawValue: 10,
        ])
        let unlocked: Set<SpireID> = [.cinderSpire, .sanguineCourt, .aureateChoir]
        let ordered = GameContent.spires.orderedForSpiresHub(progress: progress) {
            unlocked.contains($0.id)
        }

        #expect(ordered.map(\.id) == [
            .aureateChoir,
            .serpentHollow,
            .cinderSpire,
            .ironVein,
            .sanguineCourt,
            .rimeVault,
            .resonanceHall,
        ])
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

    @Test func labyrinthEffectiveTypeKeepsNonRecruitNodes() {
        let node = LabyrinthNode(id: "battle", type: .battle, depth: 1, clusterID: "floor")
        #expect(
            LabyrinthMapPresentation.effectiveType(
                for: node,
                worldSeed: 1,
                unlockedHeroIDs: [],
                unlockedCompanionIDs: []
            ) == .battle
        )
    }

    @Test func labyrinthEffectiveTypeFallsBackToMysteryWhenNoRecruitsRemain() {
        let node = LabyrinthNode(id: "recruit", type: .recruit, depth: 1, clusterID: "floor")
        #expect(
            LabyrinthMapPresentation.effectiveType(
                for: node,
                worldSeed: 1,
                unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
                unlockedCompanionIDs: Set(GameContent.companions.map(\.id))
            ) == .mystery
        )
    }

    @Test func labyrinthEffectiveTypeKeepsAConfiguredEligibleRecruit() throws {
        let event = GameContent.recruitEvents.first { $0.unlockCombatantID != nil }
        let recruitEvent = try #require(event)
        let node = LabyrinthNode(
            id: "recruit-configured",
            type: .recruit,
            depth: 1,
            clusterID: "floor",
            recruitEventID: recruitEvent.id
        )
        let lockedID = recruitEvent.unlockCombatantID
        let unlockedHeroIDs = Set(GameContent.heroes.map(\.id)).subtracting(lockedID.map { [$0] } ?? [])
        let unlockedCompanionIDs = Set(GameContent.companions.map(\.id)).subtracting(
            lockedID.map { [$0] } ?? []
        )
        #expect(
            LabyrinthMapPresentation.effectiveType(
                for: node,
                worldSeed: 1,
                unlockedHeroIDs: unlockedHeroIDs,
                unlockedCompanionIDs: unlockedCompanionIDs
            ) == .recruit
        )
    }

    @Test func labyrinthRecruitEncounterArtUsesSeededHeroOrCompanionScene() throws {
        let heroEvent = try #require(
            GameContent.recruitEvents.first { event in
                guard let combatant = GameContent.combatant(forMysteryEvent: event) else { return false }
                return combatant.role == .hero
            }
        )
        let companionEvent = try #require(
            GameContent.recruitEvents.first { event in
                guard let combatant = GameContent.combatant(forMysteryEvent: event) else { return false }
                return combatant.role == .companion
            }
        )
        let heroNode = LabyrinthNode(
            id: "recruit-hero",
            type: .recruit,
            depth: 1,
            clusterID: "floor",
            recruitEventID: heroEvent.id
        )
        let companionNode = LabyrinthNode(
            id: "recruit-companion",
            type: .recruit,
            depth: 1,
            clusterID: "floor",
            recruitEventID: companionEvent.id
        )
        let lockedHeroID = heroEvent.unlockCombatantID
        let lockedCompanionID = companionEvent.unlockCombatantID
        let heroUnlocks = (
            Set(GameContent.heroes.map(\.id)).subtracting(lockedHeroID.map { [$0] } ?? []),
            Set(GameContent.companions.map(\.id))
        )
        let companionUnlocks = (
            Set(GameContent.heroes.map(\.id)),
            Set(GameContent.companions.map(\.id)).subtracting(lockedCompanionID.map { [$0] } ?? [])
        )

        let heroArt = try #require(
            LabyrinthMapPresentation.recruitEncounterArtReference(
                for: heroNode,
                worldSeed: 1,
                unlockedHeroIDs: heroUnlocks.0,
                unlockedCompanionIDs: heroUnlocks.1
            )
        )
        let companionArt = try #require(
            LabyrinthMapPresentation.recruitEncounterArtReference(
                for: companionNode,
                worldSeed: 1,
                unlockedHeroIDs: companionUnlocks.0,
                unlockedCompanionIDs: companionUnlocks.1
            )
        )

        #expect(heroArt.imageName == "encounter_mystery_recruit_heroes")
        #expect(companionArt.imageName == "encounter_mystery_recruit_companions")
    }

    @Test func labyrinthRecruitEncounterArtIsNilWhenPoolFallsBackToMystery() {
        let node = LabyrinthNode(id: "recruit", type: .recruit, depth: 1, clusterID: "floor")
        #expect(
            LabyrinthMapPresentation.recruitEncounterArtReference(
                for: node,
                worldSeed: 1,
                unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
                unlockedCompanionIDs: Set(GameContent.companions.map(\.id))
            ) == nil
        )
    }
}
