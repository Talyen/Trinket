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

        guard let encounter = StageEncounterResolver.resolve(for: stage) else {
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
            stageReward: stage.rewards,
            rewardItemNames: rewardItemNames(for: stage.rewards),
            catalog: GameContentCombatCatalog()
        )
        battle.notifyBattleStarted(stageID: stage.id)
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
            stageReward: activeBattle.stageReward,
            rewardItemNames: activeBattle.rewardItemNames,
            catalog: GameContentCombatCatalog()
        )
    }

    func retreatFromBattle() {
        battle.endBattle()
    }

    func setBattleMusicPreview(for stage: Stage?) {
        battle.setMusicPreview(for: stage)
    }

    func presentBattleCombatantDetail(_ detail: CombatantCardDetail) {
        battle.presentCombatantDetail(detail)
    }

    func restoreBattlePauseAfterOverlay() {
        battle.restorePauseAfterOverlay()
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

    private func rewardItemNames(for stageReward: StageReward) -> [String] {
        let catalog = GameContentPlayerCatalog()
        return stageReward.itemTemplateIDs.compactMap { templateID in
            catalog.itemTemplate(matching: templateID)?.displayName
        }
    }
}
