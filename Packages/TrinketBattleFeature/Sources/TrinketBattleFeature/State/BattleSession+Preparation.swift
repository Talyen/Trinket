import Foundation
import SwiftUI
import TrinketBattleRuntime
import TrinketFeatureSupport

public extension BattleSession {
    internal struct PreparedBattleRun {
        let configuration: BattleRunConfiguration
        let simulation: BattleSimulationStore.PreparedRun
    }

    @discardableResult
    func prepareBattleRun(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle == nil,
              let runKey = configuration.runKey else { return false }
        if preparedBattleRunsByKey[runKey]?.configuration.id == configuration.id {
            return true
        }
        preparedBattleRunsByKey[runKey] = PreparedBattleRun(
            configuration: configuration,
            simulation: simulation.makePreparedRun(from: configuration)
        )
        preparedBattlePresentationRevision += 1
        lifecyclePhase = .prepared
        return true
    }

    /// Warms all currently prepared runs without exposing BattleFeature's caches
    /// or presentation primitives to the app's mode screens.
    func preparePreparedBattlePresentation(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) async {
        guard lifecyclePhase == .prepared,
              !preparedBattleRunsByKey.isEmpty
        else { return }

        // Let the navigation transition commit before doing the first expensive
        // raster work. The task owner in PlayView cancels this work when the
        // prepared-run revision changes.
        await Task.yield()
        guard !Task.isCancelled else { return }

        let preparedRuns = Array(preparedBattleRunsByKey.values)
        await BattlePresentationWarmup.prepareAndWait(
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
        guard !Task.isCancelled else { return }

        for run in preparedRuns {
            prepareBattlePresentation(
                heroUltimateID: run.configuration.hero.combatant.abilityLoadout.ultimate?.id,
                companionUltimateID: run.configuration.companion.combatant.abilityLoadout.ultimate?.id
            )
        }

        let artworkNames = preparedRuns.flatMap { run -> [String] in
            guard let runKey = run.configuration.runKey else { return [] }
            return preparedAbilityArtworkNames(for: runKey)
        }
        guard !Task.isCancelled else { return }
        await PreparedArtworkCache.shared.prepareAndPin(names: artworkNames)
    }

    /// Opening-hand ability art names for a prepared run (cast faces on first play).
    /// Peeks a copy so the prepared run keeps an empty hand for the paced deal.
    internal func preparedAbilityArtworkNames(for runKey: BattleRunKey) -> [String] {
        guard let run = preparedBattleRunsByKey[runKey] else { return [] }
        return simulation.openingHandArtworkNames(for: run.simulation)
    }

    func activatePreparedBattle(
        runKey: BattleRunKey,
        heroID: String,
        companionID: String,
        enemyID: String?
    ) -> Bool {
        guard let preparedBattleRun = preparedBattleRunsByKey[runKey],
              preparedBattleRun.configuration.runKey == runKey,
              preparedBattleRun.configuration.hero.combatant.id == heroID,
              preparedBattleRun.configuration.companion.combatant.id == companionID,
              preparedBattleRun.configuration.enemy?.id == enemyID
        else { return false }
        preparedBattleRunsByKey.removeValue(forKey: runKey)
        pendingPreparedRun = preparedBattleRun
        installActiveBattle(preparedBattleRun.configuration)
        return true
    }

    @discardableResult
    func activate(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle == nil else { return false }
        pendingPreparedRun = nil
        installActiveBattle(configuration)
        return true
    }

    @discardableResult
    func restart(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle != nil else { return false }
        pendingPreparedRun = nil
        installActiveBattle(configuration)
        return true
    }

    internal func installSimulationPresentation() {
        guard let snapshot = simulation.presentationSnapshot() else { return }
        presentation.install(snapshot)
    }
}
