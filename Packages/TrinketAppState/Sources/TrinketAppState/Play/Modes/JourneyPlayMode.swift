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
    private let battleCoordinator: PlayBattleCoordinator
    private let encounters: EncounterPlayMode

    init(
        playerSave: PlayerSaveStore,
        battle: any BattleRuntime,
        battleCoordinator: PlayBattleCoordinator,
        encounters: EncounterPlayMode,
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleCoordinator = battleCoordinator
        self.encounters = encounters
    }

    public var playChapter: Chapter {
        GameContent.chapter(id: playerSave.journey.activeChapterID) ?? GameContent.chapters[0]
    }

    public func resolvedEncounter(for stage: Stage) -> ScaledEncounter? {
        PlayBattlePreparation.journeyEncounter(
            for: stage,
            worldSeed: playerSave.worldSeed,
            partyAverageLevel: playerSave.roster.activePartyAverageLevel,
        )
    }

    @discardableResult
    public func startBattle(for stage: Stage) -> StageMapMessage? {
        // No access pre-check here: PlayBattleCoordinator.startBattle owns the
        // gate and returns the restriction first.
        battleCoordinator.startBattle(
            origin: .journey(stageID: stage.id),
            encounters: encounters,
            busyMessage: nil, // Map taps swallow a busy battle.
            resolve: {
                guard let encounter = resolvedEncounter(for: stage) else { return .missing }
                let request = combatRequest(for: stage, encounter: encounter)
                return .ready(input: request.input, route: request.route)
            },
        )
    }

    public func prepareBattle(for stage: Stage) {
        guard playerSave.accessRestriction(for: .journey(stageID: stage.id)) == nil else { return }
        guard battle.lifecyclePhase != .active,
              let encounter = resolvedEncounter(for: stage)
        else { return }
        let request = combatRequest(for: stage, encounter: encounter)
        battleCoordinator.prepareCombat(request.input, route: request.route)
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
            )
        }
    }

    public func previewMysteryEvent(for stage: Stage) -> MysteryEvent? {
        previewMysteryEvent(for: stage, save: playerSave.currentSave)
    }

    /// Preview against an incoming save before CloudKit publishes it. This
    /// uses the same deterministic event inputs as the live encounter path.
    public func previewMysteryEvent(for stage: Stage, save: PlayerSave) -> MysteryEvent? {
        let resolved = resolvedCampaignStage(stage, save: save)
        switch resolved.encounter {
        case .mysteryEvent, .recruit:
            return MysteryEncounterSession.resolveEvent(
                origin: .journey(stage: resolved),
                forcedEventID: resolved.encounter.recruitEventID,
                worldSeed: save.worldSeed,
                pickContext: .journey(
                    chapterNumber: resolved.chapterNumber,
                    inventory: save.inventory,
                    corruptionAltarCooldownRemaining: save.corruptionAltarCooldownRemaining,
                ),
                pinnedJourneyEventID: save.journey.pinnedMysteryEventIDs[resolved.id],
            )
        default:
            return nil
        }
    }

    func resolvedCampaignStage(_ stage: Stage) -> Stage {
        resolvedCampaignStage(stage, save: playerSave.currentSave)
    }

    private func resolvedCampaignStage(_ stage: Stage, save: PlayerSave) -> Stage {
        let roster = save.roster
        return GameContent.resolveRecruitStage(
            stage,
            worldSeed: save.worldSeed,
            unlockedHeroIDs: roster.unlockedHeroIDs,
            unlockedCompanionIDs: roster.unlockedCompanionIDs,
            access: playerSave.contentAccess,
        )
    }
}

extension JourneyPlayMode {
    private func battleLoot(
        for stage: Stage,
        encounter: ScaledEncounter,
    ) -> BattleLootResult {
        let loot = BattleLootContext(playerSave: playerSave)
        return StageCompletion.resolveLoot(
            for: stage,
            encounterLevel: encounter.level,
            enemyIsBoss: VictoryRewardApplier.isBoss(enemyID: encounter.combatant.id),
            worldSeed: loot.worldSeed,
            ownedTrinketIDs: loot.ownedTrinketIDs,
            ownedUniqueIDs: loot.ownedUniqueIDs,
            astralChanceBonusPercent: loot.astralChanceBonusPercent,
        )
    }

    private func combatRequest(
        for stage: Stage,
        encounter: ScaledEncounter,
    ) -> (input: BattleLaunchInput, route: PlayBattleRoute) {
        let loot = battleLoot(for: stage, encounter: encounter)
        let input = ModeBattleSpec.launchInput(
            origin: .journey(stageID: stage.id),
            encounter: encounter,
            loot: loot,
            roster: playerSave.roster,
            stageRewardsAlreadyClaimed: playerSave.journey.hasClaimedRewards(for: stage),
        )
        return (input, .journey(stage))
    }
}
