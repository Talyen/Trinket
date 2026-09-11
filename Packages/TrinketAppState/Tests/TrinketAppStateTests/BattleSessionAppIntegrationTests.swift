import Foundation
import Testing
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence
@testable import TrinketAppState
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionAppIntegrationTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func `stale victory settlement must refresh before claiming`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(state.journey.startBattle(for: stage) == nil)
        let configuration = try #require(state.battle.activeBattle)
        let battle = try #require(state.battle as? BattleSession)
        battle.presentLaunchVictory()
        let summary = try #require(battle.spectacle.outcomePresentation.victorySummaryIfAvailable)
        try state.playerSave.performBatchMutation { save in save.roster.gold = 999 }
        #expect(!battle.claimVictory(configurationID: configuration.id, summary: summary))
        #expect(!state.playerSave.journey.hasClaimedRewards(for: stage))
        #expect(battle.completionError == nil)
        let refreshedSummary = try #require(battle.spectacle.outcomePresentation.victorySummaryIfAvailable)
        let refreshed = refreshedSummary.settlement
        #expect(refreshed.award.goldGained == 0)
        #expect(refreshed.replacementExperience > 0)
        #expect(refreshedSummary.totalGold == 0)
        #expect(refreshedSummary.experience == refreshed.award.heroExperience)
        #expect(battle.claimVictory(configurationID: configuration.id, summary: refreshedSummary))
        #expect(state.playerSave.roster.gold == 999)
        #expect(state.playerSave.roster.progression(for: configuration.hero.combatant) == refreshed.heroProgressionAfter)
        #expect(state.playerSave.roster.progression(for: configuration.companion.combatant) == refreshed.companionProgressionAfter)
        let claimedSave = state.playerSave.currentSave
        #expect(!battle.claimVictory(configurationID: configuration.id, summary: refreshedSummary))
        #expect(state.playerSave.currentSave == claimedSave)
    }

    @Test func `prepared battle uses current party build`() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.playerSave.roster.activeHero
        state.journey.prepareBattle(for: stage)
        let runKey = PlayBattleOrigin.journey(stageID: stage.id).runKey
        let prepared = try #require(state.battleRegistration(for: runKey)?.launch.configuration)
        let item = try #require(GameContent.sampleInventoryItems.first { $0.baseType.defaultEquipmentSlot == .weapon })
        try state.playerSave.performBatchMutation { save in
            save.inventory.appendUniqueItem(item)
            var loadout = save.roster.equipmentLoadout(for: hero)
            loadout.equip(item, inventory: save.inventory.items)
            save.roster.setEquipmentLoadout(loadout, for: hero)
            save.roster.progressions[hero.id] = .at(level: 5)
        }

        #expect(state.journey.startBattle(for: stage) == nil)
        let active = try #require(state.battle.activeBattle)
        #expect(active.id != prepared.id)
        #expect(active.rngSeed == prepared.rngSeed)
        #expect(active.hero.progression == state.playerSave.roster.progression(for: hero))
        #expect(active.hero.equipmentLoadout == state.playerSave.roster.equipmentLoadout(for: hero))
    }

    @Test(arguments: [false, true])
    func `prepared launch validates encounter inputs and preserves sibling runs`(changedEncounter: Bool) throws {
        let state = try context.makePlaySession()
        let stages = GameContent.chapters[0].stages.filter(\.encounter.isCombat)
        let first = try #require(stages.first)
        let second = try #require(stages.dropFirst().first)
        state.journey.prepareBattle(for: first)
        state.journey.prepareBattle(for: second)
        let runKey = PlayBattleOrigin.journey(stageID: first.id).runKey
        let sibling = PlayBattleOrigin.journey(stageID: second.id).runKey
        let registration = try #require(state.battleRegistration(for: runKey))
        let original = registration.launch.inputs.launch
        let input = BattleLaunchInput(
            origin: original.origin, hero: original.hero, companion: original.companion, enemy: original.enemy,
            enemyEncounterLevel: (original.enemyEncounterLevel ?? 1) + (changedEncounter ? 1 : 0),
            stageReward: original.stageReward, experienceBonusPercent: original.experienceBonusPercent,
            pendingRewardItem: original.pendingRewardItem, stageRewardsAlreadyClaimed: original.stageRewardsAlreadyClaimed,
            universalModifiers: original.universalModifiers, labyrinthModifiers: original.labyrinthModifiers,
        )
        #expect(state.battleLaunch.activateBattle(input, route: registration.route))
        let active = try #require(state.battle.activeBattle)
        #expect((active.id != registration.launch.configuration.id) == changedEncounter)
        #expect(active.enemyEncounterLevel == input.enemyEncounterLevel)
        #expect(active.rngSeed == registration.launch.configuration.rngSeed)
        #expect(state.battle.hasPreparedRun(sibling))
        let stale = PlayBattleLaunch.assembleLaunch(registration.launch.inputs).configuration
        #expect(!state.battle.restart(stale))
        #expect(!state.completeActiveBattle(stale, battleGold: .init(gained: 5)).didComplete)
        #expect(state.battle.activeBattle?.id == active.id)
    }

    @Test func `scholars toll victory shows the granted experience`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        #expect(state.labyrinth.enter() == nil)
        let nodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        let node = try #require(state.playerSave.labyrinth.node(id: nodeID))
        LabyrinthTestSupport.store(
            LabyrinthTestSupport.remade(
                node, type: .battle, recruitEventID: nil, enemyID: node.enemyID,
                modifierIDs: [LabyrinthModifierID("scholarsToll")],
            ),
            in: state,
        )
        #expect(state.labyrinth.startBattle(nodeID: nodeID) == nil)
        let active = try #require(state.battle.activeBattle)
        let presentation = try #require(state.battlePresentation(for: active.runKey))
        let heroBefore = state.playerSave.roster.progression(for: state.playerSave.roster.activeHero)
        #expect(presentation.experienceBonusPercent == 25)
        #expect(state.completeActiveBattle(active, battleGold: .init(gained: 0)).didComplete)
        #expect(
            state.playerSave.roster.progression(for: state.playerSave.roster.activeHero)
                == heroBefore.addingExperience(presentation.heroExperienceAward),
        )
    }

    @Test func `start battle ignores request when battle already active`() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.journey.startBattle(for: stage)
        let firstBattleID = try #require(appState.battle.activeBattle?.id)

        let message = appState.journey.startBattle(for: stage)

        #expect(message == nil)
        #expect(appState.battle.activeBattle?.id == firstBattleID)
    }

    @Test func `restart battle refreshes progression from roster when roster updated`() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.journey.startBattle(for: stage)

        #expect(appState.battle.activeBattle?.hero.progression.currentXP == 0)

        var updatedRoster = appState.playerSave.roster
        updatedRoster.grantExperience(3, to: appState.playerSave.roster.activeHero)
        #expect(appState.playerSave.persistBatch(logging: "Test setup") { $0.roster = updatedRoster })
        appState.restartActiveBattle()

        #expect(appState.battle.activeBattle?.hero.progression.currentXP == 3)
    }

    @Test func `start battle returns message when enemy missing`() throws {
        let appState = try context.makePlaySession()
        let brokenStage = Stage(
            id: "test-missing-enemy",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            encounter: .battle(enemyID: "missing-enemy"),
            rewards: .empty,
        )

        let message = try #require(appState.journey.startBattle(for: brokenStage))

        #expect(message.fullGameOffer == nil)
        #expect(appState.battle.activeBattle == nil)
    }

    @Test func `restart battle rebuilds active configuration when battle active`() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.journey.startBattle(for: stage)
        let original = try #require(appState.battle.activeBattle)

        appState.restartActiveBattle()

        let restarted = try #require(appState.battle.activeBattle)
        #expect(restarted.runKey == original.runKey)
        #expect(restarted.hero.combatant.id == original.hero.combatant.id)
        #expect(restarted.id != original.id)
    }

    @Test func `restart battle preserves labyrinth reward fields`() throws {
        let appState = try context.makePlaySession(arguments: ["-reset-state"])
        _ = appState.labyrinth.enter()
        let combatNodeID = try #require(
            LabyrinthTestSupport.firstReachableCombatNodeID(
                where: { node in
                    let effects = appState.playerSave.labyrinth.effects(for: node.id)
                    return !effects.damageDealtBonus.isEmpty
                        || !effects.damageTakenReduction.isEmpty
                        || effects.blockGainedBonus != 0
                        || effects.leechGainedPercent != 0
                },
                in: appState,
            ),
        )
        #expect(appState.labyrinth.startBattle(nodeID: combatNodeID) == nil)
        let original = try #require(appState.battle.activeBattle)
        let originalPresentation = try #require(appState.battlePresentation(for: original.runKey))
        let effects = appState.playerSave.labyrinth.effects(for: combatNodeID)
        let originalUniversalModifiers = appState.battleUniversalModifiers(for: original.runKey)
        #expect(originalUniversalModifiers.count == 1)
        for (keyword, amount) in effects.damageDealtBonus {
            #expect(original.hero.modifiers.damageDealtBonus(for: keyword) == 0)
            #expect(original.companion.modifiers.damageDealtBonus(for: keyword) == 0)
            #expect(original.enemyModifiers.damageDealtBonus(for: keyword) == amount)
        }

        appState.restartActiveBattle()

        let restarted = try #require(appState.battle.activeBattle)
        let restartedPresentation = try #require(appState.battlePresentation(for: restarted.runKey))
        #expect(restarted.runKey == PlayBattleOrigin.labyrinth(nodeID: combatNodeID).runKey)
        #expect(
            appState.battleUniversalModifiers(for: restarted.runKey) == originalUniversalModifiers,
        )
        #expect(restartedPresentation.pendingRewardItem == originalPresentation.pendingRewardItem)
        #expect(restartedPresentation.rewardItems == originalPresentation.rewardItems)
        #expect(restarted.id != original.id)
    }

    @Test func `restart battle in labyrinth preserves battle combatant and starts at full health when active roster changes`() throws {
        let appState = try context.makePlaySession(arguments: ["-reset-state"])
        _ = appState.labyrinth.enter()
        let combatNodeID = try #require(
            LabyrinthTestSupport.firstReachableCombatNodeID(in: appState),
        )
        let initialHero = appState.playerSave.roster.activeHero
        let otherHero = try #require(
            GameContent.heroes.first { $0.id != initialHero.id },
        )

        var save = appState.playerSave.currentSave
        save.roster.unlock(otherHero)
        #expect(appState.playerSave.persistBatch(logging: "Test setup") { $0.roster = save.roster })

        #expect(appState.labyrinth.startBattle(nodeID: combatNodeID) == nil)
        let original = try #require(appState.battle.activeBattle)
        #expect(original.hero.combatant.id == initialHero.id)
        #expect(original.hero.startingHealth == nil)

        var updatedRoster = appState.playerSave.roster
        updatedRoster.setActiveHero(otherHero)
        #expect(appState.playerSave.persistBatch(logging: "Test setup") { $0.roster = updatedRoster })

        appState.restartActiveBattle()

        let restarted = try #require(appState.battle.activeBattle)
        #expect(restarted.hero.combatant.id == initialHero.id)
        #expect(restarted.hero.startingHealth == nil)
    }

    @Test func `clearing transient state removes the whole battle run record`() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.journey.startBattle(for: stage)
        let runKey = try #require(appState.battle.activeBattle?.runKey)

        #expect(appState.route(for: runKey) != nil)
        #expect(appState.battlePresentation(for: runKey) != nil)

        appState.clearTransientState()

        #expect(appState.route(for: runKey) == nil)
        #expect(appState.battlePresentation(for: runKey) == nil)
        #expect(appState.battle.activeBattle == nil)
    }

    @Test func `prepared siblings survive activation and active pruning then clear together on exit`() throws {
        let appState = try context.makePlaySession()
        let combatStages = GameContent.chapters
            .flatMap(\.stages)
            .filter(\.encounter.isCombat)
        let firstStage = try #require(combatStages.first)
        let secondStage = try #require(combatStages.dropFirst().first)

        appState.journey.prepareBattle(for: firstStage)
        let firstRunKey = PlayBattleOrigin.journey(stageID: firstStage.id).runKey
        appState.journey.prepareBattle(for: secondStage)
        let secondRunKey = PlayBattleOrigin.journey(stageID: secondStage.id).runKey
        let battle = try #require(context.lastBattle)

        #expect(appState.battlePresentation(for: firstRunKey) != nil)
        #expect(appState.battlePresentation(for: secondRunKey) != nil)

        _ = appState.journey.startBattle(for: secondStage)

        #expect(appState.battle.activeBattle?.runKey == secondRunKey)
        #expect(appState.battlePresentation(for: firstRunKey) != nil)
        #expect(appState.battlePresentation(for: secondRunKey) != nil)
        #expect(battle.hasPreparedRun(firstRunKey))
        #expect(!battle.hasPreparedRun(secondRunKey))
        appState.battleLaunch.keepPreparedRuns([])
        #expect(appState.battlePresentation(for: firstRunKey) != nil)
        #expect(appState.battlePresentation(for: secondRunKey) != nil)
        #expect(battle.hasPreparedRun(firstRunKey))

        appState.endBattleReturningToOrigin()
        #expect(appState.battlePresentation(for: firstRunKey) == nil)
        #expect(appState.battlePresentation(for: secondRunKey) == nil)
        #expect(!battle.hasPreparedRun(firstRunKey))
        #expect(battle.lifecyclePhase == .idle)
    }

    #if DEBUG
    @Test func `victory persist failure preserves the award and retries through composition`() throws {
        let playerSave = try PlayerSaveStore(
            disableCloudSync: true,
            inMemoryOnly: true,
        )
        let battle = BattleSession(
            autoEndTurnDelay: 0,
            openingHandDrawStagger: 0,
            enemyAttackImpactDelayOverride: 0,
            outcomePresentationDelayOverride: 0,
            presentationEnvironment: .silent,
        )
        battle.partyCelebrateDelayOverride = .zero
        let state = try context.makePlaySession(playerSave: playerSave, battleRuntime: battle)
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        driveToVictory(battle)
        #expect(battle.outcome == .victory)
        let summary = try #require(battle.spectacle.outcomePresentation.victorySummaryIfAvailable)
        let before = playerSave.currentSave
        playerSave.forcesNextSaveFailure = true
        #expect(!battle.claimVictory(configurationID: configuration.id, summary: summary))
        #expect(playerSave.currentSave == before)
        #expect(battle.completionError != nil)
        #expect(battle.spectacle.outcomePresentation.isVictoryPresented)
        #expect(battle.spectacle.outcomePresentation.victorySummaryIfAvailable == summary)
        #expect(state.battle.activeBattle != nil)
        #expect(battle.claimVictory(configurationID: configuration.id, summary: summary))
        #expect(state.playerSave.journey.hasClaimedRewards(for: stage))
        #expect(state.battle.activeBattle == nil)
    }
    #endif

    @MainActor
    private func driveToVictory(_ battle: BattleSession) {
        var steps = 0
        while battle.outcome == nil, steps < 200 {
            steps += 1
            if let card = battle.hand.first(where: { battle.isCardPlayable($0) }) {
                _ = battle.playCard(cardID: card.id)
                continue
            }
            if battle.canEndTurn {
                battle.endTurn()
                continue
            }
            break
        }
        battle.handleOutcomeIfNeeded(at: .now)
    }
}
