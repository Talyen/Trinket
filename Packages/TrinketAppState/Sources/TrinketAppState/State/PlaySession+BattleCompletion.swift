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

    private struct PendingExit {
        let configurationID: UUID
        let origin: PlayBattleOrigin?
        let onFinished: () -> Void
        let restoreOrigin: (PlayBattleOrigin?) -> Void
    }

    private var pendingExit: PendingExit?

    init(playerSave: PlayerSaveStore, battle: any BattleRuntime) {
        self.playerSave = playerSave
        self.battle = battle
    }

    func finishPresentation(configurationID: UUID) {
        guard let pendingExit, pendingExit.configurationID == configurationID else { return }
        self.pendingExit = nil
        guard battle.activeBattle?.id == configurationID else { return }
        pendingExit.restoreOrigin(pendingExit.origin)
        battle.endBattle()
        pendingExit.onFinished()
    }

    func cancelPendingExit() {
        pendingExit = nil
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
        guard pendingExit?.configurationID != configuration.id else { return .unavailable }
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

        let resolved = settleRewards(
            configuration, battleGold: battleGold, materialRewards: materialRewards, presentation: presentation,
            at: settlement?.inputs.productionDate ?? Date(),
        )
        guard settlement == nil || settlement == resolved else { return .staleSettlement(resolved) }
        let origin = route?.origin
        let loot = Self.preparedLoot(
            from: presentation,
            materialRewards: materialRewards,
        )
        let result: BattleCompletionResult = if let route, let presentation {
            route.complete(
                configuration,
                presentation,
                settlement ?? resolved,
                materialRewards,
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
