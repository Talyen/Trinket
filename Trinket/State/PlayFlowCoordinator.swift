import Foundation
import os
import TrinketContent
import TrinketPersistence

private let playFlowLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "PlayFlow"
)

extension AppState {
    var playChapter: Chapter {
        GameContent.chapter(id: journey.current.activeChapterID) ?? GameContent.chapters[0]
    }

    @discardableResult
    func completeStage(
        _ stage: Stage,
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0
    ) -> String {
        var scrollTarget = JourneyMapPresentation.scrollFocusID(for: journey.current)
        do {
            try playerSave.performBatchMutation { save in
                var context = save.stageCompletionContext()
                StageCompletion.complete(
                    stage,
                    hero: hero,
                    pet: pet,
                    battleEarnedGold: battleEarnedGold,
                    in: GameContent.chapters,
                    context: &context
                )
                context.apply(to: &save)
                scrollTarget = JourneyMapPresentation.scrollFocusID(for: context.journey)
            }
            lastPlayFlowError = nil
            sessionState.mapScrollStageID = scrollTarget
            journey.requestMapScroll(to: scrollTarget)
        } catch {
            playFlowLogger.error(
                "Failed to persist stage completion: \(error.localizedDescription, privacy: .public)"
            )
            lastPlayFlowError = "Progress couldn't be saved. Try again."
        }
        return scrollTarget
    }

    func completeActiveBattle(_ configuration: ActiveBattleConfiguration, battleEarnedGold: Int) {
        guard battle.activeBattle != nil else { return }

        if let stageID = configuration.stageID,
           let stage = GameContent.stage(id: stageID) {
            completeStage(stage, hero: configuration.hero, pet: configuration.pet, battleEarnedGold: battleEarnedGold)
        } else if battleEarnedGold > 0 {
            roster.grantGold(battleEarnedGold)
        }
        battle.endBattle()
    }
}
