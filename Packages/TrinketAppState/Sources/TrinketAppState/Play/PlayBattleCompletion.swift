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

    private enum ClaimState {
        case unclaimed
        case defeat(configurationID: UUID)
        case victory(PendingExit)
    }

    private var claimState: ClaimState = .unclaimed
    private var talentProgressionsBefore: [String: CombatantProgression] = [:]

    init(playerSave: PlayerSaveStore, battle: any BattleRuntime, runs: PlayBattleRuns) {
        self.playerSave = playerSave
        self.battle = battle
        self.runs = runs
    }

    func finishPresentation(configurationID: UUID) {
        guard case let .victory(pendingExit) = claimState,
              pendingExit.configurationID == configurationID else { return }
        claimState = .unclaimed
        guard battle.activeBattle?.id == configurationID else { return }
        pendingExit.restoreOrigin(pendingExit.origin)
        runs.endBattle()
        pendingExit.onFinished()
    }

    func reset() {
        claimState = .unclaimed
        talentProgressionsBefore.removeAll()
    }

    func takeTalentProgressions() -> [String: CombatantProgression] {
        defer { talentProgressionsBefore.removeAll() }
        return talentProgressionsBefore
    }

    private func recordTalentProgressions(
        _ settlement: BattleRewardSettlement,
        configuration: BattleRunConfiguration,
    ) {
        // Retain the earliest baseline across Retry attempts, so Talent points
        // earned on a previous defeat remain visible when the player exits.
        for (id, before) in [
            configuration.hero.combatant.id: settlement.inputs.heroProgression,
            configuration.companion.combatant.id: settlement.inputs.companionProgression,
        ] where talentProgressionsBefore[id] == nil {
            talentProgressionsBefore[id] = before
        }
    }

    private func canClaimVictory(configurationID: UUID) -> Bool {
        switch claimState {
        case .unclaimed: true
        case let .defeat(claimedID): claimedID != configurationID
        case .victory: false
        }
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
        guard canClaimVictory(configurationID: configuration.id) else { return .unavailable }
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
            recordTalentProgressions(settlement ?? resolved, configuration: configuration)
            claimState = .victory(PendingExit(
                configurationID: configuration.id, origin: origin,
                onFinished: onFinished, restoreOrigin: restoreOrigin,
            ))
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

    func settleDefeat(
        _ configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext,
        at date: Date,
    ) -> BattleRewardSettlement? {
        guard battle.activeBattle?.id == configuration.id,
              let progress = battle.resolvedDefeatProgress else { return nil }
        return presentation.rewardPlan.settleDefeat(
            progress: progress,
            inputs: RewardSettlementInputs(
                save: playerSave.currentSave,
                hero: configuration.hero.combatant, companion: configuration.companion.combatant,
                at: date,
            ),
        )
    }

    func claimDefeat(
        _ configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext,
        settlement: BattleRewardSettlement,
    ) -> BattleCompletionResult {
        guard battle.lifecyclePhase == .active, battle.activeBattle?.id == configuration.id,
              battle.resolvedDefeatProgress != nil else { return .unavailable }
        switch claimState {
        case .victory:
            return .unavailable
        case let .defeat(claimedID) where claimedID == configuration.id:
            return .completed
        case .unclaimed, .defeat:
            break
        }
        guard let resolved = settleDefeat(configuration, presentation: presentation, at: settlement.inputs.productionDate)
        else { return .unavailable }
        guard resolved == settlement else { return .staleSettlement(resolved) }
        let didPersist = playerSave.persistBatch(logging: "Failed to persist defeat experience") { save in
            BattleExperienceReward.apply(
                resolved, hero: configuration.hero.combatant, companion: configuration.companion.combatant, save: &save,
            )
        }
        guard didPersist else { return .persistenceFailed }
        claimState = .defeat(configurationID: configuration.id)
        recordTalentProgressions(resolved, configuration: configuration)
        return .completed
    }
}
