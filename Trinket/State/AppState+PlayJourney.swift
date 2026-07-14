import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    /// Completes a stage and returns the map scroll target when persistence succeeds.
    @discardableResult
    func completeStage(
        _ stage: Stage,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil
    ) -> String? {
        guard let resultingJourney = persistStageCompletions(
            [stage],
            hero: hero,
            companion: companion,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards
        ) else {
            return nil
        }
        let scrollTarget = JourneyMapPresentation.scrollFocusID(for: resultingJourney)
        noteMapScrollFocus(scrollTarget)
        return scrollTarget
    }

    /// Persists victory rewards and ends the battle only when persistence succeeds.
    @discardableResult
    func completeActiveBattle(
        _ configuration: ActiveBattleConfiguration,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]? = nil
    ) -> Bool {
        guard battle.activeBattle != nil else { return false }

        let persisted = persistBattleProgress(
            for: configuration,
            hero: configuration.hero.combatant,
            companion: configuration.companion.combatant,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards
        )
        if persisted {
            queueReturnToBattleOrigin(from: configuration.resumeToken)
            battle.endBattle()
        }
        return persisted
    }

    private func persistBattleProgress(
        for configuration: ActiveBattleConfiguration,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]?
    ) -> Bool {
        switch configuration.resumeToken {
        case let .journey(stageID):
            guard let stage = GameContent.stage(id: stageID) else {
                appStateLogger.error(
                    "Missing stage for resume token: \(stageID, privacy: .public)"
                )
                return false
            }
            guard let resultingJourney = persistStageCompletions(
                [stage],
                hero: hero,
                companion: companion,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards
            ) else {
                return false
            }
            noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: resultingJourney))
            return true
        case let .aspect(aspectID, floorNumber):
            guard let floor = GameContent.aspectFloor(aspectID: aspectID, floor: floorNumber) else {
                appStateLogger.error(
                    "Missing aspect floor for resume token: \(aspectID.rawValue, privacy: .public)/\(floorNumber)"
                )
                return false
            }
            return completeAspectFloor(
                floor,
                hero: hero,
                companion: companion,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: configuration.pendingRewardItem
            )
        case let .labyrinth(nodeID):
            return completeLabyrinthNode(
                nodeID: nodeID,
                hero: hero,
                companion: companion,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: configuration.pendingRewardItem
            )
        case .none:
            guard battleEarnedGold > 0 else { return true }
            return grantBattleEarnedGold(battleEarnedGold)
        }
    }

    @discardableResult
    func grantBattleEarnedGold(_ amount: Int) -> Bool {
        guard amount > 0 else { return true }
        do {
            try playerSave.performBatchMutation { save in
                save.roster.grantGold(amount)
            }
            return true
        } catch {
            appStateLogger.error(
                "Failed to persist battle gold: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
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
            companion: roster.activeCompanion,
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
        let companion = roster.companions.first(where: { $0.id == activeBattle.companion.combatant.id })
            ?? roster.activeCompanion

        activateBattle(
            resumeToken: activeBattle.resumeToken,
            hero: hero,
            companion: companion,
            enemy: activeBattle.enemy,
            enemyEncounterLevel: activeBattle.enemyEncounterLevel,
            stageReward: activeBattle.stageReward,
            experienceBonusPercent: activeBattle.experienceBonusPercent,
            pendingRewardItem: activeBattle.pendingRewardItem
        )
    }

    /// Clears preview, installs a fresh battle configuration, and syncs the tick loop.
    func activateBattle(
        resumeToken: ActiveBattleResumeToken? = nil,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        stageReward: StageReward?,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil
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
            companion: companion,
            rosterState: roster,
            inventoryState: inventory,
            homesteadState: homestead,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            experienceBonusPercent: experienceBonusPercent,
            pendingRewardItem: pendingRewardItem
        )
    }

    @discardableResult
    func handleStagePrimaryAction(for stage: Stage) -> StageMapMessage? {
        switch stage.encounter {
        case .battle:
            startBattle(for: stage)
        case .mysteryEvent:
            beginMysteryEncounter(for: stage)
        case .shop:
            beginShopEncounter(for: stage)
        case .event, .rest:
            completeStageOrPersistFailure(stage)
        }
    }

    /// Completes a stage, returning a save-failure message when persistence fails.
    func completeStageOrPersistFailure(_ stage: Stage) -> StageMapMessage? {
        guard completeStage(
            stage,
            hero: roster.activeHero,
            companion: roster.activeCompanion
        ) != nil else {
            return StageMapMessage(
                title: "Couldn't Save Progress",
                message: "This stage wasn't saved. Try again."
            )
        }
        return nil
    }

    /// Completes a Labyrinth node, returning a save-failure message when persistence fails.
    func completeLabyrinthNodeOrPersistFailure(nodeID: String) -> StageMapMessage? {
        guard completeLabyrinthNode(nodeID: nodeID) else {
            return StageMapMessage(
                title: "Couldn't Save Progress",
                message: "This path wasn't saved. Try again."
            )
        }
        return nil
    }

    @discardableResult
    func advanceToNextChapter() -> Bool {
        guard journey.pendingNextChapter() != nil else { return false }
        do {
            try playerSave.performBatchMutation { save in
                _ = save.journey.advanceToNextChapter()
            }
            noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: journey))
            return true
        } catch {
            appStateLogger.error(
                "Failed to advance chapter: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    @discardableResult
    func persistStageCompletions(
        _ stages: [Stage],
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        resetJourney: Bool = false
    ) -> JourneyProgressState? {
        guard !stages.isEmpty else { return nil }

        var resultingJourney = journey
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
                        companion: companion,
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
