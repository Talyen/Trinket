import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
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

    /// Persists victory rewards and ends the battle only when persistence succeeds.
    @discardableResult
    func completeActiveBattle(
        _ configuration: ActiveBattleConfiguration,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]? = nil
    ) -> Bool {
        guard battle.activeBattle != nil else { return false }

        let hero = configuration.hero.combatant
        let pet = configuration.pet.combatant
        let persisted: Bool
        switch configuration.resumeToken {
        case let .journey(stageID):
            if let stage = GameContent.stage(id: stageID) {
                if let resultingJourney = persistStageCompletions(
                    [stage],
                    hero: hero,
                    pet: pet,
                    battleEarnedGold: battleEarnedGold,
                    materialRewards: materialRewards
                ) {
                    noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: resultingJourney))
                    persisted = true
                } else {
                    persisted = false
                }
            } else {
                persisted = true
            }
        case let .aspect(aspectID, floorNumber):
            if let floor = GameContent.aspectFloor(aspectID: aspectID, floor: floorNumber) {
                persisted = completeAspectFloor(
                    floor,
                    hero: hero,
                    pet: pet,
                    battleEarnedGold: battleEarnedGold,
                    materialRewards: materialRewards,
                    rewardItem: configuration.pendingRewardItem
                )
            } else {
                persisted = true
            }
        case let .labyrinth(nodeID):
            persisted = completeLabyrinthNode(
                nodeID: nodeID,
                hero: hero,
                pet: pet,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards
            )
        case .none:
            if battleEarnedGold > 0 {
                persisted = grantBattleEarnedGold(battleEarnedGold)
            } else {
                persisted = true
            }
        }

        if persisted {
            queueReturnToBattleOrigin(from: configuration.resumeToken)
            battle.endBattle()
        }
        return persisted
    }

    @discardableResult
    func grantBattleEarnedGold(_ amount: Int) -> Bool {
        guard amount > 0 else { return true }
        do {
            try playerSave.performBatchMutation { save in
                save.roster.gold += amount
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
    func advanceToNextChapter() -> Bool {
        guard journey.current.pendingNextChapter() != nil else { return false }
        do {
            try playerSave.performBatchMutation { save in
                _ = save.journey.advanceToNextChapter()
            }
            noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: journey.current))
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
