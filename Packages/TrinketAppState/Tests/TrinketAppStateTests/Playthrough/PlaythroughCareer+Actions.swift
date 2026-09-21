import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
@testable import TrinketAppState
@testable import TrinketBattleFeature
@testable import TrinketFeatureAdapters
@testable import TrinketPersistence

extension PlaythroughCareer {
    func execute(_ action: PlaythroughAction) async throws {
        switch action {
        case let .starterHero(id):
            try require(state.confirmStarterHero(id), "starter hero")
        case let .starterCompanion(id):
            try require(state.completeStarterSelection(companionID: id), "starter companion")
        case let .talent(id, tree, node):
            try require(play.currentPostBattleTalentCombatantID == id, "talent owner")
            try require(play.choosePostBattleTalent(nodeID: node, treeID: tree) == .unlocked, "talent")
            summary.talents += 1
        case .finishTalent:
            guard let id = play.postBattleTalentConfirmationID else { throw PlaythroughFailure.rejected("talent confirmation") }
            play.finishPostBattleTalentConfirmation(id: id)
        case let .mystery(id):
            try require(play.encounters.resolveActiveMysteryChoice(choiceID: id), "mystery choice")
        case .finishMystery:
            let isCorruption = play.encounters.activeMysteryEncounter?.showsCorruptionReveal == true
            try require(
                isCorruption ? play.encounters.finishActiveMysteryCorruptionReveal() : play.encounters.finishActiveMysteryEncounter(),
                "mystery completion",
            )
        case let .shop(id):
            try require(play.encounters.purchaseActiveShopOffer(offerID: id), "shop purchase")
        case .finishShop:
            try require(play.encounters.finishActiveShopEncounter(), "shop completion")
        case .reopen:
            try require(!play.isGameplayActive, "reload must be at browsing boundary")
            let before = snapshot
            close()
            try open()
            try require(snapshot == before, "immediate save reload comparison")
            summary.reloads += 1
        case let .corrupt(itemID):
            try require(play.encounters.corruptActiveMysteryItem(itemID: itemID), "corruption choice")
        case .card, .endTurn, .victory, .defeat, .retreat:
            try executeBattle(action)
        case .campaign, .enterLabyrinth, .labyrinth, .contracts, .contract, .spire:
            try executeMode(action)
        case .equip, .party, .upgrade, .collect:
            try await executeInvestment(action)
        }
    }

    private func executeBattle(_ action: PlaythroughAction) throws {
        switch action {
        case let .card(id):
            try require(battle.playCard(cardID: id, at: date).didCommit, "card \(id)")
        case .endTurn:
            let previous = battle.engineState?.turnCount
            try require(battle.canEndTurn, "turn readiness")
            battle.endTurn(at: date)
            try require(battle.outcome != nil || battle.engineState?.turnCount != previous, "turn transition")
        case .victory:
            guard let config = battle.activeBattle,
                  let award = battle.spectacle.outcomePresentation.victorySummaryIfAvailable else {
                throw PlaythroughFailure.rejected("victory presentation")
            }
            try require(battle.claimVictory(configurationID: config.id, summary: award), "victory claim")
            battle.finishVictoryPresentation(configurationID: config.id)
            try require(battle.activeBattle == nil, "victory exit")
            summary.outcomes.append("victory")
            recordBattleOutcome("victory", configuration: config)
            if VictoryRewardApplier.isBoss(enemyID: config.enemy?.id) {
                summary.bossVictories += 1
            }
        case let .defeat(retry):
            guard let config = battle.activeBattle,
                  case let .defeat(award) = battle.spectacle.outcomePresentation else {
                throw PlaythroughFailure.rejected("defeat presentation")
            }
            try require(
                battle.claimDefeat(configurationID: config.id, settlement: award, action: retry ? .retry : .leave),
                "defeat claim",
            )
            summary.outcomes.append("defeat")
            recordBattleOutcome("defeat", configuration: config)
        case .retreat:
            guard let config = battle.activeBattle else { throw PlaythroughFailure.rejected("retreat battle") }
            try require(battle.canRetreat, "retreat readiness")
            try require(battle.retreatFromBattle(), "retreat")
            guard case let .defeat(award) = battle.spectacle.outcomePresentation else {
                throw PlaythroughFailure.rejected("retreat defeat presentation")
            }
            try require(battle.claimDefeat(configurationID: config.id, settlement: award, action: .leave), "retreat leave")
            summary.outcomes.append("retreat")
            recordBattleOutcome("retreat", configuration: config)
        default: throw PlaythroughFailure.unsupported("invalid battle action")
        }
    }

    private func executeMode(_ action: PlaythroughAction) throws {
        switch action {
        case let .campaign(id, seed):
            guard store.journey.activeStageID == id, let stage = GameContent.stage(id: id) else {
                throw PlaythroughFailure.rejected("unreachable stage \(id)")
            }
            launchSeed = seed
            try require(play.journey.handleStagePrimaryAction(for: stage) == nil, "campaign entry \(id)")
            currentBattleEncounterID = id
            summary.reachedStages.append(id)
        case .enterLabyrinth:
            try require(play.labyrinth.enter() == nil, "Labyrinth entry")
        case let .labyrinth(id, seed):
            launchSeed = seed
            try require(play.labyrinth.handleNodeAction(nodeID: id) == nil, "Labyrinth node")
            currentBattleEncounterID = "labyrinth/\(id)"
            summary.reachedStages.append("labyrinth/\(id)")
        case let .contracts(refresh):
            try require((refresh ? play.contracts.refresh() : play.contracts.enter()) == nil, "Contracts board")
        case let .contract(id, seed):
            launchSeed = seed
            try require(play.contracts.startBattle(offerID: id) == nil, "Contract launch")
            currentBattleEncounterID = "contract/\(id)"
            summary.reachedStages.append("contract/\(id)")
        case let .spire(id, number, seed):
            launchSeed = seed
            guard let floor = GameContent.spireFloor(spireID: SpireID(id), floor: number) else {
                throw PlaythroughFailure.unsupported("Spire floor")
            }
            try require(play.spires.startBattle(for: floor) == nil, "Spire launch")
            currentBattleEncounterID = "spire/\(id)/\(number)"
            summary.reachedStages.append("spire/\(id)/\(number)")
        default: throw PlaythroughFailure.unsupported("invalid mode action")
        }
    }

    private func executeInvestment(_ action: PlaythroughAction) async throws {
        switch action {
        case let .equip(combatantID, itemID):
            guard let combatant = (store.roster.heroes + store.roster.companions).first(where: { $0.id == combatantID }),
                  let item = store.inventory.items.first(where: { $0.id == itemID }) else {
                throw PlaythroughFailure.rejected("equipment identity")
            }
            try require(
                CombatantDetailEdit.equipItem(item, item.baseType.defaultEquipmentSlot).apply(to: store, for: combatant),
                "equip item",
            )
            summary.equipmentChanges += 1
        case let .party(heroID, companionID):
            guard let hero = store.roster.heroes.first(where: { $0.id == heroID }),
                  let companion = store.roster.companions.first(where: { $0.id == companionID }),
                  store.roster.isUnlocked(hero), store.roster.isUnlocked(companion),
                  store.contentAccess.allowsCombatant(heroID), store.contentAccess.allowsCombatant(companionID) else {
                throw PlaythroughFailure.rejected("party availability")
            }
            try require(store.mutateRoster { roster in
                roster.setActiveHero(hero)
                roster.setActiveCompanion(companion)
            }, "party change")
        case let .upgrade(id, tier):
            guard let definition = GameContent.homesteadNodes.first(where: { $0.id.rawValue == id }) else {
                throw PlaythroughFailure.unsupported("Homestead node \(id)")
            }
            try await require(store.buildOrUpgradeNode(definition, targetTier: tier, at: date) == .success, "Homestead build")
            summary.upgrades += 1
        case let .collect(at):
            date = at
            let result = await store.collectProduction(at: at)
            switch result {
            case .success, .noProduction: break
            default: throw PlaythroughFailure.rejected("Homestead collection: \(result)")
            }
        default: throw PlaythroughFailure.unsupported("invalid investment action")
        }
    }

    func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw PlaythroughFailure.rejected(message) }
    }

    private func recordBattleOutcome(_ outcome: String, configuration: BattleRunConfiguration) {
        summary.battleOutcomes.append(.init(
            attempt: summary.battleOutcomes.count + 1,
            outcome: outcome,
            encounterID: currentBattleEncounterID ?? configuration.runKey?.rawValue,
            enemyID: configuration.enemy?.id,
            enemyEncounterLevel: configuration.enemyEncounterLevel,
            heroLevel: configuration.hero.progression.level,
            companionLevel: configuration.companion.progression.level,
            heroTalentCount: configuration.hero.unlockedTalents.count,
            companionTalentCount: configuration.companion.unlockedTalents.count,
            heroEquipmentCount: configuration.hero.equipmentLoadout.itemIDsBySlot.count,
            companionEquipmentCount: configuration.companion.equipmentLoadout.itemIDsBySlot.count,
        ))
    }
}
