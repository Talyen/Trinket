import Foundation
import SwiftUI
import TrinketBattleRuntime
import TrinketFeatureSupport

public extension BattleSession {
    /// Warms the prepared launch candidates or active fallback run without exposing
    /// BattleFeature's caches and presentation primitives to app mode screens.
    func prepareBattlePresentationAssets(displayScale: CGFloat) async {
        guard lifecyclePhase == .prepared || lifecyclePhase == .active else { return }
        releasePreparedArtworkPins()

        // Let the navigation transition commit before doing the first expensive
        // raster work. The task owner in PlayView cancels this work when the
        // prepared-run revision changes.
        await Task.yield()
        guard !Task.isCancelled else { return }

        let phase = lifecyclePhase
        let preparedRuns = phase == .prepared ? preparedBattleRuns : []
        let activeConfiguration = phase == .active ? activeBattle : nil
        guard !preparedRuns.isEmpty || activeConfiguration != nil else { return }

        await BattlePresentationWarmup.prepareAndWait(displayScale: displayScale)
        guard !Task.isCancelled else { return }

        for run in preparedRuns {
            prepareBattlePresentation(
                heroActorID: run.configuration.hero.combatant.id,
                heroUltimateID: run.configuration.hero.combatant.abilityLoadout.ultimate?.id,
                companionActorID: run.configuration.companion.combatant.id,
                companionUltimateID: run.configuration.companion.combatant.abilityLoadout.ultimate?.id
            )
        }

        if let activeConfiguration {
            prepareBattlePresentation(
                heroActorID: activeConfiguration.hero.combatant.id,
                heroUltimateID: activeConfiguration.hero.combatant.abilityLoadout.ultimate?.id,
                companionActorID: activeConfiguration.companion.combatant.id,
                companionUltimateID: activeConfiguration.companion.combatant.abilityLoadout.ultimate?.id
            )
        }

        var artworkNames = preparedRuns.flatMap { run -> [String] in
            guard let runKey = run.configuration.runKey else { return [] }
            return preparedAbilityArtworkNames(for: runKey)
        }
        if activeConfiguration != nil {
            artworkNames.append(contentsOf: activeOpeningHandArtworkNames())
        }
        guard !Task.isCancelled else { return }
        await PreparedArtworkCache.shared.prepareAndPin(names: artworkNames)
        guard !Task.isCancelled else {
            PreparedArtworkCache.shared.releasePins(names: artworkNames)
            return
        }
        releasePreparedArtworkPins()
        preparedArtworkNames = Set(artworkNames)
    }

    /// Releases artwork retained for the current prepared/active run.
    /// Preparation owns these pins until the run is activated, replaced, or ended.
    func releasePreparedArtworkPins() {
        guard !preparedArtworkNames.isEmpty else { return }
        PreparedArtworkCache.shared.releasePins(names: Array(preparedArtworkNames))
        preparedArtworkNames.removeAll()
    }

    /// Opening-hand ability art names for a prepared run (cast faces on first play).
    /// Peeks a copy so the prepared run keeps an empty hand for the paced deal.
    internal func preparedAbilityArtworkNames(for runKey: BattleRunKey) -> [String] {
        guard let run = preparedBattleRun(for: runKey) else { return [] }
        return openingHandArtworkNames(for: run)
    }

    internal func installSimulationPresentation() {
        guard let snapshot = presentationSnapshot() else { return }
        presentation.install(snapshot)
    }
}
