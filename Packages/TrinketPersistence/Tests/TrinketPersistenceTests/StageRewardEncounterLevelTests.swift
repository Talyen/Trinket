import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct StageRewardEncounterLevelTests {
    enum ClaimFallbackMode: String {
        case journey
        case spire
    }

    @Test(arguments: [ClaimFallbackMode.journey, .spire])
    func `claim fallback uses party adjusted encounter level`(mode: ClaimFallbackMode) throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })

        var pinned = SaveTestSupport.makeSave()
        pinned.roster.progressions[hero.id] = .at(level: 3)
        pinned.roster.progressions[companion.id] = .at(level: 2)
        let level = try expectedClaimLevel(mode: mode, in: pinned)
        try completeForClaimFallback(
            mode: mode,
            hero: hero,
            companion: companion,
            save: &pinned,
            enemyEncounterLevel: level,
        )
        let pinnedXP = pinned.roster.progression(for: hero).currentXP

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

        try assertClaimModeExpectations(mode: mode, level: level)
        #expect(fallback.roster.progression(for: hero).currentXP == pinnedXP)
    }

    @Test func `combat loot resolves at provided encounter level instead of node depth`() throws {
        let node = LabyrinthNode(
            id: "level-override-node",
            type: .battle,
            enemyID: "goblin",
            depth: 2,
            clusterID: "labyrinth-test",
        )
        let atDepth = try #require(
            LabyrinthCompletion.resolveCombatLoot(
                for: node,
                effects: .zero,
                worldSeed: 5,
                ownedTrinketIDs: [],
                ownedUniqueIDs: [],
            ),
        )
        let explicit = try #require(
            LabyrinthCompletion.resolveCombatLoot(
                for: node,
                effects: .zero,
                encounterLevel: 2,
                worldSeed: 5,
                ownedTrinketIDs: [],
                ownedUniqueIDs: [],
            ),
        )
        #expect(explicit.gold == atDepth.gold)
        #expect(explicit.materials == atDepth.materials)

        let raised = try #require(
            LabyrinthCompletion.resolveCombatLoot(
                for: node,
                effects: .zero,
                encounterLevel: 40,
                worldSeed: 5,
                ownedTrinketIDs: [],
                ownedUniqueIDs: [],
            ),
        )
        for (boosted, base) in zip(raised.materials, atDepth.materials) {
            #expect(boosted.resource == base.resource)
            #expect(boosted.quantity > base.quantity)
        }
        #expect(raised.gold > atDepth.gold)
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
                enemyEncounterLevel: enemyEncounterLevel,
                save: &save,
            )
            return save.roster.progression(for: hero).currentXP - before.currentXP
        }

        let authored = grantedHeroXP(enemyEncounterLevel: 20)
        let scaled = grantedHeroXP(enemyEncounterLevel: 13)

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
                enemyEncounterLevel: enemyEncounterLevel,
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
                enemyEncounterLevel: enemyEncounterLevel,
                save: &save,
            )
        }
    }

    private func expectedClaimLevel(mode: ClaimFallbackMode, in save: PlayerSave) throws -> Int {
        switch mode {
        case .journey:
            let deepStage = try deepJourneyStage()
            return StageCompletion.partyAdjustedEncounterLevel(for: deepStage, save: save)
        case .spire:
            let topFloor = try ironVeinTopFloor()
            return EncounterLevelResolver.partyAdjusted(
                EncounterLevelResolver.spireEnemyLevel(for: topFloor),
                partyAverageLevel: save.roster.activePartyAverageLevel,
            )
        }
    }

    private func assertClaimModeExpectations(mode: ClaimFallbackMode, level: Int) throws {
        switch mode {
        case .journey:
            #expect(level == 5)
        case .spire:
            let topFloor = try ironVeinTopFloor()
            #expect(level < EncounterLevelResolver.spireEnemyLevel(for: topFloor))
        }
    }

    private func deepJourneyStage() throws -> Stage {
        try #require(
            GameContent.chapters.flatMap(\.stages).last(where: {
                $0.encounter.isCombat
                    && StageCompletion.resolvedEncounterLevel(for: $0, in: GameContent.chapters) > 5
            }),
        )
    }

    private func ironVeinTopFloor() throws -> SpireFloor {
        let spire = try #require(GameContent.spire(id: .ironVein))
        return try #require(GameContent.spireFloor(spireID: .ironVein, floor: spire.floorCount))
    }
}
