import Foundation

public extension BattleSession {
    func prepareBattlePresentationAssets(displayScale: CGFloat) async {
        // lifecyclePhase already derives from the same runs/active state
        // checked below, so one guard suffices on this actor.
        let phase = lifecyclePhase
        guard phase == .prepared || phase == .active else { return }

        dependencies.warmSFX(CombatSFXMapper.battlePrewarmIDs, 2)
        await artworkPreparation.prepare(names: desiredPreparedArtworkNames, displayScale: displayScale)
    }

    func releasePreparedArtworkPins() {
        artworkPreparation.release()
    }

    internal func retainPreparedArtworkPins() {
        artworkPreparation.releaseExtraneousPins(names: desiredPreparedArtworkNames)
    }

    private var desiredPreparedArtworkNames: Set<String> {
        var configurations = preparedPreview.configurations
        if let activeBattle {
            configurations.append(activeBattle)
        }
        return Set(configurations.flatMap { BattleArtworkPreparation.artworkNames(for: $0) })
    }

    internal func installSimulationPresentation() {
        guard let snapshot = presentationSnapshot() else {
            // No active or uniquely prepared run: no valid cue target exists,
            // so a lifted cue cannot be valid either.
            clearCardCues()
            return
        }
        presentation.install(snapshot)
        if let cue = cardCues.current, cue.phase == .lifted,
           !snapshot.playableCardIDs.contains(cue.cardID) {
            publishAttackTelegraph(.cancel, for: cue.actorID)
            cardCues.cancel(cardID: cue.cardID)
        }
    }
}
