import Foundation
import TrinketContent
import TrinketPersistence

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
        playerSave.performBatchMutation { save in
            save.roster = SavedRosterState(context.roster)
            save.inventory = SavedInventoryState(context.inventory)
            save.homestead = SavedHomesteadState(context.homestead)
            save.journey = context.journey
        }

        let scrollTarget = mapScrollFocusID(for: context.journey)
        journey.requestMapScroll(to: scrollTarget)
        return scrollTarget
    }

    func completeActiveBattle(_ configuration: ActiveBattleConfiguration, battleEarnedGold: Int) {
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
