import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
final class PlayBattleCompletion {
    let playerSave: PlayerSaveStore
    let battle: any BattleRuntime
    private let runs: PlayBattleRuns

    private struct PendingExit {
        let configurationID: UUID
        let origin: PlayBattleOrigin?
        let onFinished: () -> Void
        let restoreOrigin: (PlayBattleOrigin?) -> Void
    }

    private var pendingExit: PendingExit?
    var deferredDefeatTalentProgressions: [String: CombatantProgression] = [:]
    var claimedDefeat: (configurationID: UUID, settlement: BattleRewardSettlement)?

    init(playerSave: PlayerSaveStore, battle: any BattleRuntime, runs: PlayBattleRuns) {
        self.playerSave = playerSave
        self.battle = battle
        self.runs = runs
    }

    func finishPresentation(configurationID: UUID) {
        guard let pendingExit, pendingExit.configurationID == configurationID else { return }
        self.pendingExit = nil
        guard battle.activeBattle?.id == configurationID else { return }
        pendingExit.restoreOrigin(pendingExit.origin)
        runs.endBattle()
        pendingExit.onFinished()
    }

    func cancelPendingExit() {
        pendingExit = nil
        claimedDefeat = nil
        deferredDefeatTalentProgressions.removeAll()
    }

    @discardableResult
    func completeActiveBattle(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards: [ResourceAmount]? = nil,
        settlement: BattleRewardSettlement? = nil,
        route: PlayBattleRoute?,
        presentation: BattlePresentationContext?,
        defersPresentationExit: Bool,
        onFinished: @escaping () -> Void,
        restoreOrigin: @escaping (PlayBattleOrigin?) -> Void,
    ) -> BattleCompletionResult {
        // Fail closed while any presentation exit is pending. Same-ID calls
        // are duplicate claims; a different ID would overwrite the pending
        // onFinished/restoreOrigin and leak the first battle's exit.
        guard pendingExit == nil else { return .unavailable }
        guard battle.lifecyclePhase == .active, battle.activeBattle?.id == configuration.id else { return .unavailable }

        guard PlayBattleRoute.matches(
            route,
            runKey: configuration.runKey,
            missingLog: "Missing route for active battle completion",
        ) else {
            return .unavailable
        }

        guard route == nil || presentation != nil else {
            appStateLogger.error("Missing presentation metadata for active battle completion")
            return .unavailable
        }

        // A settled award already includes material bonuses. With a supplied
        // settlement, validate against the launch plan's unadjusted materials.
        let baseMaterials = settlement == nil ? materialRewards : nil
        let resolved = settleRewards(
            configuration, battleGold: battleGold, materialRewards: baseMaterials, presentation: presentation,
            at: settlement?.inputs.productionDate ?? Date(),
        )
        guard settlement == nil || settlement == resolved else { return .staleSettlement(resolved) }
        let origin = route?.origin
        let loot = Self.preparedLoot(
            from: presentation,
            materialRewards: baseMaterials,
        )
        let result: BattleCompletionResult = if let route, let presentation {
            route.complete(
                configuration,
                presentation,
                settlement ?? resolved,
                baseMaterials,
                loot,
            )
        } else {
            playerSave.persistBatch(logging: "Failed to persist battle rewards") { save in
                VictoryRewardApplier.apply(
                    resolved,
                    hero: configuration.hero.combatant,
                    companion: configuration.companion.combatant,
                    save: &save,
                )
            } ? .completed : .persistenceFailed
        }
        if result.didComplete {
            pendingExit = PendingExit(
                configurationID: configuration.id, origin: origin,
                onFinished: onFinished, restoreOrigin: restoreOrigin,
            )
            if !defersPresentationExit {
                finishPresentation(configurationID: configuration.id)
            }
        }
        return result
    }

    static func preparedLoot(
        from presentation: BattlePresentationContext?,
        materialRewards: [ResourceAmount]?,
    ) -> BattleLootResult? {
        guard let presentation, let item = presentation.pendingRewardItem else { return nil }
        return BattleLootResult(
            item: item,
            gold: presentation.stageReward?.gold ?? 0,
            materials: materialRewards ?? presentation.materialRewards,
        )
    }

    func settleRewards(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards: [ResourceAmount]? = nil,
        presentation: BattlePresentationContext?,
        at date: Date = Date(),
    ) -> BattleRewardSettlement {
        let plan = presentation?.rewardPlan ?? BattleRewardPlan(
            stageGold: 0, goldFindPercent: 0,
            goldOverflowExperience: RewardExperiencePolicy.encounterAward(
                encounterLevel: configuration.enemyEncounterLevel ?? configuration.hero.progression.level,
                roster: playerSave.roster,
            ),
            heroExperience: 0, companionExperience: 0, materials: [], items: [],
        )
        return plan.settle(
            battleGold: battleGold,
            inputs: RewardSettlementInputs(
                save: playerSave.currentSave, hero: configuration.hero.combatant, companion: configuration.companion.combatant, at: date,
            ),
            materials: materialRewards,
        )
    }
}
