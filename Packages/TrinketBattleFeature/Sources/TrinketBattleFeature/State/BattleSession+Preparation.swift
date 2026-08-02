import Foundation
import SwiftUI
import TrinketBattleRuntime
import TrinketFeatureSupport

public extension BattleSession {
    /// Warms all currently prepared runs without exposing BattleFeature's caches
    /// or presentation primitives to the app's mode screens.
    func preparePreparedBattlePresentation(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) async {
        guard runtime.lifecyclePhase == .prepared,
              !runtime.preparedBattleRuns.isEmpty
        else { return }

        // Let the navigation transition commit before doing the first expensive
        // raster work. The task owner in PlayView cancels this work when the
        // prepared-run revision changes.
        await Task.yield()
        guard !Task.isCancelled else { return }

        let preparedRuns = runtime.preparedBattleRuns
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
        guard let run = runtime.preparedBattleRun(for: runKey) else { return [] }
        return runtime.openingHandArtworkNames(for: run.simulation)
    }

    internal func installSimulationPresentation() {
        guard let snapshot = runtime.presentationSnapshot() else { return }
        presentation.install(snapshot)
    }
}
