import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import TrinketAppState

@MainActor
struct ContractsPlayModeTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func `battle launch and retry use the latest party and progression`() throws {
        let play = try context.makePlaySession()
        #expect(play.contracts.enter() == nil)
        let board = play.playerSave.contracts
        let standard = try #require(board.offer(for: .standard))
        #expect(!play.battle.hasPreparedRun(PlayBattleOrigin.contract(offerID: standard.id).runKey))
        var roster = play.playerSave.roster
        roster.unlockHero(id: "wizard")
        roster.unlockCompanion(id: "frost_whelp")
        let hero = try #require(roster.heroes.first { $0.id == "wizard" })
        let companion = try #require(roster.companions.first { $0.id == "frost_whelp" })
        roster.setActiveHero(hero)
        roster.setActiveCompanion(companion)
        roster.progressions[roster.activeHeroID] = .at(level: 40)
        roster.progressions[roster.activeCompanionID] = .at(level: 1)
        play.playerSave.roster = roster

        #expect(play.contracts.startBattle(offerID: standard.id) == nil)
        let configuration = try #require(play.battle.activeBattle)
        #expect(configuration.hero.combatant.id == hero.id)
        #expect(configuration.companion.combatant.id == companion.id)
        #expect(configuration.hero.progression.level == 40)
        #expect(configuration.companion.progression.level == 1)
        #expect(configuration.enemyEncounterLevel == 20)
        #expect(play.playerSave.contracts == board)
        let presentation = try #require(play.battlePresentation(for: configuration.runKey))
        #expect(presentation.heroExperienceAward == 0)
        #expect(presentation.companionExperienceAward > 0)

        #expect(play.contracts.refresh() != nil)
        #expect(play.contracts.startBattle(offerID: standard.id) != nil)
        #expect(play.playerSave.contracts == board)
        #expect(play.battle.activeBattle?.id == configuration.id)
        play.endBattleReturningToOrigin()
        #expect(play.consumePendingDestination() == .contracts)
        #expect(play.playerSave.contracts == board)
        roster.progressions[roster.activeHeroID] = .at(level: 10)
        roster.progressions[roster.activeCompanionID] = .at(level: 5)
        play.playerSave.roster = roster
        #expect(play.contracts.startBattle(offerID: standard.id) == nil)
        #expect(play.battle.activeBattle?.enemyEncounterLevel == 7)
        #expect(play.battle.activeBattle?.id != configuration.id)
    }

    @Test(arguments: [ContractDifficulty.easy, .standard, .hard])
    func `difficulty resolves only when battle begins`(_ difficulty: ContractDifficulty) throws {
        let play = try context.makePlaySession()
        #expect(play.contracts.enter() == nil)
        #expect(play.contracts.refresh() == nil)
        let board = play.playerSave.contracts
        for offer in board.offers {
            #expect(!play.battle.hasPreparedRun(PlayBattleOrigin.contract(offerID: offer.id).runKey))
        }
        let offer = try #require(board.offer(for: difficulty))
        var roster = play.playerSave.roster
        roster.progressions[roster.activeHeroID] = .at(level: 2)
        roster.progressions[roster.activeCompanionID] = .at(level: 3)
        play.playerSave.roster = roster
        #expect(play.contracts.startBattle(offerID: offer.id) == nil)
        let expectedLevel = switch difficulty {
        case .easy: 1
        case .standard: 2
        case .hard: 5
        }
        #expect(play.battle.activeBattle?.enemyEncounterLevel == expectedLevel)
        #expect(play.playerSave.contracts == board)
    }

    @Test func `victory pays the shown rewards and returns to one replaced offer`() throws {
        let play = try context.makePlaySession()
        #expect(play.contracts.enter() == nil)
        let board = play.playerSave.contracts
        let hard = try #require(board.offer(for: .hard))
        #expect(play.contracts.startBattle(offerID: hard.id) == nil)
        let configuration = try #require(play.battle.activeBattle)
        let presentation = try #require(play.battlePresentation(for: configuration.runKey))
        let pendingItem = try #require(presentation.pendingRewardItem)
        let before = play.playerSave.currentSave

        #expect(play.completeActiveBattle(configuration, battleEarnedGold: 0))
        #expect(play.battle.activeBattle == nil)
        #expect(play.consumePendingDestination() == .contracts)
        #expect(play.playerSave.contracts.offer(for: .hard)?.id != hard.id)
        #expect(play.playerSave.contracts.offer(for: .easy) == board.offer(for: .easy))
        #expect(play.playerSave.contracts.offer(for: .standard) == board.offer(for: .standard))
        #expect(play.playerSave.inventory.item(matching: pendingItem.id) == pendingItem)
        #expect(play.playerSave.roster.progression(for: before.roster.activeHero)
            == before.roster.progression(for: before.roster.activeHero).addingExperience(presentation.heroExperienceAward))
        #expect(play.playerSave.roster.progression(for: before.roster.activeCompanion)
            == before.roster.progression(for: before.roster.activeCompanion).addingExperience(presentation.companionExperienceAward))
        let claimed = play.playerSave.currentSave
        #expect(!play.completeActiveBattle(configuration, battleEarnedGold: 0))
        #expect(play.playerSave.currentSave == claimed)
    }

    #if DEBUG
    @Test func `failed board refresh keeps jobs available for launch`() throws {
        let play = try context.makePlaySession()
        #expect(play.contracts.enter() == nil)
        let before = play.playerSave.currentSave
        play.playerSave.forcesNextSaveFailure = true
        #expect(play.contracts.refresh() != nil)
        #expect(play.playerSave.currentSave == before)
        let easy = try #require(before.contracts.offer(for: .easy))
        #expect(play.contracts.startBattle(offerID: easy.id) == nil)
        #expect(play.battle.activeBattle?.runKey == PlayBattleOrigin.contract(offerID: easy.id).runKey)
    }
    #endif
}
