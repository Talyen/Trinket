import BattleEngine
import Foundation
import Observation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

/// Journey/campaign stage flow: map actions, prepare/start battle, and journey-unique victory writes.
@MainActor
@Observable
public final class JourneyPlayMode {
    private struct PreparationInputs: Equatable {
        let stageID: String
        let roster: PlayerRosterState
        let inventory: PlayerInventoryState
        let homestead: PlayerHomesteadState
        let stageRewardsAlreadyClaimed: Bool
    }

    public let playerSave: PlayerSaveStore
    public let battle: any BattleRuntime
    private let battleLaunch: PlayBattleLaunch
    private let encounters: EncounterPlayMode
    private var preparedInputs: PreparationInputs?

    init(
        playerSave: PlayerSaveStore,
        battle: any BattleRuntime,
        battleLaunch: PlayBattleLaunch,
        encounters: EncounterPlayMode
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
        self.encounters = encounters
    }

    public var playChapter: Chapter {
        GameContent.chapter(id: playerSave.journey.activeChapterID) ?? GameContent.chapters[0]
    }

    /// Completes a stage when persistence succeeds.
    @discardableResult
    func completeStage(
        _ stage: Stage,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil
    ) -> Bool {
        persistStageCompletions(
            [stage],
            hero: hero,
            companion: companion,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards,
            rewardItem: rewardItem
        )
    }

    public func resolvedEncounter(for stage: Stage) -> (combatant: Combatant, level: Int)? {
        Self.resolvedEncounter(for: stage)
    }

    @discardableResult
    public func startBattle(for stage: Stage) -> StageMapMessage? {
        guard battle.lifecyclePhase != .active else { return nil }

        guard let encounter = resolvedEncounter(for: stage) else {
            return StageMapMessage(title: "Encounter Missing", message: "This stage is not ready yet.")
        }

        let origin = PlayBattleOrigin.journey(stageID: stage.id)
        battleLaunch.activateCombat(
            origin: origin,
            encounter: encounter,
            route: battleRoute(stageID: stage.id),
            loot: battleLoot(for: stage, encounter: encounter),
            stageRewardsAlreadyClaimed: Self.stageRewardsAlreadyClaimed(
                for: stage,
                journey: playerSave.journey
            )
        )
        preparedInputs = nil
        return nil
    }

    public func prepareBattle(for stage: Stage) {
        guard battle.lifecyclePhase != .active,
              let encounter = resolvedEncounter(for: stage)
        else { return }
        let stageRewardsAlreadyClaimed = Self.stageRewardsAlreadyClaimed(
            for: stage,
            journey: playerSave.journey
        )
        let inputs = PreparationInputs(
            stageID: stage.id,
            roster: playerSave.roster,
            inventory: playerSave.inventory,
            homestead: playerSave.homestead,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed
        )
        guard inputs != preparedInputs else { return }
        let origin = PlayBattleOrigin.journey(stageID: stage.id)
        if battleLaunch.prepareCombat(
            origin: origin,
            encounter: encounter,
            route: battleRoute(stageID: stage.id),
            loot: battleLoot(for: stage, encounter: encounter),
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed
        ) {
            preparedInputs = inputs
        }
    }

    @discardableResult
    func beginMysteryEncounter(
        for stage: Stage,
        forcedEventID: String? = nil
    ) -> StageMapMessage? {
        encounters.beginMysteryEncounter(
            origin: .journey(stage: stage),
            forcedEventID: forcedEventID
        )
    }

    @discardableResult
    public func handleStagePrimaryAction(for stage: Stage) -> StageMapMessage? {
        let resolvedStage = resolvedCampaignStage(stage)
        switch resolvedStage.encounter {
        case .battle, .randomBattle:
            return startBattle(for: resolvedStage)
        case .mysteryEvent:
            return beginMysteryEncounter(for: resolvedStage)
        case .recruit:
            return beginMysteryEncounter(
                for: resolvedStage,
                forcedEventID: resolvedStage.encounter.recruitEventID
            )
        case .shop:
            switch encounters.beginShopEncounter(origin: .journey(stage: resolvedStage)) {
            case .autoCompleted:
                appStateLogger.error(
                    "Shop stage \(resolvedStage.id, privacy: .public) produced no offers; completing stage."
                )
                if let failure = completeStageOrPersistFailure(resolvedStage) {
                    return failure
                }
                return StageMapMessage(
                    title: "Shop Closed",
                    message: "The merchant has nothing left to sell. You continue on."
                )
            case .opened, .unavailable:
                return nil
            }
        case .event, .rest:
            return completeStageOrPersistFailure(resolvedStage)
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
        ) else {
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
    ) -> Bool {
        guard !stages.isEmpty else { return false }

        return playerSave.persistBatch(logging: "Failed to persist stage completions") { save in
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
        }
    }
}

extension JourneyPlayMode {
    static func resolvedEncounter(
        for stage: Stage
    ) -> (combatant: Combatant, level: Int)? {
        guard let enemyID = stage.resolvedBattleEnemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID),
              let chapter = GameContent.chapters.first(where: { $0.id == stage.chapterID })
        else { return nil }

        let level = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        return (CombatantLevelScaler.scale(enemy: catalogEnemy, level: level), level)
    }

    private func battleLoot(
        for stage: Stage,
        encounter: (combatant: Combatant, level: Int)
    ) -> BattleLootPackage? {
        Self.resolveBattleLoot(
            stage: stage,
            encounterLevel: encounter.level,
            enemyIsBoss: GameContent.enemy(matching: encounter.combatant.id)?.isBoss == true,
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent
        )
    }

    static func resolveBattleLoot(
        stage: Stage,
        encounterLevel: Int,
        enemyIsBoss: Bool,
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage? {
        guard stage.encounter.isCombat else { return nil }
        return BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            astralChanceBonusPercent: astralChanceBonusPercent
        )
    }

    static func stageRewardsAlreadyClaimed(
        for stage: Stage,
        journey: JourneyProgressState
    ) -> Bool {
        journey.hasClaimedRewards(for: stage)
    }

    func battleRoute(stageID: String) -> PlayBattleRoute {
        let origin = PlayBattleOrigin.journey(stageID: stageID)
        return PlayBattleRoute(origin: origin) { [weak self] configuration, presentation, battleEarnedGold, materialRewards in
            guard let self, let stage = GameContent.stage(id: stageID) else { return false }
            return completeStage(
                stage,
                hero: configuration.hero.combatant,
                companion: configuration.companion.combatant,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: presentation?.pendingRewardItem
            )
        }
    }
}
