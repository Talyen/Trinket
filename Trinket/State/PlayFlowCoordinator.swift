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
        var context = StageCompletionContext(
            roster: roster.current,
            inventory: inventory.current,
            homestead: homestead.current,
            journey: journey.current
        )
        StageCompletion.complete(
            stage,
            hero: hero,
            pet: pet,
            battleEarnedGold: battleEarnedGold,
            in: GameContent.chapters,
            context: &context
        )
        do {
            try playerSave.performBatchMutation { save in
                save.roster = SavedRosterState(context.roster)
                save.inventory = SavedInventoryState(context.inventory)
                save.homestead = SavedHomesteadState(context.homestead)
                save.journey = context.journey
            }
        } catch {
            playFlowLogger.error(
                "Failed to persist stage completion: \(error.localizedDescription, privacy: .public)"
            )
        }

        let scrollTarget = mapScrollFocusID(for: context.journey)
        sessionState.mapScrollStageID = scrollTarget
        journey.requestMapScroll(to: scrollTarget)
        return scrollTarget
    }

    func completeActiveBattle(_ configuration: ActiveBattleConfiguration, battleEarnedGold: Int) {
        guard battle.activeBattle != nil else { return }

        if let stageID = configuration.stageID,
           let stage = GameContent.chapters.flatMap(\.stages).first(where: { $0.id == stageID }) {
            completeStage(stage, hero: configuration.hero, pet: configuration.pet, battleEarnedGold: battleEarnedGold)
        } else if battleEarnedGold > 0 {
            roster.grantGold(battleEarnedGold)
        }
        battle.endBattle()
    }

    func mapScrollFocusID(for progress: JourneyProgressState) -> String {
        if let activeStageID = progress.activeStageID {
            return activeStageID
        }

        let chapter = GameContent.chapter(id: progress.activeChapterID) ?? GameContent.chapters[0]
        let gateChapter = GameContent.nextChapter(after: chapter) ?? placeholderGateChapter(after: chapter)
        return StageMapID.chapterGate(for: gateChapter)
    }

    private func placeholderGateChapter(after chapter: Chapter) -> Chapter {
        let nextNumber = chapter.number + 1
        return Chapter(
            id: StageMapID.placeholderGate(afterChapterNumber: nextNumber),
            number: nextNumber,
            title: "",
            theme: chapter.theme,
            stages: []
        )
    }
}
