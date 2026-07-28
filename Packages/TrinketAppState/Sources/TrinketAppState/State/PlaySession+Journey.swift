import BattleEngine
import Foundation
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

extension PlaySession {
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
    public func completeActiveBattle(
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
                materialRewards: materialRewards,
                rewardItem: configuration.pendingRewardItem
            ) else {
                return false
            }
            noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: resultingJourney))
            return true
        case let .spire(spireID, floorNumber):
            guard let floor = GameContent.spireFloor(spireID: spireID, floor: floorNumber) else {
                appStateLogger.error(
                    "Missing spire floor for resume token: \(spireID.rawValue, privacy: .public)/\(floorNumber)"
                )
                return false
            }
            return completeSpireFloor(
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

        if battle.activatePreparedJourneyBattle(
            stageID: stage.id,
            heroID: roster.activeHero.id,
            companionID: roster.activeCompanion.id,
            enemyID: encounter.combatant.id
        ) {
            return nil
        }

        let loot = ActiveBattleConfiguration.lootPackage(
            for: .journey(stageID: stage.id),
            enemy: encounter.combatant,
            encounterLevel: encounter.level,
            astralChanceBonusPercent: homestead.effects.astralChanceBonusPercent
        )
        activateBattle(
            resumeToken: .journey(stageID: stage.id),
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            pendingRewardItem: loot?.item
        )
        return nil
    }

    public func prepareBattle(for stage: Stage) {
        guard battle.activeBattle == nil,
              let encounter = ActiveBattleConfiguration.resolvedEncounter(for: stage)
        else { return }
        let loot = ActiveBattleConfiguration.lootPackage(
            for: .journey(stageID: stage.id),
            enemy: encounter.combatant,
            encounterLevel: encounter.level,
            astralChanceBonusPercent: homestead.effects.astralChanceBonusPercent
        )
        let configuration = makeBattleConfiguration(
            resumeToken: .journey(stageID: stage.id),
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            pendingRewardItem: loot?.item
        )
        battle.prepareBattleRun(configuration)
    }

    public func restartActiveBattle() {
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
            pendingRewardItem: activeBattle.pendingRewardItem,
            universalModifiers: activeBattle.universalModifiers
        )
    }

    /// Installs a fresh battle configuration and syncs the tick loop.
    func activateBattle(
        resumeToken: ActiveBattleResumeToken? = nil,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        stageReward: StageReward?,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        universalModifiers: [AffixModifier] = []
    ) {
        if let resumeToken,
           battle.activatePreparedBattle(
               resumeToken: resumeToken,
               heroID: hero.id,
               companionID: companion.id,
               enemyID: enemy?.id
           ) {
            return
        }
        battle.activeBattle = makeBattleConfiguration(
            resumeToken: resumeToken,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            experienceBonusPercent: experienceBonusPercent,
            pendingRewardItem: pendingRewardItem,
            universalModifiers: universalModifiers
        )
    }

    func makeBattleConfiguration(
        resumeToken: ActiveBattleResumeToken?,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        stageReward: StageReward?,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        universalModifiers: [AffixModifier] = []
    ) -> ActiveBattleConfiguration {
        let rngSeed = AppEnvironment.shared.battlePerformanceScenario == nil
            ? UInt64.random(in: UInt64.min ... UInt64.max)
            : BattlePerformanceFixture.seed
        return ActiveBattleConfiguration.make(
            resumeToken: resumeToken,
            rngSeed: rngSeed,
            hero: hero,
            companion: companion,
            rosterState: roster,
            inventoryState: inventory,
            homesteadState: homestead,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            experienceBonusPercent: experienceBonusPercent,
            pendingRewardItem: pendingRewardItem,
            universalModifiers: universalModifiers
        )
    }

    @discardableResult
    public func handleStagePrimaryAction(for stage: Stage) -> StageMapMessage? {
        let resolvedStage = resolvedCampaignStage(stage)
        return switch resolvedStage.encounter {
        case .battle, .randomBattle:
            startBattle(for: resolvedStage)
        case .mysteryEvent:
            beginMysteryEncounter(for: resolvedStage)
        case .recruit:
            beginMysteryEncounter(
                for: resolvedStage,
                forcedEventID: resolvedStage.encounter.recruitEventID
            )
        case .shop:
            beginShopEncounter(for: resolvedStage)
        case .event, .rest:
            completeStageOrPersistFailure(resolvedStage)
        }
    }

    func resolvedCampaignStage(_ stage: Stage) -> Stage {
        GameContent.resolveRecruitStage(
            stage,
            unlockedHeroIDs: roster.unlockedHeroIDs,
            unlockedCompanionIDs: roster.unlockedCompanionIDs
        )
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
    func persistStageCompletions(
        _ stages: [Stage],
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
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
                        rewardItem: isLast ? rewardItem : nil,
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
