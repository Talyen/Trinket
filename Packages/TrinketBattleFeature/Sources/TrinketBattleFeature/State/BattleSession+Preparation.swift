import BattleEngine
import Foundation
import SwiftUI
import TrinketFeatureSupport

public extension BattleSession {
    func prepareBattlePresentationAssets(displayScale: CGFloat) async {
        guard lifecyclePhase == .prepared || lifecyclePhase == .active else { return }

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
        let uniqueNames = Set(artworkNames)
        guard !Task.isCancelled else { return }
        guard uniqueNames != preparedArtworkNames else { return }
        await PreparedArtworkCache.shared.prepareAndPin(names: artworkNames)
        guard !Task.isCancelled else {
            PreparedArtworkCache.shared.releasePins(names: artworkNames)
            return
        }
        let obsoleteNames = preparedArtworkNames.subtracting(uniqueNames)
        if !obsoleteNames.isEmpty {
            PreparedArtworkCache.shared.releasePins(names: Array(obsoleteNames))
        }
        preparedArtworkNames = uniqueNames
    }

    func releasePreparedArtworkPins() {
        guard !preparedArtworkNames.isEmpty else { return }
        PreparedArtworkCache.shared.releasePins(names: Array(preparedArtworkNames))
        preparedArtworkNames.removeAll()
    }

    internal func preparedAbilityArtworkNames(for runKey: BattleRunKey) -> [String] {
        guard let run = preparedBattleRun(for: runKey) else { return [] }
        return openingHandArtworkNames(for: run)
    }

    internal func installSimulationPresentation() {
        guard let snapshot = presentationSnapshot() else { return }
        presentation.install(snapshot)
    }
}
