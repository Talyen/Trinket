import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import TrinketAppState

@MainActor
struct VoyagePlayModeTests {
    let context: AppTestContext
    init() throws {
        context = try AppTestContext()
    }

    @Test(arguments: VoyageDifficulty.allCases)
    func `route resumes and party changes scale each attempt`(difficulty: VoyageDifficulty) throws {
        let play = try context.makePlaySession()
        #expect(play.playerSave.persistBatch(logging: "Unlock alternate Voyage hero") { save in
            save.roster.unlockHero(id: "wizard")
        })
        #expect(play.voyage.enter() == nil)
        let offer = try #require(play.playerSave.voyage.offers.first { $0.difficulty == difficulty })
        play.voyage.embark(offerID: offer.id)
        let firstNode = try #require(play.playerSave.voyage.activeRun?.nextNode)
        #expect(play.playerSave.persistBatch(logging: "Keyword Voyage reward") { save in
            save.voyage.updateNode(runID: offer.id, nodeID: firstNode.id) {
                $0.modifierIDs = [LabyrinthCatalog.rewardID(.keyword(.freeze))]
            }
        })
        let run = try #require(play.playerSave.voyage.activeRun)
        let node = try #require(run.nextNode)
        play.voyage.prepareNextBattle()
        let key = PlayBattleOrigin.voyage(runID: run.id, nodeID: node.id).runKey
        #expect(play.battle.hasPreparedRun(key))
        var roster = play.playerSave.roster
        let hero = try #require(roster.heroes.first { $0.id == "wizard" })
        roster.setActiveHero(hero)
        roster.progressions[roster.activeHeroID] = .at(level: 10)
        roster.progressions[roster.activeCompanionID] = .at(level: 6)
        #expect(play.playerSave.persistBatch(logging: "Voyage party") { $0.roster = roster })
        #expect(play.voyage.handleNode(runID: run.id, nodeID: node.id) == nil)
        let battle = try #require(play.battle.activeBattle)
        #expect(battle.hero.combatant.id == "wizard")
        #expect(battle.enemyEncounterLevel == 8 + difficulty.levelOffset)
        play.endBattleReturningToOrigin()
        #expect(play.shellSession.playPath == [.explore, .voyage])
        #expect(play.playerSave.voyage.activeRun == run)
        #expect(play.voyage.handleNode(runID: run.id, nodeID: node.id) == nil)
        let retry = try #require(play.battle.activeBattle)
        #expect(retry.id != battle.id)
        let item = try #require(play.battlePresentation(for: retry)?.pendingRewardItem)
        #expect(item.baseType.keywordAffinities.contains(.freeze))
        #expect(item.affixes.contains { $0.keywords.contains(.freeze) })
        let state = play.playerSave.currentSave
        #expect(play.completeActiveBattle(retry, battleGold: .init(gained: 3)).didComplete)
        let completed = play.playerSave.currentSave
        #expect(completed.inventory.item(matching: item.id) == item)
        #expect(completed.voyage.activeRun?.nodes.first?.isCleared == true)
        #expect(completed.voyage.activeRun?.earnedGold ?? 0 > 0)
        #expect(completed.journey == state.journey)
        #expect(!play.completeActiveBattle(retry, battleGold: .init(gained: 3)).didComplete)
        #expect(play.playerSave.currentSave == completed)
    }

    @Test func `full route uses shared encounters and pays completion once`() throws {
        let play = try context.makePlaySession()
        #expect(play.voyage.enter() == nil)
        let offers = play.playerSave.voyage.offers
        let offer = try #require(offers.first)
        play.voyage.embark(offerID: offer.id)
        for _ in 0 ..< offer.difficulty.nodeCount {
            let run = try #require(play.playerSave.voyage.activeRun)
            let node = try #require(run.nextNode)
            #expect(play.voyage.handleNode(runID: run.id, nodeID: node.id) == nil)
            if node.type.isCombat {
                let battle = try #require(play.battle.activeBattle)
                let presentation = try #require(play.battlePresentation(for: battle))
                #expect((presentation.completionBonus != nil) == (node.type == .boss))
                if node.type == .boss {
                    let base = presentation.rewardPlan.resolve(battleGold: .init(gained: 4), includingCompletionBonus: false)
                    let all = presentation.rewardPlan.resolve(battleGold: .init(gained: 4))
                    #expect(all.goldGained == base.goldGained + (run.earnedGold + base.goldGained) / 5)
                }
                #expect(play.completeActiveBattle(battle, battleGold: .init(gained: 4)).didComplete)
            } else if node.type == .shop {
                if play.encounters.activeShopEncounter != nil {
                    #expect(play.encounters.finishActiveShopEncounter())
                }
            } else {
                let session = try #require(play.encounters.activeMysteryEncounter)
                if !session.event.isRecruit {
                    let choice = session.event.choices.first { $0.effects.contains(.leave) } ?? session.event.choices.first
                    #expect(play.encounters.resolveActiveMysteryChoice(choiceID: choice?.id))
                }
                if play.encounters.activeMysteryEncounter != nil {
                    #expect(play.encounters.finishActiveMysteryEncounter())
                }
            }
            #expect(play.playerSave.voyage.activeRun?.node(id: node.id)?.isCleared == true)
        }
        #expect(play.playerSave.voyage.activeRun?.isComplete == true)
        #expect(play.playerSave.voyage.offers[0].id != offer.id)
        #expect(Array(play.playerSave.voyage.offers.dropFirst()) == Array(offers.dropFirst()))
        play.voyage.dismissCompleted()
        #expect(play.playerSave.voyage.activeRun == nil)
    }

    @Test func `destination and boss item promises appear and commit together once`() throws {
        let play = try context.makePlaySession()
        #expect(play.voyage.enter() == nil)
        let original = try #require(play.playerSave.voyage.offers.first)
        let offer = VoyageOffer(
            id: original.id, chapterID: original.chapterID, difficulty: original.difficulty,
            seed: original.seed, rewardModifier: .armorHoard,
        )
        var nodes = VoyageGenerator.nodes(for: offer, eligibleRecruitEventIDs: [])
        for index in nodes.indices.dropLast() {
            nodes[index].isCleared = true
        }
        nodes[nodes.count - 1].modifierIDs = [LabyrinthCatalog.rewardID(.armsHoard)]
        #expect(play.playerSave.persistBatch(logging: "Prepare final Voyage") { save in
            save.voyage.activeRun = VoyageRun(offer: offer, nodes: nodes)
        })
        let run = try #require(play.playerSave.voyage.activeRun)
        let boss = try #require(run.nextNode)
        #expect(play.voyage.handleNode(runID: run.id, nodeID: boss.id) == nil)
        let battle = try #require(play.battle.activeBattle)
        let presentation = try #require(play.battlePresentation(for: battle))
        let items = presentation.rewardPlan.resolve(battleGold: .init()).items
        #expect(items.count == 2)
        #expect(items[0].baseType.slot == .weapon)
        #expect(items[1].baseType.slot == .armor)
        #expect(play.completeActiveBattle(battle, battleGold: .init()).didComplete)
        let after = play.playerSave.currentSave
        #expect(items.allSatisfy { item in after.inventory.items.contains { $0.id == item.id } })
        #expect(after.voyage.activeRun?.isComplete == true)
        #expect(!play.completeActiveBattle(battle, battleGold: .init()).didComplete)
        #expect(play.playerSave.currentSave == after)
    }

    @Test func `destination experience is victory only and abandonment forfeits it`() throws {
        let play = try context.makePlaySession()
        #expect(play.voyage.enter() == nil)
        let original = try #require(play.playerSave.voyage.offers.first)
        let offer = VoyageOffer(
            id: original.id, chapterID: original.chapterID, difficulty: original.difficulty,
            seed: original.seed, rewardModifier: .experience,
        )
        var nodes = VoyageGenerator.nodes(for: offer, eligibleRecruitEventIDs: [])
        for index in nodes.indices.dropLast() {
            nodes[index].isCleared = true
        }
        nodes[nodes.count - 1].modifierIDs = [LabyrinthCatalog.rewardID(.experience)]
        #expect(play.playerSave.persistBatch(logging: "Prepare XP Voyage") { save in
            save.voyage.activeRun = VoyageRun(offer: offer, nodes: nodes)
        })
        let run = try #require(play.playerSave.voyage.activeRun)
        let boss = try #require(run.nextNode)
        #expect(play.voyage.handleNode(runID: run.id, nodeID: boss.id) == nil)
        let battle = try #require(play.battle.activeBattle)
        let presentation = try #require(play.battlePresentation(for: battle))
        #expect(presentation.experienceBonusPercent == 25)
        #expect(presentation.victoryOnlyExperienceBonusPercent == 25)
        #expect(presentation.rewardPlan.heroExperience > presentation.rewardPlan.defeatHeroExperience)
        let inputs = try #require(presentation.rewardInputs)
        let defeat = presentation.rewardPlan.settleDefeat(
            progress: .init(remainingHealth: 0, maximumHealth: 100),
            inputs: inputs,
        )
        #expect(defeat.award.items.isEmpty)
        let inventory = play.playerSave.inventory
        play.endBattleReturningToOrigin()
        play.voyage.abandon(runID: run.id)
        #expect(play.playerSave.voyage.activeRun == nil)
        #expect(play.playerSave.inventory == inventory)
    }

    @Test func `exhausted recruit becomes modified mystery without rerolling route`() throws {
        let play = try context.makePlaySession()
        _ = play.voyage.enter()
        let offer = try #require(play.playerSave.voyage.offers.first)
        play.voyage.embark(offerID: offer.id)
        let run = try #require(play.playerSave.voyage.activeRun)
        let recruit = try #require(run.nodes.first { $0.type == .recruit })
        #expect(play.playerSave.persistBatch(logging: "Unlock remaining recruits") { save in
            save.roster.unlockAllCombatants(atLevel: 1)
        })
        _ = play.voyage.enter()
        let updated = try #require(play.playerSave.voyage.activeRun)
        #expect(updated.nodes.map(\.id) == run.nodes.map(\.id))
        #expect(updated.node(id: recruit.id)?.type == .mystery)
        #expect(updated.node(id: recruit.id)?.modifierIDs.count == 1)
        #expect(updated.nodes.filter { $0.id != recruit.id } == run.nodes.filter { $0.id != recruit.id })
    }

    #if DEBUG
    @Test func `failed embark and victory do not publish partial progress`() throws {
        let play = try context.makePlaySession()
        #expect(play.voyage.enter() == nil)
        let offer = try #require(play.playerSave.voyage.offers.first)
        play.playerSave.forcesNextSaveFailure = true
        play.voyage.embark(offerID: offer.id)
        #expect(play.playerSave.voyage.activeRun == nil)
        play.voyage.embark(offerID: offer.id)
        let run = try #require(play.playerSave.voyage.activeRun)
        let node = try #require(run.nextNode)
        #expect(play.voyage.handleNode(runID: run.id, nodeID: node.id) == nil)
        let battle = try #require(play.battle.activeBattle)
        let before = play.playerSave.currentSave
        play.playerSave.forcesNextSaveFailure = true
        #expect(play.completeActiveBattle(battle, battleGold: .init()) == .persistenceFailed)
        #expect(play.playerSave.currentSave == before)
        #expect(play.completeActiveBattle(battle, battleGold: .init()).didComplete)
        #expect(play.playerSave.voyage.activeRun?.nodes.first?.isCleared == true)
    }
    #endif
}
