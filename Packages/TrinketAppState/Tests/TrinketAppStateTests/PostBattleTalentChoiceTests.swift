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

    @Test(arguments: [false, true])
    func `victory queues only combatant who earned talent point`(defersExit: Bool) throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.playerSave.roster.activeHero
        let companion = state.playerSave.roster.activeCompanion
        try state.playerSave.performBatchMutation { save in
            save.roster.progressions[hero.id] = CombatantProgression(
                level: 1,
                currentXP: 9,
                requiredXP: 10,
            )
            save.roster.progressions[companion.id] = .initial
        }
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleGold: .init(gained: 0), defersPresentationExit: defersExit).didComplete)
        if defersExit {
            #expect(state.currentPostBattleTalentCombatantID == nil)
            #expect(state.playerSave.roster.progression(for: hero).level == 2)
            state.finishBattleRewardPresentation(configurationID: configuration.id)
        }
        #expect(state.battle.activeBattle == nil)
        #expect(state.currentPostBattleTalentCombatantID == hero.id)

        let tree = try #require(CombatantTalentCatalog.allConfigs[hero.id]?.trees.first)
        let node = try #require(tree.nodes.first)
        #expect(state.choosePostBattleTalent(nodeID: "missing", treeID: tree.id) == .unavailable)
        #expect(state.currentPostBattleTalentCombatantID == hero.id)
        #if DEBUG
        state.playerSave.forcesNextSaveFailure = true
        #expect(state.choosePostBattleTalent(nodeID: node.id, treeID: tree.id) == .persistenceFailed)
        #expect(state.postBattleTalentConfirmationID == nil)
        #expect(state.playerSave.roster.unlockedTalents(for: hero.id).isEmpty)
        #endif
        #expect(state.choosePostBattleTalent(nodeID: node.id, treeID: tree.id) == .unlocked)
        #expect(state.playerSave.roster.unlockedTalents(for: hero.id) == [node.id])
        #expect(state.currentPostBattleTalentCombatantID == hero.id)
        #expect(state.isGameplayActive)
        let confirmation = try #require(state.postBattleTalentConfirmationID)
        state.finishPostBattleTalentConfirmation(id: confirmation)
        #expect(state.currentPostBattleTalentCombatantID == nil)
        #expect(!state.isGameplayActive)
    }

    @Test func `victory queues hero then companion when both earn talent point`() throws {
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

        #expect(state.completeActiveBattle(configuration, battleGold: .init(gained: 0)).didComplete)
        #expect(state.currentPostBattleTalentCombatantID == hero.id)

        let tree = try #require(CombatantTalentCatalog.allConfigs[hero.id]?.trees.first)
        let node = try #require(tree.nodes.first)
        #expect(state.choosePostBattleTalent(nodeID: node.id, treeID: tree.id) == .unlocked)
        #expect(state.currentPostBattleTalentCombatantID == hero.id)
        let confirmation = try #require(state.postBattleTalentConfirmationID)
        state.finishPostBattleTalentConfirmation(id: confirmation)
        #expect(state.currentPostBattleTalentCombatantID == companion.id)

        state.dismissPostBattleTalentChoice()
        state.finishPostBattleTalentConfirmation(id: confirmation)
        #expect(state.currentPostBattleTalentCombatantID == nil)
        #expect(state.playerSave.roster.unlockedTalents(for: companion.id).isEmpty)
    }

    @Test func `victory allows allocating multiple talent points`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.playerSave.roster.activeHero
        try state.playerSave.performBatchMutation { save in
            let requiredLevel3 = CombatantProgression.requiredXP(forLevel: 3)
            save.roster.progressions[hero.id] = CombatantProgression(level: 3, currentXP: requiredLevel3 - 1, requiredXP: requiredLevel3)
        }
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleGold: .init(gained: 0)).didComplete)
        #expect(state.playerSave.roster.progression(for: hero).level >= 4)
        #expect(state.playerSave.roster.availableTalentPoints(for: hero.id) == 2)
        #expect(state.currentPostBattleTalentCombatantID == hero.id)

        let tree = try #require(CombatantTalentCatalog.allConfigs[hero.id]?.trees.first)
        let row1Nodes = tree.nodes(forRow: 1)
        try #require(row1Nodes.count >= 2)
        let firstNode = row1Nodes[0]
        let secondNode = row1Nodes[1]

        #expect(state.choosePostBattleTalent(nodeID: firstNode.id, treeID: tree.id) == .unlocked)
        #expect(state.currentPostBattleTalentCombatantID == hero.id)
        #expect(state.playerSave.roster.availableTalentPoints(for: hero.id) == 1)

        let firstConfirmation = try #require(state.postBattleTalentConfirmationID)
        #expect(state.choosePostBattleTalent(nodeID: secondNode.id, treeID: tree.id) == .unlocked)
        let lastConfirmation = try #require(state.postBattleTalentConfirmationID)
        #expect(firstConfirmation != lastConfirmation)
        #expect(state.playerSave.roster.availableTalentPoints(for: hero.id) == 0)
        state.finishPostBattleTalentConfirmation(id: firstConfirmation)
        #expect(state.currentPostBattleTalentCombatantID == hero.id)
        #expect(state.postBattleTalentConfirmationID == lastConfirmation)
        #expect(state.choosePostBattleTalent(nodeID: secondNode.id, treeID: tree.id) == .unavailable)
        state.finishPostBattleTalentConfirmation(id: lastConfirmation)
        #expect(state.currentPostBattleTalentCombatantID == nil)
    }

    @Test func `victory does not queue old unspent talent point`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.playerSave.roster.activeHero
        try state.playerSave.performBatchMutation { save in
            save.roster.progressions[hero.id] = .at(level: 2)
        }
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleGold: .init(gained: 0)).didComplete)
        #expect(state.playerSave.roster.availableTalentPoints(for: hero.id) == 1)
        #expect(state.currentPostBattleTalentCombatantID == nil)
    }

    #if DEBUG
    @Test func `failed battle save does not queue talent choice`() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(playerSave: playerSave)
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.playerSave.roster.activeHero
        try playerSave.performBatchMutation { save in
            save.roster.progressions[hero.id] = CombatantProgression(
                level: 1,
                currentXP: 9,
                requiredXP: 10,
            )
        }
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        playerSave.forcesNextSaveFailure = true

        #expect(!state.completeActiveBattle(configuration, battleGold: .init(gained: 0)).didComplete)
        #expect(state.currentPostBattleTalentCombatantID == nil)
    }
    #endif

    @Test func `spent talent points prune post battle talent choice`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.playerSave.roster.activeHero
        try state.playerSave.performBatchMutation { save in
            save.roster.progressions[hero.id] = CombatantProgression(
                level: 1,
                currentXP: 9,
                requiredXP: 10,
            )
        }
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleGold: .init(gained: 0)).didComplete)
        #expect(state.currentPostBattleTalentCombatantID == hero.id)
        #expect(state.isGameplayActive)

        let tree = try #require(CombatantTalentCatalog.allConfigs[hero.id]?.trees.first)
        let node = try #require(tree.nodes.first)
        #expect(state.playerSave.unlockTalent(nodeID: node.id, treeID: tree.id, for: hero.id) == .unlocked)

        #expect(state.currentPostBattleTalentCombatantID == nil)
        #expect(!state.isGameplayActive)
    }
}
