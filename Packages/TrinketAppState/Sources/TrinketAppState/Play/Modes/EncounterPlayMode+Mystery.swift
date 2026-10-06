import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

public extension EncounterPlayMode {
    func previewMysteryEvent(
        origin: PlayEncounterOrigin,
        forcedEventID: String? = nil,
    ) -> MysteryEvent {
        let inputs = mysteryPickInputs(origin: origin)
        return MysteryEncounterSession.resolveEvent(
            origin: origin,
            forcedEventID: forcedEventID,
            worldSeed: playerSave.worldSeed,
            pickContext: inputs.pickContext,
            pinnedLabyrinthEventID: inputs.pinnedLabyrinthEventID,
            pinnedJourneyEventID: inputs.pinnedJourneyEventID,
        )
    }

    @discardableResult
    func beginMysteryEncounter(
        origin: PlayEncounterOrigin,
        forcedEventID: String? = nil,
    ) -> StageMapMessage? {
        if let restriction = playerSave.encounterAccessRestriction(for: origin) {
            return restriction
        }
        guard canBeginTransientEncounter else { return nil }

        let inputs = mysteryPickInputs(origin: origin)
        let session = MysteryEncounterSession.open(
            origin: origin,
            encounter: origin.identity(in: playerSave.currentSave),
            forcedEventID: forcedEventID,
            worldSeed: playerSave.worldSeed,
            pickContext: inputs.pickContext,
            pinnedLabyrinthEventID: inputs.pinnedLabyrinthEventID,
            pinnedJourneyEventID: inputs.pinnedJourneyEventID,
        )

        if let paywall = mysteryPaywallMessage(for: session.event) {
            return paywall
        }
        return finishOpeningMystery(session, forcedEventID: forcedEventID)
    }

    /// Publishes only after the event pin and offers commit together. Recruit
    /// auto-resolution has its own transaction and retry path.
    private func finishOpeningMystery(
        _ session: MysteryEncounterSession,
        forcedEventID: String?,
    ) -> StageMapMessage? {
        if !session.event.isRecruit {
            switch playerSave.prepareMysteryEncounter(
                event: session.event, encounter: session.encounter, using: &mysteryRandom, at: currentDate(),
            ) {
            case let .committed(offers):
                session.installOffers(offers)
            case .rejected:
                return Self.mysteryPinFailureMessage
            case .persistFailed:
                retryOpeningMystery(origin: session.origin, forcedEventID: forcedEventID)
                return nil
            }
        }
        activeMysteryEncounter = session
        sfxPlayer.play(SFXID.mysteryEvent, volume: options.effectsVolume)
        if session.event.isRecruit {
            guard resolveActiveMysteryChoice(choiceID: nil) else {
                if playerSave.lastPersistenceError == .writeFailed {
                    return nil
                }
                let detail = session.persistFailureMessage
                    ?? Self.mysteryPinFailureMessage.message
                activeMysteryEncounter = nil
                return StageMapMessage(
                    title: Self.mysteryPinFailureMessage.title,
                    message: detail,
                )
            }
        }
        return nil
    }

    /// Character paywall for mystery events that unlock combatants. Also
    /// enforced in `PlayBattleCoordinator.activateBattle` and
    /// `resolveActiveMysteryChoice`; checked here so the paywall surfaces
    /// before any pin writes.
    private func mysteryPaywallMessage(for event: MysteryEvent) -> StageMapMessage? {
        guard let id = event.unlockCombatantID, !playerSave.contentAccess.allowsCombatant(id) else { return nil }
        return .fullGameRequired(.combatant(id))
    }

    private func retryOpeningMystery(origin: PlayEncounterOrigin, forcedEventID: String?) {
        playerSave.retrySaveAction(key: SaveRetryKey.mysteryOpen) { [weak self] in
            guard let self, activeMysteryEncounter == nil, canBeginTransientEncounter else { return }
            _ = beginMysteryEncounter(origin: origin, forcedEventID: forcedEventID)
        }
    }

    private func mysteryPickInputs(
        origin: PlayEncounterOrigin,
    ) -> (pickContext: MysteryEventPickContext, pinnedLabyrinthEventID: String?, pinnedJourneyEventID: String?) {
        let cooldown = playerSave.currentSave.corruptionAltarCooldownRemaining
        switch origin {
        case let .journey(stage):
            return (
                .journey(
                    chapterNumber: stage.chapterNumber,
                    inventory: playerSave.inventory,
                    corruptionAltarCooldownRemaining: cooldown,
                ),
                nil,
                playerSave.journey.pinnedMysteryEventIDs[stage.id],
            )
        case let .labyrinth(nodeID):
            return (
                .labyrinth(inventory: playerSave.inventory, corruptionAltarCooldownRemaining: cooldown),
                playerSave.labyrinth.nodes[nodeID]?.mysteryEventID,
                nil,
            )
        case let .voyage(runID, nodeID):
            return (
                .labyrinth(inventory: playerSave.inventory, corruptionAltarCooldownRemaining: cooldown),
                playerSave.voyage.node(runID: runID, nodeID: nodeID)?.mysteryEventID,
                nil,
            )
        }
    }

    @discardableResult
    func resolveActiveMysteryChoice(choiceID: String? = nil) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        if mysteryPaywallMessage(for: mysterySession.event) != nil {
            mysterySession.markPersistFailed("This character requires Full Game. Progress is preserved.")
            return false
        }
        guard mysterySession.canResolveChoice else {
            mysterySession.markChoiceUnavailable()
            return false
        }

        return persistMysteryResolution(mysterySession, action: .choice(choiceID), at: currentDate())
    }

    @discardableResult
    func corruptActiveMysteryItem(itemID: String) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.showsCorruptItemChoice, !mysterySession.isResolvingChoice,
              mysterySession.corruptibleItems.contains(where: { $0.id == itemID }) else {
            mysterySession.markChoiceUnavailable()
            return false
        }

        return persistMysteryResolution(mysterySession, action: .corruptItem(itemID), at: currentDate())
    }

    private func persistMysteryResolution(
        _ mysterySession: MysteryEncounterSession,
        action: MysteryEncounterAction,
        at date: Date,
    ) -> Bool {
        mysterySession.markChoiceStarted()
        switch playerSave.resolveMysteryEncounter(
            mysterySession.resolutionRequest, action: action, using: &mysteryRandom, at: date,
        ) {
        case let .committed(outcome):
            return applyMysteryOutcome(outcome, session: mysterySession)
        case .rejected:
            mysterySession.markChoiceUnavailable()
            return false
        case .persistFailed:
            // Transient write failure: silent retry while the encounter stays
            // open; only rejection surfaces "unavailable".
            playerSave.retrySaveAction(key: SaveRetryKey.mysteryResolution) { [weak self] in
                guard let self, activeMysteryEncounter === mysterySession else { return }
                _ = persistMysteryResolution(mysterySession, action: action, at: date)
            }
            return false
        }
    }

    func cancelActiveMysteryCorruptSelection() {
        guard let mysterySession = activeMysteryEncounter, mysterySession.showsCorruptItemChoice else {
            return
        }
        mysterySession.returnToReading()
    }

    @discardableResult
    func finishActiveMysteryCorruptionReveal() -> Bool {
        guard let mysterySession = activeMysteryEncounter, mysterySession.showsCorruptionReveal else {
            return false
        }
        activeMysteryEncounter = nil
        return true
    }

    @discardableResult
    func finishActiveMysteryEncounter(dismiss: Bool = true) -> Bool {
        guard let mysterySession = activeMysteryEncounter else {
            return false
        }
        mysterySession.clearPersistFailure()
        if mysterySession.showsReward {
            if dismiss {
                activeMysteryEncounter = nil
            }
            return true
        }
        guard mysterySession.showsReveal else {
            return false
        }
        sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
        if dismiss {
            activeMysteryEncounter = nil
        }
        return true
    }

    func collectMysteryReward(session: MysteryEncounterSession) -> Bool {
        guard activeMysteryEncounter === session, session.showsReward,
              finishActiveMysteryEncounter(dismiss: false) else { return false }
        if session.claimRewardCollectionSound() {
            sfxPlayer.play(SFXID.lootCollect, volume: options.effectsVolume)
        }
        return true
    }

    func dismissMysteryReward(session: MysteryEncounterSession) {
        guard activeMysteryEncounter === session, session.showsReward else { return }
        activeMysteryEncounter = nil
    }

    func dismissActiveMysteryEncounter() {
        activeMysteryEncounter = nil
    }

    @discardableResult
    internal func applyMysteryOutcome(
        _ outcome: MysteryChoiceOutcome,
        session mysterySession: MysteryEncounterSession,
    ) -> Bool {
        switch outcome {
        case .dismiss:
            activeMysteryEncounter = nil
            return true
        case .reward:
            mysterySession.applyOutcome(outcome)
            sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
            return true
        case .corruptionReveal:
            let isNewReveal = !mysterySession.showsCorruptionReveal
            mysterySession.applyOutcome(outcome)
            if isNewReveal {
                sfxPlayer.play(SFXID.itemCorrupt, volume: options.effectsVolume)
            }
            return true
        case .reveal:
            mysterySession.applyOutcome(outcome)
            return true
        case .refreshedOffers:
            mysterySession.applyOutcome(outcome)
            return false
        case .selectCorruptItem:
            mysterySession.applyOutcome(outcome, inventory: playerSave.inventory)
            return true
        }
    }

    private static let mysteryPinFailureMessage = StageMapMessage(
        title: "Event Unavailable",
        message: "This event is no longer available.",
    )
}
