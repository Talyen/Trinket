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
    public let playerSave: PlayerSaveStore
    public let battle: any BattleRuntime
    private let battleLaunch: PlayBattleLaunch
    private let encounters: EncounterPlayMode
    private var preparationTracker = PlayBattlePreparationTracker<SingleBattlePreparationInputs>()

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
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardSettlement? = nil,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootResult? = nil,
        enemyEncounterLevel: Int? = nil,
    ) -> Bool {
        persistStageCompletions(
            [stage],
            hero: hero,
            companion: companion,
            battleGold: battleGold,
            award: award,
            materialRewards: materialRewards,
            rewardItem: rewardItem,
            loot: loot,
            enemyEncounterLevel: enemyEncounterLevel,
        )
    }

    public func resolvedEncounter(for stage: Stage) -> ScaledEncounter? {
        Self.resolvedEncounter(
            for: stage,
            worldSeed: playerSave.worldSeed,
            partyAverageLevel: playerSave.roster.activePartyAverageLevel,
        )
    }

    @discardableResult
    public func startBattle(for stage: Stage) -> StageMapMessage? {
        // No access pre-check here: PlayBattleLaunch.startBattle owns the gate
        // and returns the restriction first.
        battleLaunch.startBattle(
            origin: .journey(stageID: stage.id),
            encounters: encounters,
            busyMessage: nil, // Map taps swallow a busy battle.
            resolve: {
                guard let encounter = resolvedEncounter(for: stage) else { return nil }
                return combatRequest(for: stage, encounter: encounter)
            },
            onActivated: { preparationTracker.invalidate() },
        )
    }

    public func prepareBattle(for stage: Stage) {
        guard playerSave.accessRestriction(for: .journey(stageID: stage.id)) == nil else { return }
        guard battle.lifecyclePhase != .active,
              let encounter = resolvedEncounter(for: stage)
        else { return }
        battleLaunch.prepareSingleBattle(
            tracker: &preparationTracker,
            origin: .journey(stageID: stage.id),
            stageRewardsAlreadyClaimed: Self.stageRewardsAlreadyClaimed(
                for: stage,
                journey: playerSave.journey,
            ),
            party: PlayBattlePartySnapshot(playerSave: playerSave),
            makeRequest: { combatRequest(for: stage, encounter: encounter) },
        )
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
        // No access pre-check here: every branch below re-checks through the
        // same rules (startBattle / beginMysteryEncounter / beginShopOrAutoComplete).
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
            return encounters.beginShopOrAutoComplete(
                origin: .journey(stage: resolvedStage),
                identifier: resolvedStage.id,
                onAutoComplete: { self.completeStageOrPersistFailure(resolvedStage) },
            )
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
            access: playerSave.contentAccess,
        )
    }

    func completeStageOrPersistFailure(_ stage: Stage) -> StageMapMessage? {
        let roster = playerSave.roster
        guard completeStage(
            stage,
            hero: roster.activeHero,
            companion: roster.activeCompanion,
        ) else {
            playerSave.retrySaveAction(key: SaveRetryKey.stage(stage.id)) { [weak self] in
                _ = self?.completeStageOrPersistFailure(stage)
            }
            return nil
        }
        return nil
    }

    @discardableResult
    func persistStageCompletions(
        _ stages: [Stage],
        hero: Combatant,
        companion: Combatant,
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardSettlement? = nil,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        resetJourney: Bool = false,
        loot: BattleLootResult? = nil,
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
                    battleGold: isLast ? battleGold : .init(),
                    award: isLast ? award : nil,
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
    ) -> ScaledEncounter? {
        PlayBattlePreparation.journeyEncounter(
            for: stage,
            worldSeed: worldSeed,
            partyAverageLevel: partyAverageLevel,
        )
    }

    private func battleLoot(
        for stage: Stage,
        encounter: ScaledEncounter,
    ) -> BattleLootResult {
        StageCompletion.resolveLoot(
            for: stage,
            encounterLevel: encounter.level,
            enemyIsBoss: VictoryRewardApplier.isBoss(enemyID: encounter.combatant.id),
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

    private func combatRequest(
        for stage: Stage,
        encounter: ScaledEncounter,
    ) -> PlayCombatRequest {
        let stageRewardsAlreadyClaimed = Self.stageRewardsAlreadyClaimed(
            for: stage,
            journey: playerSave.journey,
        )
        return PlayCombatRequest(
            origin: .journey(stageID: stage.id),
            encounter: encounter,
            route: battleRoute(stage: stage),
            loot: battleLoot(for: stage, encounter: encounter),
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
        )
    }

    func battleRoute(stage: Stage) -> PlayBattleRoute {
        let origin = PlayBattleOrigin.journey(stageID: stage.id)
        return PlayBattleRoute(origin: origin) { [weak self] configuration, presentation, award, materialRewards, loot in
            guard let self else { return .unavailable }
            let transaction = playerSave.persistTransaction(logging: "Failed to persist stage completion") { save -> Result<
                EncounterCompletion,
                PlayCompletionFailure,
            > in
                switch StageCompletion.complete(
                    stage,
                    hero: configuration.hero.combatant,
                    companion: configuration.companion.combatant,
                    battleGold: award.award.goldFlow,
                    award: award,
                    materialRewards: materialRewards,
                    rewardItem: presentation?.pendingRewardItem,
                    loot: loot,
                    enemyEncounterLevel: configuration.enemyEncounterLevel,
                    in: GameContent.chapters,
                    save: &save,
                ) {
                case .completed: return .success(.completed)
                case .alreadyCompleted, .unavailable: return .failure(.unavailable)
                }
            }
            return PlayBattleRoute.completionResult(transaction)
        }
    }
}
