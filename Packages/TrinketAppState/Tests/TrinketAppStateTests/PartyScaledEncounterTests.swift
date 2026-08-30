import BattleEngine
import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketPersistence
import TrinketTestSupport
@testable import TrinketAppState

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
        state.playerSave.roster = roster
    }

    private func unlockSpireThroughPenultimateFloor(in state: PlaySession) throws -> SpireFloor {
        let spire = try #require(GameContent.spire(id: .ironVein))
        let hero = state.playerSave.roster.activeHero
        let companion = state.playerSave.roster.activeCompanion
        for floor in 1 ..< spire.floorCount {
            let spireFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: floor))
            _ = state.spires.completeFloor(spireFloor, hero: hero, companion: companion)
        }
        return try #require(GameContent.spireFloor(spireID: .ironVein, floor: spire.floorCount))
    }

    @Test func `journey encounter scales down to party ceiling`() throws {
        let state = try context.makePlaySession()
        setPartyLevels(3, 2, in: state)
        let chapter = try #require(GameContent.chapters.last)
        let stage = try #require(chapter.stages.last { $0.encounter.isCombat })
        #expect(EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter) > 5)

        #expect(state.journey.startBattle(for: stage) == nil)
        let configuration = try #require(state.battle.activeBattle)
        #expect(configuration.enemyEncounterLevel == 5)

        let enemyID = try #require(stage.resolvedBattleEnemyID(worldSeed: state.playerSave.worldSeed))
        let catalogEnemy = try #require(GameContent.enemy(matching: enemyID))
        let enemy = try #require(configuration.enemy)
        let expectedStats = CombatantLevelScaler.scale(enemy: catalogEnemy, level: 5)
        #expect(enemy.maxHealth == expectedStats.maxHealth)
    }

    @Test func `journey encounter keeps authored level when party is ahead`() throws {
        let state = try context.makePlaySession()
        setPartyLevels(60, 60, in: state)
        let chapter = try #require(GameContent.chapters.last)
        let stage = try #require(chapter.stages.last { $0.encounter.isCombat })

        #expect(state.journey.startBattle(for: stage) == nil)
        let configuration = try #require(state.battle.activeBattle)
        #expect(
            configuration.enemyEncounterLevel
                == EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter),
        )
    }

    @Test func `spire encounter scales down to party ceiling`() throws {
        let state = try context.makePlaySession()
        let topFloor = try unlockSpireThroughPenultimateFloor(in: state)
        setPartyLevels(3, 2, in: state)
        #expect(EncounterLevelResolver.spireEnemyLevel(for: topFloor) > 5)

        #expect(state.spires.startBattle(for: topFloor) == nil)
        let configuration = try #require(state.battle.activeBattle)
        #expect(configuration.enemyEncounterLevel == 5)

        let catalogEnemy = try #require(GameContent.enemy(matching: topFloor.enemyID))
        let enemy = try #require(configuration.enemy)
        let expectedStats = CombatantLevelScaler.scale(enemy: catalogEnemy, level: 5)
        #expect(enemy.maxHealth == expectedStats.maxHealth)
    }

    @Test func `spire encounter keeps authored level when party is ahead`() throws {
        let state = try context.makePlaySession()
        let topFloor = try unlockSpireThroughPenultimateFloor(in: state)
        setPartyLevels(60, 60, in: state)

        #expect(state.spires.startBattle(for: topFloor) == nil)
        let configuration = try #require(state.battle.activeBattle)
        #expect(
            configuration.enemyEncounterLevel == EncounterLevelResolver.spireEnemyLevel(for: topFloor),
        )
    }

    private func forceDeepCombatNode(in state: PlaySession) throws -> String {
        _ = state.labyrinth.enter()
        let nodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        let node = try #require(state.playerSave.labyrinth.node(id: nodeID))
        let deepened = LabyrinthNode(
            id: node.id,
            type: .battle,
            enemyID: "goblin",
            depth: 20,
            clusterID: node.clusterID,
            gridPosition: node.gridPosition,
            modifierIDs: node.modifierIDs,
            recruitEventID: nil,
            mysteryEventID: nil,
            outgoingIDs: node.outgoingIDs,
            isCleared: false,
            isRevealed: true,
        )
        var labyrinth = state.playerSave.labyrinth
        labyrinth.nodes[nodeID] = deepened
        state.playerSave.labyrinth = labyrinth
        return nodeID
    }

    @Test func `labyrinth encounter scales down to party ceiling`() throws {
        let state = try context.makePlaySession()
        setPartyLevels(3, 2, in: state)
        let nodeID = try forceDeepCombatNode(in: state)

        #expect(state.labyrinth.startBattle(nodeID: nodeID) == nil)
        let configuration = try #require(state.battle.activeBattle)
        #expect(configuration.enemyEncounterLevel == 5)
    }

    @Test func `labyrinth encounter keeps authored level when party is ahead`() throws {
        let state = try context.makePlaySession()
        setPartyLevels(60, 60, in: state)
        let nodeID = try forceDeepCombatNode(in: state)

        #expect(state.labyrinth.startBattle(nodeID: nodeID) == nil)
        let configuration = try #require(state.battle.activeBattle)
        #expect(configuration.enemyEncounterLevel == 20)
    }
}
