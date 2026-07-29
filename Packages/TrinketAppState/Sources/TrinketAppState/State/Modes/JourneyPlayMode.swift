import Foundation
import Observation
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

/// Journey/campaign stage flow: primary actions, prepare/start battle, and stage victory.
@MainActor
@Observable
public final class JourneyPlayMode {
    private let playerSave: PlayerSaveStore
    private let battle: BattleSession
    private let battleLaunch: PlayBattleLaunch
    private let noteMapScrollFocus: (String) -> Void
    private var encounters: EncounterPlayMode?

    init(
        playerSave: PlayerSaveStore,
        battle: BattleSession,
        battleLaunch: PlayBattleLaunch,
        noteMapScrollFocus: @escaping (String) -> Void
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
        self.noteMapScrollFocus = noteMapScrollFocus
    }

    func bind(encounters: EncounterPlayMode) {
        self.encounters = encounters
    }

    private var boundEncounters: EncounterPlayMode {
        guard let encounters else {
            preconditionFailure("JourneyPlayMode used before encounters bind")
        }
        return encounters
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

    func persistVictory(
        for configuration: ActiveBattleConfiguration,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]?
    ) -> Bool {
        guard case let .journey(stageID) = configuration.resumeToken else { return false }
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
    }

    @discardableResult
    public func startBattle(for stage: Stage) -> StageMapMessage? {
        guard battle.activeBattle == nil else { return nil }

        guard let encounter = ActiveBattleConfiguration.resolvedEncounter(for: stage) else {
            return StageMapMessage(title: "Encounter Missing", message: "This stage is not ready yet.")
        }

        let roster = playerSave.roster
        let homestead = playerSave.homestead
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
        battleLaunch.activateBattle(
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
        let roster = playerSave.roster
        let homestead = playerSave.homestead
        guard battle.activeBattle == nil,
              let encounter = ActiveBattleConfiguration.resolvedEncounter(for: stage)
        else { return }
        let loot = ActiveBattleConfiguration.lootPackage(
            for: .journey(stageID: stage.id),
            enemy: encounter.combatant,
            encounterLevel: encounter.level,
            astralChanceBonusPercent: homestead.effects.astralChanceBonusPercent
        )
        let configuration = battleLaunch.makeBattleConfiguration(
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

    @discardableResult
    public func handleStagePrimaryAction(for stage: Stage) -> StageMapMessage? {
        let resolvedStage = resolvedCampaignStage(stage)
        return switch resolvedStage.encounter {
        case .battle, .randomBattle:
            startBattle(for: resolvedStage)
        case .mysteryEvent:
            boundEncounters.beginMysteryEncounter(for: resolvedStage)
        case .recruit:
            boundEncounters.beginMysteryEncounter(
                for: resolvedStage,
                forcedEventID: resolvedStage.encounter.recruitEventID
            )
        case .shop:
            boundEncounters.beginShopEncounter(for: resolvedStage)
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
