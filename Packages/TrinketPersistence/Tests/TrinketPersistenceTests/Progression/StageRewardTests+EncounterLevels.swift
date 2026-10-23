import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

extension StageRewardTests {
    enum ClaimFallbackMode: String {
        case journey
        case spire
    }

    @Test(arguments: [ClaimFallbackMode.journey, .spire])
    func `claim fallback uses mode encounter level`(mode: ClaimFallbackMode) throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })

        var pinned = SaveTestSupport.makeSave()
        pinned.roster.progressions[hero.id] = .at(level: 3)
        pinned.roster.progressions[companion.id] = .at(level: 2)
        let level = try expectedClaimLevel(mode: mode)
        try completeForClaimFallback(
            mode: mode,
            hero: hero,
            companion: companion,
            save: &pinned,
            enemyEncounterLevel: level,
        )
        let pinnedXP = pinned.roster.progression(for: hero)
        let pinnedGold = pinned.roster.gold

        var fallback = SaveTestSupport.makeSave()
        fallback.roster.progressions[hero.id] = .at(level: 3)
        fallback.roster.progressions[companion.id] = .at(level: 2)
        try completeForClaimFallback(
            mode: mode,
            hero: hero,
            companion: companion,
            save: &fallback,
            enemyEncounterLevel: nil,
        )

        #expect(fallback.roster.progression(for: hero) == pinnedXP)
        #expect(fallback.roster.gold == pinnedGold)
        #expect(fallback.contracts.highestWonEncounterLevel == level)
    }

    @Test func `duplicate stage completion grants nothing further`() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let stage = try deepJourneyStage()
        var save = SaveTestSupport.makeSave()

        let first = StageCompletion.complete(
            stage,
            hero: hero,
            companion: companion,
            rewards: .unsettled(.init(battleGold: .init(gained: 5))),
            in: GameContent.chapters,
            save: &save,
        )
        #expect(first == .completed)
        let goldAfterFirst = save.roster.gold

        let second = StageCompletion.complete(
            stage,
            hero: hero,
            companion: companion,
            rewards: .unsettled(.init(battleGold: .init(gained: 5))),
            in: GameContent.chapters,
            save: &save,
        )
        #expect(second == .alreadyCompleted)
        #expect(save.roster.gold == goldAfterFirst)
    }

    @Test func `combat completion honors overridden encounter level for experience`() {
        func grantedHeroXP(enemyEncounterLevel: Int?) -> Int {
            var save = PlayerSave.fresh
            save.labyrinth.ensureMap(seed: 31)
            let deepID = "labyrinth-scaling-battle"
            save.labyrinth.nodes[deepID] = LabyrinthNode(
                id: deepID,
                type: .battle,
                enemyID: "goblin",
                depth: 20,
                clusterID: "labyrinth-test",
                isRevealed: true,
            )
            let hero = save.roster.activeHero
            save.roster.progressions[hero.id] = CombatantProgression(level: 20, currentXP: 0, requiredXP: 500)
            let before = save.roster.progression(for: hero)
            LabyrinthCompletion.complete(
                nodeID: deepID,
                hero: hero,
                companion: save.roster.activeCompanion,
                rewards: .unsettled(.init(enemyEncounterLevel: enemyEncounterLevel)),
                save: &save,
            )
            return save.roster.progression(for: hero).currentXP - before.currentXP
        }

        let authored = grantedHeroXP(enemyEncounterLevel: 20)
        let scaled = grantedHeroXP(enemyEncounterLevel: 16)
        let fallback = grantedHeroXP(enemyEncounterLevel: nil)
        #expect(fallback == scaled)

        #expect(authored > 0)
        #expect(scaled > 0)
        #expect(scaled < authored)
    }

    private func completeForClaimFallback(
        mode: ClaimFallbackMode,
        hero: Combatant,
        companion: Combatant,
        save: inout PlayerSave,
        enemyEncounterLevel: Int?,
    ) throws {
        switch mode {
        case .journey:
            let deepStage = try deepJourneyStage()
            StageCompletion.complete(
                deepStage,
                hero: hero,
                companion: companion,
                rewards: .unsettled(.init(enemyEncounterLevel: enemyEncounterLevel)),
                in: GameContent.chapters,
                save: &save,
            )
        case .spire:
            let spire = try #require(GameContent.spire(id: .ironVein))
            let topFloor = try #require(
                GameContent.spireFloor(spireID: .ironVein, floor: spire.floorCount),
            )
            for floor in 1 ..< spire.floorCount {
                _ = save.spires.markFloorCleared(floor, spireID: SpireID.ironVein.rawValue)
            }
            SpireCompletion.complete(
                floor: topFloor,
                hero: hero,
                companion: companion,
                rewards: .unsettled(.init(enemyEncounterLevel: enemyEncounterLevel)),
                save: &save,
            )
        }
    }

    private func expectedClaimLevel(mode: ClaimFallbackMode) throws -> Int {
        switch mode {
        case .journey:
            let deepStage = try deepJourneyStage()
            return EncounterLevelResolver.journeyEnemyLevel(for: deepStage, in: GameContent.chapters) - 3
        case .spire:
            let topFloor = try ironVeinTopFloor()
            return topFloor.floor * 2
        }
    }

    private func deepJourneyStage() throws -> Stage {
        try #require(
            GameContent.chapters.flatMap(\.stages).last(where: {
                $0.encounter.isCombat
                    && EncounterLevelResolver.journeyEnemyLevel(for: $0, in: GameContent.chapters) > 5
            }),
        )
    }

    private func ironVeinTopFloor() throws -> SpireFloor {
        let spire = try #require(GameContent.spire(id: .ironVein))
        return try #require(GameContent.spireFloor(spireID: .ironVein, floor: spire.floorCount))
    }
}
