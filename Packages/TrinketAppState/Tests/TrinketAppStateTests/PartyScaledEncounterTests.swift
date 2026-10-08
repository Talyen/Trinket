import BattleEngine
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import TrinketAppState
@testable import TrinketPersistence

@Suite("PartyScaledEncounters")
@MainActor
struct PartyScaledEncounterTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    private func setPartyLevels(_ heroLevel: Int, _ companionLevel: Int, in state: PlaySession) {
        var roster = state.playerSave.roster
        roster.progressions[roster.activeHeroID] = .at(level: heroLevel)
        roster.progressions[roster.activeCompanionID] = .at(level: companionLevel)
        #expect(state.playerSave.persistBatch(logging: "Test setup") { $0.roster = roster })
    }

    private func unlockSpireThroughPenultimateFloor(in state: PlaySession) throws -> SpireFloor {
        let spire = try #require(GameContent.spire(id: .ironVein))
        #expect(state.playerSave.persistBatch(logging: "Test setup: unlock Spire floor") {
            $0.spires.highestClearedFloorBySpireID[spire.id.rawValue] = spire.floorCount - 1
        })
        return try #require(GameContent.spireFloor(spireID: .ironVein, floor: spire.floorCount))
    }

    @Test func `journey encounter preserves the content floor across party changes`() throws {
        let state = try context.makePlaySession()
        let chapter = try #require(GameContent.chapters.last)
        let stage = try #require(chapter.stages.last { $0.encounter.isCombat })
        let authoredLevel = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        let enemyID = try #require(stage.resolvedBattleEnemyID(worldSeed: state.playerSave.worldSeed))
        let catalogEnemy = try #require(GameContent.enemy(matching: enemyID))
        for (heroLevel, companionLevel, expectedLevel) in [(3, 2, authoredLevel - 3), (60, 60, authoredLevel)] {
            setPartyLevels(heroLevel, companionLevel, in: state)
            #expect(state.journey.startBattle(for: stage) == nil)
            let configuration = try #require(state.battle.activeBattle)
            #expect(configuration.enemyEncounterLevel == expectedLevel)
            let enemy = try #require(configuration.enemy)
            #expect(enemy.maxHealth == CombatantLevelScaler.scale(enemy: catalogEnemy, level: expectedLevel).maxHealth)
            state.battle.endBattle()
        }
    }

    @Test func `spire encounter preserves fixed floor level`() throws {
        let state = try context.makePlaySession()
        let topFloor = try unlockSpireThroughPenultimateFloor(in: state)
        let expectedLevel = topFloor.floor * 2
        let catalogEnemy = try #require(GameContent.enemy(matching: topFloor.enemyID))
        for (heroLevel, companionLevel) in [(3, 2), (60, 60)] {
            setPartyLevels(heroLevel, companionLevel, in: state)
            #expect(state.spires.startBattle(for: topFloor) == nil)
            let configuration = try #require(state.battle.activeBattle)
            #expect(configuration.enemyEncounterLevel == expectedLevel)
            let enemy = try #require(configuration.enemy)
            #expect(enemy.maxHealth == CombatantLevelScaler.scale(enemy: catalogEnemy, level: expectedLevel).maxHealth)
            state.battle.endBattle()
        }
    }

    private func forceDeepCombatNode(in state: PlaySession) throws -> String {
        _ = state.labyrinth.enter()
        let nodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        let node = try #require(state.playerSave.labyrinth.node(id: nodeID))
        return LabyrinthTestSupport.store(
            LabyrinthTestSupport.remade(
                node,
                type: .battle,
                recruitEventID: nil,
                enemyID: "goblin",
                depth: 20,
                isCleared: false,
                isRevealed: true,
            ),
            in: state,
        )
    }

    @Test func `labyrinth encounter preserves depth band floor`() throws {
        let state = try context.makePlaySession()
        let nodeID = try forceDeepCombatNode(in: state)
        for (heroLevel, companionLevel, expectedLevel) in [(3, 2, 16), (60, 60, 20)] {
            setPartyLevels(heroLevel, companionLevel, in: state)
            #expect(state.labyrinth.startBattle(nodeID: nodeID) == nil)
            let configuration = try #require(state.battle.activeBattle)
            #expect(configuration.enemyEncounterLevel == expectedLevel)
            state.battle.endBattle()
        }
    }
}
