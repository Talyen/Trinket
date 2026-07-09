import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    func isSavedBattleValid() -> Bool {
        guard let savedVersion = shellSession.activeBattleSchemaVersion,
              savedVersion == PlayerShellSessionStore.currentSchemaVersion else {
            return false
        }
        if let savedAt = shellSession.activeBattleSavedAt {
            let elapsed = Date.now.timeIntervalSince(savedAt)
            if elapsed > battleSaveExpiryWindow {
                return false
            }
        }

        if let stageID = shellSession.activeBattleStageID {
            guard let stage = GameContent.stage(id: stageID),
                  case .battle = stage.encounter else {
                return false
            }
            return !journey.current.hasClaimedRewards(for: stage)
        }

        if let aspectIDRaw = shellSession.activeBattleAspectID,
           let floorNumber = shellSession.activeBattleAspectFloor {
            let aspectID = AspectID(aspectIDRaw)
            guard ModesUnlock.isUnlocked(journey: journey.current),
                  let aspect = GameContent.aspect(id: aspectID),
                  AspectUnlock.isUnlocked(aspect, progress: aspects.current),
                  GameContent.aspectFloor(aspectID: aspectID, floor: floorNumber) != nil
            else {
                return false
            }
            return aspects.current.isFloorUnlocked(
                floorNumber,
                aspectID: aspectIDRaw,
                floorCount: aspect.floorCount
            )
        }

        if let nodeID = shellSession.activeBattleLabyrinthNodeID {
            guard isLabyrinthUnlocked else { return false }
            if !labyrinth.hasMap {
                _ = enterLabyrinth()
            }
            guard let node = labyrinth.node(id: nodeID),
                  node.type.isCombat,
                  !node.isCleared
            else {
                return false
            }
            return labyrinth.isNodeReachable(nodeID) || node.isRevealed
        }

        return false
    }

    func resumeSavedBattle() {
        if let stageID = shellSession.activeBattleStageID,
           let stage = GameContent.stage(id: stageID) {
            startBattle(for: stage)
            return
        }
        if let aspectIDRaw = shellSession.activeBattleAspectID,
           let floorNumber = shellSession.activeBattleAspectFloor,
           let floor = GameContent.aspectFloor(aspectID: AspectID(aspectIDRaw), floor: floorNumber) {
            _ = startAspectBattle(for: floor)
            return
        }
        if let nodeID = shellSession.activeBattleLabyrinthNodeID {
            _ = startLabyrinthBattle(nodeID: nodeID)
        }
    }

    func abandonSavedBattle() {
        shellSession.clearBattleState()
    }

    @discardableResult
    func completeStage(
        _ stage: Stage,
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil
    ) -> String {
        var scrollTarget = JourneyMapPresentation.scrollFocusID(for: journey.current)
        if let resultingJourney = persistStageCompletions(
            [stage],
            hero: hero,
            pet: pet,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards
        ) {
            scrollTarget = JourneyMapPresentation.scrollFocusID(for: resultingJourney)
            noteMapScrollFocus(scrollTarget)
        }
        return scrollTarget
    }

    func completeActiveBattle(
        _ configuration: ActiveBattleConfiguration,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]? = nil
    ) {
        guard battle.activeBattle != nil else { return }

        if let stageID = configuration.stageID,
           let stage = GameContent.stage(id: stageID) {
            completeStage(
                stage,
                hero: configuration.hero.combatant,
                pet: configuration.pet.combatant,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards
            )
        } else if let aspectBattle = configuration.aspectBattle,
                  let floor = GameContent.aspectFloor(
                      aspectID: aspectBattle.aspectID,
                      floor: aspectBattle.floor
                  ) {
            completeAspectFloor(
                floor,
                hero: configuration.hero.combatant,
                pet: configuration.pet.combatant,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: configuration.pendingRewardItem
            )
        } else if let labyrinthBattle = configuration.labyrinthBattle {
            completeLabyrinthNode(
                nodeID: labyrinthBattle.nodeID,
                hero: configuration.hero.combatant,
                pet: configuration.pet.combatant,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards
            )
        } else if battleEarnedGold > 0 {
            grantBattleEarnedGold(battleEarnedGold)
        }
        battle.endBattle()
    }

    func grantBattleEarnedGold(_ amount: Int) {
        guard amount > 0 else { return }
        do {
            try playerSave.performBatchMutation { save in
                save.roster.gold += amount
            }
        } catch {
            appStateLogger.error(
                "Failed to persist battle gold: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Beyond the seamless resume window, drop the in-memory battle while keeping the
    /// resume card — unless a terminal victory is already pending, in which case grant
    /// rewards so the player does not lose an unclaimed win.
    func discardOrCompleteBattleBeyondSeamlessWindow() {
        guard let configuration = battle.activeBattle else { return }

        if battle.isShowingVictory || battle.outcome == .victory {
            let battleGold = battle.victorySummary?.battleGold ?? battle.state?.earnedGold ?? 0
            let materialRewards = battle.victorySummary?.materialRewards
            completeActiveBattle(
                configuration,
                battleEarnedGold: battleGold,
                materialRewards: materialRewards
            )
            return
        }

        if battle.isShowingDefeat {
            if let nodeID = configuration.labyrinthBattle?.nodeID {
                recordLabyrinthDefeat(nodeID: nodeID)
            }
            battle.endBattle()
            return
        }

        // Mid-fight: clear live battle UI/state but keep shell session stage ID for the
        // resume card (same contract as the previous nil-callback clear).
        let oldChange = battle.onBattleStateChange
        battle.onBattleStateChange = nil
        battle.endBattle()
        battle.onBattleStateChange = oldChange
    }

    @discardableResult
    func startBattle(for stage: Stage) -> StageMapMessage? {
        guard battle.activeBattle == nil else { return nil }

        guard let encounter = ActiveBattleConfiguration.resolvedEncounter(for: stage) else {
            return StageMapMessage(title: "Encounter Missing", message: "This stage is not ready yet.")
        }

        battle.preview = nil
        battle.activeBattle = makeActiveBattleConfiguration(
            stageID: stage.id,
            hero: roster.activeHero,
            pet: roster.activePet,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: stage.rewards
        )
        battle.isPaused = selectedTab != .play
        syncBattleTickLoop()
        return nil
    }

    func restartActiveBattle() {
        guard let activeBattle = battle.activeBattle else { return }

        let hero = roster.heroes.first(where: { $0.id == activeBattle.hero.combatant.id })
            ?? roster.activeHero
        let pet = roster.pets.first(where: { $0.id == activeBattle.pet.combatant.id })
            ?? roster.activePet

        battle.activeBattle = makeActiveBattleConfiguration(
            stageID: activeBattle.stageID,
            hero: hero,
            pet: pet,
            enemy: activeBattle.enemy,
            enemyEncounterLevel: activeBattle.enemyEncounterLevel,
            stageReward: activeBattle.stageReward,
            aspectBattle: activeBattle.aspectBattle,
            labyrinthBattle: activeBattle.labyrinthBattle
        )
        syncBattleTickLoop()
    }

    func makeActiveBattleConfiguration(
        stageID: String?,
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        stageReward: StageReward?,
        aspectBattle: ActiveBattleConfiguration.AspectBattle? = nil,
        labyrinthBattle: ActiveBattleConfiguration.LabyrinthBattle? = nil
    ) -> ActiveBattleConfiguration {
        ActiveBattleConfiguration.make(
            stageID: stageID,
            aspectBattle: aspectBattle,
            labyrinthBattle: labyrinthBattle,
            rngSeed: UInt64.random(in: UInt64.min ... UInt64.max),
            hero: hero,
            pet: pet,
            rosterState: roster,
            inventoryState: inventory,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward
        )
    }

    @discardableResult
    func handleStagePrimaryAction(for stage: Stage) -> StageMapMessage? {
        switch stage.encounter {
        case .battle:
            return startBattle(for: stage)
        case .mysteryEvent:
            return beginMysteryEncounter(for: stage)
        case .shop:
            return beginShopEncounter(for: stage)
        case .event, .rest:
            completeStage(stage, hero: roster.activeHero, pet: roster.activePet)
            return nil
        }
    }

    @discardableResult
    func persistStageCompletions(
        _ stages: [Stage],
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        resetJourney: Bool = false
    ) -> JourneyProgressState? {
        guard !stages.isEmpty else { return nil }

        var resultingJourney = journey.current
        do {
            try playerSave.performBatchMutation { save in
                if resetJourney {
                    save.journey = .initial
                }
                for (index, stage) in stages.enumerated() {
                    let isLast = index == stages.count - 1
                    StageCompletion.complete(
                        stage,
                        hero: hero,
                        pet: pet,
                        battleEarnedGold: isLast ? battleEarnedGold : 0,
                        materialRewards: isLast ? materialRewards : nil,
                        in: GameContent.chapters,
                        save: &save
                    )
                }
                resultingJourney = save.journey
            }
        } catch {
            appStateLogger.error(
                "Failed to persist stage completions: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
        return resultingJourney
    }
}
