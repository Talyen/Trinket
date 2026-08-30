import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
@Observable
public final class JourneyPlayMode {
    private struct PreparationInputs: Equatable {
        let stageID: String
        let party: PlayBattlePartySnapshot
        let stageRewardsAlreadyClaimed: Bool
    }

    public let playerSave: PlayerSaveStore
    public let battle: any BattleRuntime
    private let battleLaunch: PlayBattleLaunch
    private let encounters: EncounterPlayMode
    private var preparationTracker = PlayBattlePreparationTracker<PreparationInputs>()

    init(
        playerSave: PlayerSaveStore,
        battle: any BattleRuntime,
        battleLaunch: PlayBattleLaunch,
        encounters: EncounterPlayMode,
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
        self.encounters = encounters
    }

    public var playChapter: Chapter {
        GameContent.chapter(id: playerSave.journey.activeChapterID) ?? GameContent.chapters[0]
    }

    @discardableResult
    func completeStage(
        _ stage: Stage,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootPackage? = nil,
        enemyEncounterLevel: Int? = nil,
    ) -> Bool {
        persistStageCompletions(
            [stage],
            hero: hero,
            companion: companion,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards,
            rewardItem: rewardItem,
            loot: loot,
            enemyEncounterLevel: enemyEncounterLevel,
        )
    }

    public func resolvedEncounter(for stage: Stage) -> (combatant: Combatant, level: Int)? {
        Self.resolvedEncounter(
            for: stage,
            worldSeed: playerSave.worldSeed,
            partyAverageLevel: playerSave.roster.activePartyAverageLevel,
        )
    }

    @discardableResult
    public func startBattle(for stage: Stage) -> StageMapMessage? {
        guard encounters.canBeginTransientEncounter else { return nil }

        guard let encounter = resolvedEncounter(for: stage) else {
            return StageMapMessage(title: "Encounter Missing", message: "This stage is not ready yet.")
        }

        let request = combatRequest(for: stage, encounter: encounter)
        guard battle.lifecyclePhase != .active else { return PlayBattleLaunch.activationFailureMessage }
        let activated = battleLaunch.activateCombat(
            origin: request.origin,
            encounter: request.encounter,
            route: request.route,
            loot: request.loot,
            stageRewardsAlreadyClaimed: request.stageRewardsAlreadyClaimed,
            universalModifiers: request.universalModifiers,
            labyrinthModifiers: request.labyrinthModifiers,
        )
        if activated {
            preparationTracker.invalidate()
            return nil
        }
        return PlayBattleLaunch.activationFailureMessage
    }

    public func prepareBattle(for stage: Stage) {
        guard battle.lifecyclePhase != .active,
              let encounter = resolvedEncounter(for: stage)
        else { return }
        let request = combatRequest(for: stage, encounter: encounter)
        guard preparationTracker.shouldPrepare(
            for: request.preparationInputs,
            lifecycle: battle.lifecyclePhase,
            hasPreparedRun: battle.hasPreparedRun(request.origin.runKey),
        ) else { return }
        let prepared = battleLaunch.prepareCombat(
            origin: request.origin,
            encounter: request.encounter,
            route: request.route,
            loot: request.loot,
            stageRewardsAlreadyClaimed: request.stageRewardsAlreadyClaimed,
            universalModifiers: request.universalModifiers,
            labyrinthModifiers: request.labyrinthModifiers,
        )
        if prepared {
            preparationTracker.notePrepared(request.preparationInputs)
        }
    }

    @discardableResult
    func beginMysteryEncounter(
        for stage: Stage,
        forcedEventID: String? = nil,
    ) -> StageMapMessage? {
        encounters.beginMysteryEncounter(
            origin: .journey(stage: stage),
            forcedEventID: forcedEventID,
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
                forcedEventID: resolvedStage.encounter.recruitEventID,
            )
        case .shop:
            return PlayShopEncounterRouting.handle(
                encounters: encounters,
                origin: .journey(stage: resolvedStage),
                identifier: resolvedStage.id,
                onAutoComplete: { completeStageOrPersistFailure(resolvedStage) },
            )
        case .rest:
            return completeStageOrPersistFailure(resolvedStage)
        }
    }

    public func previewMysteryEvent(for stage: Stage) -> MysteryEvent? {
        let resolved = resolvedCampaignStage(stage)
        switch resolved.encounter {
        case .mysteryEvent:
            return encounters.previewMysteryEvent(origin: .journey(stage: resolved))
        case .recruit:
            return encounters.previewMysteryEvent(
                origin: .journey(stage: resolved),
                forcedEventID: resolved.encounter.recruitEventID,
            )
        default:
            return nil
        }
    }

    func resolvedCampaignStage(_ stage: Stage) -> Stage {
        let roster = playerSave.roster
        return GameContent.resolveRecruitStage(
            stage,
            worldSeed: playerSave.worldSeed,
            unlockedHeroIDs: roster.unlockedHeroIDs,
            unlockedCompanionIDs: roster.unlockedCompanionIDs,
        )
    }

    func completeStageOrPersistFailure(_ stage: Stage) -> StageMapMessage? {
        let roster = playerSave.roster
        guard completeStage(
            stage,
            hero: roster.activeHero,
            companion: roster.activeCompanion,
        ) else {
            return StageMapMessage(
                title: "Couldn't Save Progress",
                message: "This stage wasn't saved. Try again.",
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
        resetJourney: Bool = false,
        loot: BattleLootPackage? = nil,
        enemyEncounterLevel: Int? = nil,
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
                    loot: isLast ? loot : nil,
                    enemyEncounterLevel: enemyEncounterLevel,
                    in: GameContent.chapters,
                    save: &save,
                )
            }
        }
    }
}

extension JourneyPlayMode {
    static func resolvedEncounter(
        for stage: Stage,
        worldSeed: UInt64,
        partyAverageLevel: Int,
    ) -> (combatant: Combatant, level: Int)? {
        guard let chapter = GameContent.chapters.first(where: { $0.id == stage.chapterID })
        else { return nil }
        return PlayBattlePreparation.scaledEncounter(
            enemyID: stage.resolvedBattleEnemyID(worldSeed: worldSeed),
            authoredLevel: EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter),
            partyAverageLevel: partyAverageLevel,
        )
    }

    private func battleLoot(
        for stage: Stage,
        encounter: (combatant: Combatant, level: Int),
    ) -> BattleLootPackage? {
        guard stage.encounter.isCombat else { return nil }
        return BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: encounter.level,
            enemyIsBoss: GameContent.enemy(matching: encounter.combatant.id)?.isBoss == true,
            worldSeed: playerSave.worldSeed,
            ownedTrinketIDs: playerSave.inventory.ownedTrinketIDs,
            ownedUniqueIDs: playerSave.inventory.ownedUniqueIDs,
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent,
        )
    }

    static func stageRewardsAlreadyClaimed(
        for stage: Stage,
        journey: JourneyProgressState,
    ) -> Bool {
        journey.hasClaimedRewards(for: stage)
    }

    private struct CombatRequest {
        let origin: PlayBattleOrigin
        let encounter: (combatant: Combatant, level: Int)
        let route: PlayBattleRoute
        let loot: BattleLootPackage?
        let stageRewardsAlreadyClaimed: Bool
        let universalModifiers: [AffixModifier]
        let labyrinthModifiers: [LabyrinthModifierDefinition]
        let preparationInputs: PreparationInputs
    }

    private func combatRequest(
        for stage: Stage,
        encounter: (combatant: Combatant, level: Int),
    ) -> CombatRequest {
        let stageRewardsAlreadyClaimed = Self.stageRewardsAlreadyClaimed(
            for: stage,
            journey: playerSave.journey,
        )
        return CombatRequest(
            origin: .journey(stageID: stage.id),
            encounter: encounter,
            route: battleRoute(stageID: stage.id),
            loot: battleLoot(for: stage, encounter: encounter),
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            universalModifiers: [],
            labyrinthModifiers: [],
            preparationInputs: PreparationInputs(
                stageID: stage.id,
                party: PlayBattlePartySnapshot(playerSave: playerSave),
                stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            ),
        )
    }

    func battleRoute(stageID: String) -> PlayBattleRoute {
        let origin = PlayBattleOrigin.journey(stageID: stageID)
        return PlayBattleRoute(origin: origin) { [weak self] configuration, presentation, battleEarnedGold, materialRewards, loot in
            guard let self, let stage = GameContent.stage(id: stageID) else { return false }
            return completeStage(
                stage,
                hero: configuration.hero.combatant,
                companion: configuration.companion.combatant,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: presentation?.pendingRewardItem,
                loot: loot,
                enemyEncounterLevel: configuration.enemyEncounterLevel,
            )
        }
    }
}
