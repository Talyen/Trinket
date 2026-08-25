import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketAppState
@testable import TrinketPersistence

@MainActor
struct PostBattleTalentChoiceTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func victoryQueuesOnlyCombatantWhoEarnedTalentPoint() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.playerSave.roster.activeHero
        let companion = state.playerSave.roster.activeCompanion
        try state.playerSave.performBatchMutation { save in
            save.roster.progressions[hero.id] = CombatantProgression(
                level: 1,
                currentXP: 9,
                requiredXP: 10
            )
            save.roster.progressions[companion.id] = .initial
        }
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleEarnedGold: 0))
        #expect(state.currentPostBattleTalentCombatantID == hero.id)

        let tree = try #require(CombatantTalentCatalog.allConfigs[hero.id]?.trees.first)
        let node = try #require(tree.nodes.first)
        #expect(state.choosePostBattleTalent(nodeID: "missing", treeID: tree.id) == .unavailable)
        #expect(state.currentPostBattleTalentCombatantID == hero.id)
        #expect(state.choosePostBattleTalent(nodeID: node.id, treeID: tree.id) == .unlocked)
        #expect(state.currentPostBattleTalentCombatantID == nil)
        #expect(state.playerSave.roster.unlockedTalents(for: hero.id) == [node.id])
    }

    @Test func victoryQueuesHeroThenCompanionWhenBothEarnTalentPoint() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.playerSave.roster.activeHero
        let companion = state.playerSave.roster.activeCompanion
        try state.playerSave.performBatchMutation { save in
            let nearLevelTwo = CombatantProgression(level: 1, currentXP: 9, requiredXP: 10)
            save.roster.progressions[hero.id] = nearLevelTwo
            save.roster.progressions[companion.id] = nearLevelTwo
        }
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleEarnedGold: 0))
        #expect(state.currentPostBattleTalentCombatantID == hero.id)

        let tree = try #require(CombatantTalentCatalog.allConfigs[hero.id]?.trees.first)
        let node = try #require(tree.nodes.first)
        #expect(state.choosePostBattleTalent(nodeID: node.id, treeID: tree.id) == .unlocked)
        #expect(state.currentPostBattleTalentCombatantID == companion.id)

        state.dismissPostBattleTalentChoice()
        #expect(state.currentPostBattleTalentCombatantID == nil)
        #expect(state.playerSave.roster.unlockedTalents(for: companion.id).isEmpty)
    }

    @Test func victoryAllowsAllocatingMultipleTalentPoints() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.playerSave.roster.activeHero
        // Hero at level 3 with XP near level 4 and 0 talents spent (so leveling to 4 yields 2 available talent points)
        try state.playerSave.performBatchMutation { save in
            let requiredLevel3 = CombatantProgression.requiredXP(forLevel: 3)
            save.roster.progressions[hero.id] = CombatantProgression(level: 3, currentXP: requiredLevel3 - 1, requiredXP: requiredLevel3)
        }
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleEarnedGold: 0))
        #expect(state.playerSave.roster.progression(for: hero).level >= 4)
        #expect(state.playerSave.roster.availableTalentPoints(for: hero.id) == 2)
        #expect(state.currentPostBattleTalentCombatantID == hero.id)

        let tree = try #require(CombatantTalentCatalog.allConfigs[hero.id]?.trees.first)
        let row1Nodes = tree.nodes(forRow: 1)
        try #require(row1Nodes.count >= 2)
        let firstNode = row1Nodes[0]
        let secondNode = row1Nodes[1]

        #expect(state.choosePostBattleTalent(nodeID: firstNode.id, treeID: tree.id) == .unlocked)
        // 1 talent point still remains — hero should stay active in the post-battle queue
        #expect(state.currentPostBattleTalentCombatantID == hero.id)
        #expect(state.playerSave.roster.availableTalentPoints(for: hero.id) == 1)

        #expect(state.choosePostBattleTalent(nodeID: secondNode.id, treeID: tree.id) == .unlocked)
        // All talent points spent — hero is now cleared from the queue
        #expect(state.currentPostBattleTalentCombatantID == nil)
        #expect(state.playerSave.roster.availableTalentPoints(for: hero.id) == 0)
    }

    @Test func victoryDoesNotQueueOldUnspentTalentPoint() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.playerSave.roster.activeHero
        try state.playerSave.performBatchMutation { save in
            save.roster.progressions[hero.id] = .at(level: 2)
        }
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleEarnedGold: 0))
        #expect(state.playerSave.roster.availableTalentPoints(for: hero.id) == 1)
        #expect(state.currentPostBattleTalentCombatantID == nil)
    }

    #if DEBUG
    @Test func failedBattleSaveDoesNotQueueTalentChoice() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(playerSave: playerSave)
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.playerSave.roster.activeHero
        try playerSave.performBatchMutation { save in
            save.roster.progressions[hero.id] = CombatantProgression(
                level: 1,
                currentXP: 9,
                requiredXP: 10
            )
        }
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        playerSave.forcesNextSaveFailure = true

        #expect(!state.completeActiveBattle(configuration, battleEarnedGold: 0))
        #expect(state.currentPostBattleTalentCombatantID == nil)
    }
    #endif
}
