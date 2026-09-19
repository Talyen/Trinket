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
        let opened = MysteryEncounterSession.open(
            origin: origin,
            encounter: origin.identity(in: playerSave.currentSave),
            forcedEventID: forcedEventID,
            worldSeed: playerSave.worldSeed,
            pickContext: inputs.pickContext,
            pinnedLabyrinthEventID: inputs.pinnedLabyrinthEventID,
            pinnedJourneyEventID: inputs.pinnedJourneyEventID,
        )

        if let paywall = mysteryPaywallMessage(for: opened.session.event) {
            return paywall
        }
        return finishOpeningMystery(
            opened.session,
            origin: origin,
            forcedEventID: forcedEventID,
            resolvedEventID: opened.resolvedEventID,
            pinnedLabyrinthEventID: inputs.pinnedLabyrinthEventID,
            pinnedJourneyEventID: inputs.pinnedJourneyEventID,
        )
    }

    /// Pins the event, prepares offers, publishes the session, and auto-resolves
    /// recruit events. Transient write failures schedule a silent retry and
    /// return nil; rejections surface a message. (Recruit auto-resolve needs no
    /// retry here: the resolution path already scheduled one internally.)
    private func finishOpeningMystery(
        _ session: MysteryEncounterSession,
        origin: PlayEncounterOrigin,
        forcedEventID: String?,
        resolvedEventID: String,
        pinnedLabyrinthEventID: String?,
        pinnedJourneyEventID: String?,
    ) -> StageMapMessage? {
        if let pinFailure = pinMysteryEventIfNeeded(
            origin: origin,
            resolvedEventID: resolvedEventID,
            isRecruit: session.event.isRecruit,
            pinnedLabyrinthEventID: pinnedLabyrinthEventID,
            pinnedJourneyEventID: pinnedJourneyEventID,
        ) {
            if playerSave.lastPersistenceError == .writeFailed {
                retryOpeningMystery(origin: origin, forcedEventID: forcedEventID)
                return nil
            }
            return pinFailure
        }

        if !session.event.isRecruit, !session.isCorruptionAltar {
            guard prepareMysteryOffers(session) else {
                if playerSave.lastPersistenceError == .writeFailed {
                    retryOpeningMystery(origin: origin, forcedEventID: forcedEventID)
                    return nil
                }
                return Self.mysteryPinFailureMessage
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
    /// enforced in `PlayBattleLaunch.activateBattle` and
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

    private func prepareMysteryOffers(_ session: MysteryEncounterSession) -> Bool {
        let prepared = playerSave.persistTransaction(logging: "Failed to save mystery offers") { save -> Result<
            [MysteryOffer],
            MysteryChoiceFailure,
        > in
            do {
                return try .success(MysteryOfferPersistence.prepare(
                    event: session.event, stage: session.stage,
                    labyrinthNodeID: session.labyrinthNodeID, save: &save, using: &mysteryRandom, at: currentDate(),
                ))
            } catch {
                return .failure(.unavailable)
            }
        }
        guard case let .committed(offers) = prepared else { return false }
        session.installOffers(offers)
        return true
    }

    private func mysteryEventPickContext(
        origin: PlayEncounterOrigin,
    ) -> MysteryEventPickContext {
        let cooldown = playerSave.currentSave.corruptionAltarCooldownRemaining
        if origin.labyrinthNodeID != nil {
            return .labyrinth(
                inventory: playerSave.inventory,
                corruptionAltarCooldownRemaining: cooldown,
            )
        }
        guard let stage = origin.stage else {
            return .excludingCorruptionAltar
        }
        return .journey(
            chapterNumber: stage.chapterNumber,
            inventory: playerSave.inventory,
            corruptionAltarCooldownRemaining: cooldown,
        )
    }

    private func mysteryPickInputs(
        origin: PlayEncounterOrigin,
    ) -> (pickContext: MysteryEventPickContext, pinnedLabyrinthEventID: String?, pinnedJourneyEventID: String?) {
        (
            mysteryEventPickContext(origin: origin),
            origin.labyrinthNodeID.flatMap { playerSave.labyrinth.nodes[$0]?.mysteryEventID },
            origin.stage.flatMap { playerSave.journey.pinnedMysteryEventIDs[$0.id] },
        )
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

        let date = currentDate()
        return persistMysteryResolution(mysterySession, logging: "Failed to apply mystery effects") { save, rng in
            MysteryEncounterResolution.resolve(
                choiceID: choiceID,
                request: mysterySession.resolutionRequest,
                save: &save,
                using: &rng, at: date,
            )
        }
    }

    @discardableResult
    func corruptActiveMysteryItem(itemID: String) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.showsCorruptItemChoice, !mysterySession.isResolvingChoice,
              mysterySession.corruptibleItems.contains(where: { $0.id == itemID }) else {
            mysterySession.markChoiceUnavailable()
            return false
        }

        return persistMysteryResolution(mysterySession, logging: "Failed to corrupt mystery item") { save, rng in
            MysteryEncounterResolution.corrupt(
                itemID: itemID,
                request: mysterySession.resolutionRequest,
                save: &save,
                using: &rng,
            )
        }
    }

    private func persistMysteryResolution(
        _ mysterySession: MysteryEncounterSession,
        logging: String,
        mutate: @escaping (inout PlayerSave, inout any RandomNumberGenerator) -> Result<MysteryChoiceOutcome, MysteryChoiceFailure>,
    ) -> Bool {
        mysterySession.markChoiceStarted()
        switch playerSave.persistTransaction(logging: logging, { save in
            mutate(&save, &mysteryRandom)
        }) {
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
                _ = persistMysteryResolution(mysterySession, logging: logging, mutate: mutate)
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
        sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
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
        sfxPlayer.play(SFXID.uiBuySell, volume: options.effectsVolume)
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
        case .reveal, .corruptionReveal:
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

    private func pinMysteryEventIfNeeded(
        origin: PlayEncounterOrigin,
        resolvedEventID: String,
        isRecruit: Bool,
        pinnedLabyrinthEventID: String?,
        pinnedJourneyEventID: String?,
    ) -> StageMapMessage? {
        guard !isRecruit else { return nil }

        if let labyrinthNodeID = origin.labyrinthNodeID, pinnedLabyrinthEventID == nil {
            return pinEvent(logging: "Failed to pin labyrinth mystery event") { save in
                MysteryEventPinApplier.pinLabyrinthEvent(
                    nodeID: labyrinthNodeID,
                    eventID: resolvedEventID,
                    save: &save,
                )
            }
        }

        if let stage = origin.stage, pinnedJourneyEventID == nil, stage.mysteryEvent == nil {
            return pinEvent(logging: "Failed to pin journey mystery event") { save in
                MysteryEventPinApplier.pinJourneyEvent(
                    stageID: stage.id,
                    eventID: resolvedEventID,
                    save: &save,
                )
            }
        }

        return nil
    }

    private func pinEvent(
        logging: String,
        pin: (inout PlayerSave) -> Bool,
    ) -> StageMapMessage? {
        var didPinEvent = false
        let didPersist = playerSave.persistBatch(logging: logging) { save in
            didPinEvent = pin(&save)
        }
        return didPersist && didPinEvent ? nil : Self.mysteryPinFailureMessage
    }

    private static let mysteryPinFailureMessage = StageMapMessage(
        title: "Event Unavailable",
        message: "This event is no longer available.",
    )
}
