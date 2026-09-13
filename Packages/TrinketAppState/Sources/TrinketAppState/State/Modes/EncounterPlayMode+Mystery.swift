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
        let pickContext = inputs.pickContext
        let pinnedLabyrinthEventID = inputs.pinnedLabyrinthEventID
        let pinnedJourneyEventID = inputs.pinnedJourneyEventID

        let opened = MysteryEncounterSession.open(
            origin: origin,
            encounter: origin.identity(in: playerSave.currentSave),
            forcedEventID: forcedEventID,
            worldSeed: playerSave.worldSeed,
            pickContext: pickContext,
            pinnedLabyrinthEventID: pinnedLabyrinthEventID,
            pinnedJourneyEventID: pinnedJourneyEventID,
        )

        if let id = opened.session.event.unlockCombatantID, !playerSave.contentAccess.allowsCombatant(id) {
            return .fullGameRequired(.combatant(id))
        }

        if let pinFailure = pinMysteryEventIfNeeded(
            origin: origin,
            resolvedEventID: opened.resolvedEventID,
            isRecruit: opened.session.event.isRecruit,
            pinnedLabyrinthEventID: pinnedLabyrinthEventID,
            pinnedJourneyEventID: pinnedJourneyEventID,
        ) {
            return pinFailure
        }

        if !opened.session.event.isRecruit, !opened.session.isCorruptionAltar {
            guard prepareMysteryOffers(opened.session) else { return Self.mysteryPinFailureMessage }
        }
        activeMysteryEncounter = opened.session
        sfxPlayer.play(SFXID.mysteryEvent, volume: options.effectsVolume)
        if opened.session.event.isRecruit {
            guard resolveActiveMysteryChoice(choiceID: nil) else {
                let detail = opened.session.persistFailureMessage
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

    private func prepareMysteryOffers(_ session: MysteryEncounterSession) -> Bool {
        let prepared = playerSave.persistTransaction(logging: "Failed to save mystery offers") { save -> Result<
            [MysteryOffer],
            MysteryChoiceFailure,
        > in
            var rng = SystemRandomNumberGenerator()
            do {
                return try .success(MysteryOfferPersistence.prepare(
                    event: session.event, stage: session.stage,
                    labyrinthNodeID: session.labyrinthNodeID, save: &save, using: &rng,
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
        if let id = mysterySession.event.unlockCombatantID, !playerSave.contentAccess.allowsCombatant(id) {
            mysterySession.markPersistFailed("This character requires Full Game. Progress is preserved.")
            return false
        }
        guard mysterySession.canResolveChoice else {
            mysterySession.markChoiceUnavailable()
            return false
        }

        return persistMysteryResolution(mysterySession, logging: "Failed to apply mystery effects") { save, rng in
            MysteryEncounterResolution.resolve(
                choiceID: choiceID,
                request: mysterySession.resolutionRequest,
                save: &save,
                using: &rng,
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
        mutate: (inout PlayerSave, inout SystemRandomNumberGenerator) -> Result<MysteryChoiceOutcome, MysteryChoiceFailure>,
    ) -> Bool {
        mysterySession.markChoiceStarted()
        switch playerSave.persistTransaction(logging: logging, { save in
            var rng = SystemRandomNumberGenerator()
            return mutate(&save, &rng)
        }) {
        case let .committed(outcome):
            return applyMysteryOutcome(outcome, session: mysterySession)
        case .rejected:
            mysterySession.markChoiceUnavailable()
            return false
        case .persistFailed:
            mysterySession.markPersistFailed("Couldn't save progress. Stay here and try again.")
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
        title: "Couldn't Save Progress",
        message: "This event was not saved. Stay here and try again.",
    )
}
