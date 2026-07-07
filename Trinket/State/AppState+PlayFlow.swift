import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    var journeyProgress: JourneyProgressState {
        journey.current
    }

    func noteMapScrollFocus(_ stageID: String) {
        sessionState.noteMapScrollFocus(stageID)
    }

    @discardableResult
    func startBattle(for stage: Stage) -> StageMapMessage? {
        guard battle.activeBattle == nil else { return nil }

        guard let encounter = ActiveBattleConfiguration.resolvedEncounter(for: stage) else {
            return StageMapMessage(title: "Encounter Missing", message: "This stage is not ready yet.")
        }

        battle.preview = nil
        battle.activeBattle = ActiveBattleConfiguration.make(
            stageID: stage.id,
            rngSeed: UInt64.random(in: UInt64.min ... UInt64.max),
            hero: roster.activeHero,
            pet: roster.activePet,
            roster: roster,
            inventory: inventory,
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

        battle.activeBattle = ActiveBattleConfiguration.make(
            stageID: activeBattle.stageID,
            rngSeed: UInt64.random(in: UInt64.min ... UInt64.max),
            hero: hero,
            pet: pet,
            roster: roster,
            inventory: inventory,
            enemy: activeBattle.enemy,
            enemyEncounterLevel: activeBattle.enemyEncounterLevel,
            stageReward: activeBattle.stageReward
        )
        syncBattleTickLoop()
    }

    @discardableResult
    func handleStagePrimaryAction(for stage: Stage) -> StageMapMessage? {
        switch stage.encounter {
        case .battle:
            return startBattle(for: stage)
        case .event, .shop, .rest, .mysteryEvent:
            completeStage(stage, hero: roster.activeHero, pet: roster.activePet)
            return nil
        }
    }
}
