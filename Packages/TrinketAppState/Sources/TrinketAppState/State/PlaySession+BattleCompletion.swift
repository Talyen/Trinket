import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
struct PlayBattleCompletion {
    let playerSave: PlayerSaveStore
    let battle: any BattleRuntime

    @discardableResult
    func completeActiveBattle(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards: [ResourceAmount]? = nil,
        settlement: BattleRewardSettlement? = nil,
        route: PlayBattleRoute?,
        presentation: BattlePresentationContext?,
        onPersisted: () -> Void,
        queueReturnToOrigin: (PlayBattleOrigin?) -> Void,
    ) -> Bool {
        guard battle.lifecyclePhase == .active, battle.activeBattle?.id == configuration.id else { return false }

        guard PlayBattleRoute.matches(
            route,
            runKey: configuration.runKey,
            missingLog: "Missing route for active battle completion",
        ) else {
            return false
        }

        guard route == nil || presentation != nil else {
            appStateLogger.error("Missing presentation metadata for active battle completion")
            return false
        }

        let resolved = settleRewards(
            configuration, battleGold: battleGold, materialRewards: materialRewards, presentation: presentation,
            at: settlement?.inputs.productionDate ?? Date(),
        )
        guard settlement == nil || settlement == resolved else { return false }
        let origin = route?.origin
        let loot = Self.preparedLoot(
            from: presentation,
            materialRewards: materialRewards,
        )
        let persisted = if let route, let presentation {
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
            }
        }
        if persisted {
            onPersisted()
            queueReturnToOrigin(origin)
            battle.endBattle()
        }
        return persisted
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
