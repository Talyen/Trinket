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
        guard let token = savedBattleResumeToken else { return false }
        return isResumeTokenStillPlayable(token)
    }

    func resumeSavedBattle() {
        guard let token = savedBattleResumeToken else { return }
        switch token {
        case let .journey(stageID):
            if let stage = GameContent.stage(id: stageID) {
                startBattle(for: stage)
            }
        case let .aspect(aspectID, floorNumber):
            if let floor = GameContent.aspectFloor(aspectID: aspectID, floor: floorNumber) {
                _ = startAspectBattle(for: floor)
            }
        case let .labyrinth(nodeID):
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

        let hero = configuration.hero.combatant
        let pet = configuration.pet.combatant
        switch configuration.resumeToken {
        case let .journey(stageID):
            if let stage = GameContent.stage(id: stageID) {
                completeStage(
                    stage,
                    hero: hero,
                    pet: pet,
                    battleEarnedGold: battleEarnedGold,
                    materialRewards: materialRewards
                )
            }
        case let .aspect(aspectID, floorNumber):
            if let floor = GameContent.aspectFloor(aspectID: aspectID, floor: floorNumber) {
                completeAspectFloor(
                    floor,
                    hero: hero,
                    pet: pet,
                    battleEarnedGold: battleEarnedGold,
                    materialRewards: materialRewards,
                    rewardItem: configuration.pendingRewardItem
                )
            }
        case let .labyrinth(nodeID):
            completeLabyrinthNode(
                nodeID: nodeID,
                hero: hero,
                pet: pet,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards
            )
        case .none:
            if battleEarnedGold > 0 {
                grantBattleEarnedGold(battleEarnedGold)
            }
        }
        battle.endBattle()
    }

    private func isResumeTokenStillPlayable(_ token: ActiveBattleResumeToken) -> Bool {
        switch token {
        case let .journey(stageID):
            guard let stage = GameContent.stage(id: stageID),
                  case .battle = stage.encounter else {
                return false
            }
            return !journey.current.hasClaimedRewards(for: stage)
        case let .aspect(aspectID, floorNumber):
            guard ModesUnlock.isUnlocked(journey: journey.current),
                  let aspect = GameContent.aspect(id: aspectID),
                  AspectUnlock.isUnlocked(aspect, progress: aspects.current),
                  GameContent.aspectFloor(aspectID: aspectID, floor: floorNumber) != nil
            else {
                return false
            }
            return aspects.current.isFloorUnlocked(
                floorNumber,
                aspectID: aspectID.rawValue,
                floorCount: aspect.floorCount
            )
        case let .labyrinth(nodeID):
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

        activateBattle(
            resumeToken: .journey(stageID: stage.id),
            hero: roster.activeHero,
            pet: roster.activePet,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: stage.rewards
        )
        return nil
    }

    func restartActiveBattle() {
        guard let activeBattle = battle.activeBattle else { return }

        let hero = roster.heroes.first(where: { $0.id == activeBattle.hero.combatant.id })
            ?? roster.activeHero
        let pet = roster.pets.first(where: { $0.id == activeBattle.pet.combatant.id })
            ?? roster.activePet

        activateBattle(
            resumeToken: activeBattle.resumeToken,
            hero: hero,
            pet: pet,
            enemy: activeBattle.enemy,
            enemyEncounterLevel: activeBattle.enemyEncounterLevel,
            stageReward: activeBattle.stageReward
        )
    }

    /// Clears preview, installs a fresh battle configuration, and syncs the tick loop.
    func activateBattle(
        resumeToken: ActiveBattleResumeToken? = nil,
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        stageReward: StageReward?
    ) {
        let stageID: String?
        let aspectBattle: ActiveBattleConfiguration.AspectBattle?
        let labyrinthBattle: ActiveBattleConfiguration.LabyrinthBattle?
        switch resumeToken {
        case let .journey(id):
            stageID = id
            aspectBattle = nil
            labyrinthBattle = nil
        case let .aspect(aspectID, floor):
            stageID = nil
            aspectBattle = .init(aspectID: aspectID, floor: floor)
            labyrinthBattle = nil
        case let .labyrinth(nodeID):
            stageID = nil
            aspectBattle = nil
            labyrinthBattle = .init(nodeID: nodeID)
        case .none:
            stageID = nil
            aspectBattle = nil
            labyrinthBattle = nil
        }

        battle.preview = nil
        battle.activeBattle = ActiveBattleConfiguration.make(
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
        battle.isPaused = selectedTab != .play
        syncBattleTickLoop()
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
