import Foundation
import Observation
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

/// Journey/campaign stage flow: map actions, prepare/start battle, and journey-unique victory writes.
@MainActor
@Observable
public final class JourneyPlayMode {
    private let playerSave: PlayerSaveStore
    private let battle: BattleSession
    private let battleLaunch: PlayBattleLaunch
    private let noteMapScrollFocus: (String) -> Void
    private let encounters: EncounterPlayMode

    init(
        playerSave: PlayerSaveStore,
        battle: BattleSession,
        battleLaunch: PlayBattleLaunch,
        noteMapScrollFocus: @escaping (String) -> Void,
        encounters: EncounterPlayMode
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
        self.noteMapScrollFocus = noteMapScrollFocus
        self.encounters = encounters
    }

    public var playChapter: Chapter {
        GameContent.chapter(id: playerSave.journey.activeChapterID) ?? GameContent.chapters[0]
    }

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

    /// Journey-unique victory write + map-scroll focus. Token resolution lives on `PlayBattleCompletion`.
    func applyBattleVictory(
        stage: Stage,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]?,
        rewardItem: InventoryItem?
    ) -> Bool {
        guard let resultingJourney = persistStageCompletions(
            [stage],
            hero: hero,
            companion: companion,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards,
            rewardItem: rewardItem
        ) else {
            return false
        }
        noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: resultingJourney))
        return true
    }

    public func resolvedEncounter(for stage: Stage) -> (combatant: Combatant, level: Int)? {
        PlayBattleLaunch.resolvedEncounter(for: stage)
    }

    @discardableResult
    public func startBattle(for stage: Stage) -> StageMapMessage? {
        guard battle.activeBattle == nil else { return nil }

        guard let encounter = resolvedEncounter(for: stage) else {
            return StageMapMessage(title: "Encounter Missing", message: "This stage is not ready yet.")
        }

        let roster = playerSave.roster
        let origin = PlayBattleOrigin.journey(stageID: stage.id)
        if battle.activatePreparedBattle(
            runKey: origin.runKey,
            heroID: roster.activeHero.id,
            companionID: roster.activeCompanion.id,
            enemyID: encounter.combatant.id
        ) {
            return nil
        }

        battleLaunch.activateCombat(
            origin: origin,
            encounter: encounter
        )
        return nil
    }

    public func prepareBattle(for stage: Stage) {
        guard battle.activeBattle == nil,
              let encounter = resolvedEncounter(for: stage)
        else { return }
        battleLaunch.prepareCombat(
            origin: .journey(stageID: stage.id),
            encounter: encounter
        )
    }

    @discardableResult
    public func handleStagePrimaryAction(for stage: Stage) -> StageMapMessage? {
        let resolvedStage = resolvedCampaignStage(stage)
        return switch resolvedStage.encounter {
        case .battle, .randomBattle:
            startBattle(for: resolvedStage)
        case .mysteryEvent:
            encounters.beginMysteryEncounter(for: resolvedStage)
        case .recruit:
            encounters.beginMysteryEncounter(
                for: resolvedStage,
                forcedEventID: resolvedStage.encounter.recruitEventID
            )
        case .shop:
            encounters.beginShopEncounter(for: resolvedStage)
        case .event, .rest:
            completeStageOrPersistFailure(resolvedStage)
        }
    }

    func resolvedCampaignStage(_ stage: Stage) -> Stage {
        let roster = playerSave.roster
        return GameContent.resolveRecruitStage(
            stage,
            unlockedHeroIDs: roster.unlockedHeroIDs,
            unlockedCompanionIDs: roster.unlockedCompanionIDs
        )
    }

    /// Completes a stage, returning a save-failure message when persistence fails.
    func completeStageOrPersistFailure(_ stage: Stage) -> StageMapMessage? {
        let roster = playerSave.roster
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

        var resultingJourney = playerSave.journey
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
