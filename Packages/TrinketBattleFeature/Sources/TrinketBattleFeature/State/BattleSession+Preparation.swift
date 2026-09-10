import Foundation

public extension BattleSession {
    func prepareBattlePresentationAssets(displayScale: CGFloat) async {
        guard lifecyclePhase == .prepared || lifecyclePhase == .active else { return }

        let preparedRuns = preparedBattleRuns
        let activeConfiguration = activeBattle
        guard !preparedRuns.isEmpty || activeConfiguration != nil else { return }

        await artworkPreparation.prepare(names: desiredPreparedArtworkNames, displayScale: displayScale) {
            var configurations = preparedRuns.map(\.configuration)
            if let activeConfiguration {
                configurations.append(activeConfiguration)
            }
            for configuration in configurations {
                prepareBattlePresentation(
                    heroActorID: configuration.hero.combatant.id,
                    heroUltimateID: configuration.hero.combatant.abilityLoadout.ultimate?.id,
                    companionActorID: configuration.companion.combatant.id,
                    companionUltimateID: configuration.companion.combatant.abilityLoadout.ultimate?.id,
                )
            }
        }
    }

    func releasePreparedArtworkPins() {
        artworkPreparation.release()
    }

    internal func retainPreparedArtworkPins() {
        artworkPreparation.retain(names: desiredPreparedArtworkNames)
    }

    private var desiredPreparedArtworkNames: Set<String> {
        var names = Set(preparedBattleRuns.flatMap { openingHandArtworkNames(for: $0) })
        if activeBattle != nil {
            names.formUnion(activeOpeningHandArtworkNames())
        }
        return names
    }

    internal func installSimulationPresentation() {
        guard let snapshot = presentationSnapshot() else { return }
        presentation.install(snapshot)
        if let cue = cardCues.current, cue.phase == .lifted,
           !snapshot.playableCardIDs.contains(cue.cardID) {
            publishAttackTelegraph(.cancel, for: cue.actorID)
            cardCues.cancel(cardID: cue.cardID)
        }
    }
}
