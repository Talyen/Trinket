import BattleEngine
import Testing
import TrinketContent
@testable import TrinketAppState
@testable import TrinketPersistence

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
        #expect(!(play.battleCoordinator.preparedRuns[PlayBattleOrigin.contract(offerID: standard.id).runKey] != nil))
        var roster = play.playerSave.roster
        roster.unlockHero(id: "wizard")
        roster.unlockCompanion(id: "frost_whelp")
        let hero = try #require(roster.heroes.first { $0.id == "wizard" })
        let companion = try #require(roster.companions.first { $0.id == "frost_whelp" })
        roster.setActiveHero(hero)
        roster.setActiveCompanion(companion)
        roster.progressions[roster.activeHeroID] = .at(level: 40)
        roster.progressions[roster.activeCompanionID] = .at(level: 1)
        #expect(play.playerSave.persistFixtureBatch(logging: "Test setup") { $0.roster = roster })

        #expect(play.contracts.startBattle(offerID: standard.id) == nil)
        let configuration = try #require(play.battle.activeBattle)
        #expect(configuration.hero.combatant.id == hero.id)
        #expect(configuration.companion.combatant.id == companion.id)
        #expect(configuration.hero.progression.level == 40)
        #expect(configuration.companion.progression.level == 1)
        #expect(configuration.enemyEncounterLevel == 20)
        #expect(play.playerSave.contracts == board)
        let presentation = try #require(play.battlePresentation(for: configuration.runKey))
        #expect(presentation.rewardPlan.heroExperience == 0)
        #expect(presentation.rewardPlan.companionExperience > 0)

        #expect(play.contracts.refresh() != nil)
        #expect(play.contracts.startBattle(offerID: standard.id) != nil)
        #expect(play.contracts.startBattle(offerID: "missing-offer")?.title == PlayBattleCoordinator.activationFailureMessage.title)
        #expect(play.playerSave.contracts == board)
        #expect(play.battle.activeBattle?.id == configuration.id)
        play.endBattleReturningToOrigin()
        #expect(play.contracts.startBattle(offerID: "missing-offer")?.title == "Contract Unavailable")
        #expect(play.shellSession.playPath == [.explore, .contracts])
        #expect(play.consumePendingDestination() == nil)
        #expect(play.playerSave.contracts == board)
        roster.progressions[roster.activeHeroID] = .at(level: 10)
        roster.progressions[roster.activeCompanionID] = .at(level: 5)
        #expect(play.playerSave.persistFixtureBatch(logging: "Test setup") { $0.roster = roster })
        #expect(play.contracts.startBattle(offerID: standard.id) == nil)
        #expect(play.battle.activeBattle?.enemyEncounterLevel == 7)
        #expect(play.battle.activeBattle?.id != configuration.id)
    }

    @Test func `easy contract retry retains the previewed recovery enemy`() throws {
        let play = try context.makePlaySession()
        #expect(play.contracts.enter() == nil)
        let offer = try #require(play.playerSave.contracts.offer(for: .easy))
        #expect(play.playerSave.persistFixtureBatch(logging: "High level recovery contract") { save in
            save.roster.progressions[save.roster.activeHeroID] = .at(level: 40)
            save.roster.progressions[save.roster.activeCompanionID] = .at(level: 40)
        })
        let preview = try #require(play.contracts.resolvedEncounter(for: offer))
        play.battleCoordinator.nextCombatSeed = { 41 }
        #expect(play.contracts.startBattle(offerID: offer.id) == nil)
        let original = try #require(play.battle.activeBattle)
        let launch = try #require(play.battleCoordinator.activeRun?.launch)
        let enemy = try #require(GameContent.enemy(matching: offer.enemyID))
        let recovery = CombatBuildResolver.build(enemy: enemy, level: preview.level, profile: .recovery)
        let standard = CombatBuildResolver.build(enemy: enemy, level: preview.level)
        #expect(original.enemy == preview.combatant)
        #expect(original.enemyModifiers == recovery.modifiers)
        #expect(original.enemyModifiers.outgoingDamagePercent != standard.modifiers.outgoingDamagePercent)

        #expect(play.playerSave.persistFixtureBatch(logging: "Progression before Retry") { save in
            save.roster.grantExperience(1, to: launch.inputs.launch.hero)
        })
        play.battleCoordinator.nextCombatSeed = { 42 }
        #expect(play.restartActiveBattle() == nil)
        let retried = try #require(play.battleCoordinator.activeRun?.launch)
        #expect(retried.configuration.enemy == original.enemy)
        #expect(retried.configuration.enemyModifiers == original.enemyModifiers)
        #expect(retried.configuration.rngSeed == 42)
        #expect(retried.configuration.id != original.id)
        #expect(retried.configuration.hero.progression == play.playerSave.roster.progression(for: launch.inputs.launch.hero))
        #expect(retried.inputs.launch == launch.inputs.launch)
        #expect(retried.rewardPlan.items == launch.rewardPlan.items)
    }

    @Test(arguments: [ContractDifficulty.easy, .standard, .hard])
    func `difficulty resolves only when battle begins`(_ difficulty: ContractDifficulty) throws {
        let play = try context.makePlaySession()
        #expect(play.contracts.enter() == nil)
        #expect(play.contracts.refresh() == nil)
        let board = play.playerSave.contracts
        for offer in board.offers {
            #expect(!(play.battleCoordinator.preparedRuns[PlayBattleOrigin.contract(offerID: offer.id).runKey] != nil))
        }
        let offer = try #require(board.offer(for: difficulty))
        var roster = play.playerSave.roster
        roster.progressions[roster.activeHeroID] = .at(level: 2)
        roster.progressions[roster.activeCompanionID] = .at(level: 3)
        #expect(play.playerSave.persistFixtureBatch(logging: "Test setup") { $0.roster = roster })
        #expect(play.contracts.startBattle(offerID: offer.id) == nil)
        let expectedLevel = switch difficulty {
        case .easy: 1
        case .standard: 2
        case .hard: 5
        }
        #expect(play.battle.activeBattle?.enemyEncounterLevel == expectedLevel)
        #expect(play.playerSave.contracts == board)
    }

    @Test(arguments: [RewardModifier.experience, .wood, .unique, .keyword(.bleed)])
    func `victory pays the shown rewards and returns to one replaced offer`(modifier: RewardModifier) throws {
        let play = try context.makePlaySession()
        #expect(play.contracts.enter() == nil)
        #expect(play.playerSave.persistFixtureBatch(logging: "Contract modifier fixture") { save in
            save.contracts = PlayerContractsState(offers: save.contracts.offers.map {
                ContractOffer(id: $0.id, difficulty: $0.difficulty, enemyID: $0.enemyID, rewardModifier: modifier)
            })
        })
        let board = play.playerSave.contracts
        let hard = try #require(board.offer(for: .hard))
        #expect(play.contracts.startBattle(offerID: hard.id) == nil)
        let configuration = try #require(play.battle.activeBattle)
        let presentation = try #require(play.battlePresentation(for: configuration.runKey))
        let pendingItem = try #require(play.battleRegistration(for: play.battle.activeBattle?.runKey)?.launch.inputs.launch
            .pendingRewardItem)
        if let keyword = modifier.requiredKeyword {
            #expect(pendingItem.baseType.keywordAffinities.contains(keyword))
            #expect(pendingItem.affixes.contains { $0.keywords.contains(keyword) })
        }
        let before = play.playerSave.currentSave

        #expect(play.completeActiveBattle(configuration, battleGold: .init(gained: 0)).didComplete)
        #expect(play.battle.activeBattle == nil)
        #expect(play.shellSession.playPath == [.explore, .contracts])
        #expect(play.consumePendingDestination() == nil)
        #expect(play.playerSave.contracts.offer(for: .hard)?.id != hard.id)
        #expect(play.playerSave.contracts.offer(for: .easy) == board.offer(for: .easy))
        #expect(play.playerSave.contracts.offer(for: .standard) == board.offer(for: .standard))
        #expect(play.playerSave.inventory.item(matching: pendingItem.id) == pendingItem)
        #expect(play.playerSave.roster.progression(for: before.roster.activeHero)
            == before.roster.progression(for: before.roster.activeHero).addingExperience(presentation.rewardPlan.heroExperience))
        #expect(play.playerSave.roster.progression(for: before.roster.activeCompanion)
            == before.roster.progression(for: before.roster.activeCompanion).addingExperience(presentation.rewardPlan.companionExperience))
        let claimed = play.playerSave.currentSave
        #expect(!play.completeActiveBattle(configuration, battleGold: .init(gained: 0)).didComplete)
        #expect(play.playerSave.currentSave == claimed)
    }

    #if DEBUG
    @Test func `failed board refresh keeps jobs available for launch`() throws {
        let play = try context.makePlaySession()
        #expect(play.contracts.enter() == nil)
        #expect(play.playerSave.persistFixtureBatch(logging: "Earn refresh fixture") { $0.contracts.earnRefresh() })
        let before = play.playerSave.currentSave
        play.playerSave.forcesNextSaveFailure = true
        #expect(play.contracts.refresh() == nil)
        #expect(play.playerSave.isRetryingSaveAction)
        #expect(play.playerSave.currentSave == before)
        let easy = try #require(before.contracts.offer(for: .easy))
        #expect(play.contracts.startBattle(offerID: easy.id) == nil)
        #expect(play.battle.activeBattle?.runKey == PlayBattleOrigin.contract(offerID: easy.id).runKey)
    }
    #endif
}
