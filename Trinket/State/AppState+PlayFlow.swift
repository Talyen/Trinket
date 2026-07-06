import Foundation
import Observation
import TrinketContent

extension AppState {
    var journeyProgress: JourneyProgressState {
        journey.current
    }

    func noteMapScrollFocus(_ stageID: String) {
        sessionState.noteMapScrollFocus(stageID)
    }

    @discardableResult
    func startBattle(for stage: Stage) -> StageMapMessage? {
        PlayFlowCoordinator.startBattle(
            session: battle,
            stage: stage,
            roster: roster,
            inventory: inventory
        )
    }

    func restartActiveBattle() {
        PlayFlowCoordinator.restartBattle(
            session: battle,
            roster: roster,
            inventory: inventory
        )
    }

    func retreatFromBattle() {
        battle.endBattle()
    }

    func setBattleMusicPreview(for stage: Stage?) {
        battle.presentation.setMusicPreview(for: stage, battleIsActive: battle.activeBattle != nil)
    }

    func presentBattleCombatantDetail(_ detail: CombatantCardDetail) {
        battle.presentation.presentCombatantDetail(
            detail,
            battleIsActive: battle.activeBattle != nil
        )
    }

    func restoreBattlePauseAfterOverlay() {
        battle.presentation.restorePauseAfterOverlay(battleIsActive: battle.activeBattle != nil)
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
