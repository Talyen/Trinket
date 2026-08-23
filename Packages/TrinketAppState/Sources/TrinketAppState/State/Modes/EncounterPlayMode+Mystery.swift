import Foundation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

public extension EncounterPlayMode {
    /// Map/inspector preview; uses the same pins and pick context as `beginMysteryEncounter`.
    func previewMysteryEvent(
        origin: PlayEncounterOrigin,
        forcedEventID: String? = nil
    ) -> MysteryEvent {
        MysteryEncounterSession.resolveEvent(
            origin: origin,
            forcedEventID: forcedEventID,
            worldSeed: playerSave.worldSeed,
            pickContext: mysteryEventPickContext(origin: origin),
            pinnedLabyrinthEventID: origin.labyrinthNodeID.flatMap {
                playerSave.labyrinth.nodes[$0]?.mysteryEventID
            },
            pinnedJourneyEventID: origin.stage.flatMap {
                playerSave.journey.pinnedMysteryEventIDs[$0.id]
            }
        )
    }

    @discardableResult
    func beginMysteryEncounter(
        origin: PlayEncounterOrigin,
        forcedEventID: String? = nil
    ) -> StageMapMessage? {
        guard canBeginTransientEncounter else { return nil }

        let pickContext = mysteryEventPickContext(origin: origin)
        let pinnedLabyrinthEventID = origin.labyrinthNodeID.flatMap {
            playerSave.labyrinth.nodes[$0]?.mysteryEventID
        }
        let pinnedJourneyEventID = origin.stage.flatMap {
            playerSave.journey.pinnedMysteryEventIDs[$0.id]
        }

        let opened = MysteryEncounterSession.open(
            origin: origin,
            forcedEventID: forcedEventID,
            worldSeed: playerSave.worldSeed,
            pickContext: pickContext,
            pinnedLabyrinthEventID: pinnedLabyrinthEventID,
            pinnedJourneyEventID: pinnedJourneyEventID
        )

        if let pinFailure = pinMysteryEventIfNeeded(
            origin: origin,
            resolvedEventID: opened.resolvedEventID,
            isRecruit: opened.session.event.isRecruit,
            pinnedLabyrinthEventID: pinnedLabyrinthEventID,
            pinnedJourneyEventID: pinnedJourneyEventID
        ) {
            return pinFailure
        }

        opened.session.installPreviews(save: playerSave.currentSave)
        activeMysteryEncounter = opened.session
        sfxPlayer.play(SFXID.mysteryEvent, volume: options.effectsVolume)
        if opened.session.event.isRecruit {
            guard resolveActiveMysteryChoice(choiceID: nil) else {
                let detail = opened.session.persistFailureMessage
                    ?? Self.mysteryPinFailureMessage.message
                activeMysteryEncounter = nil
                return StageMapMessage(
                    title: Self.mysteryPinFailureMessage.title,
                    message: detail
                )
            }
        }
        return nil
    }

    private func mysteryEventPickContext(
        origin: PlayEncounterOrigin
    ) -> MysteryEventPickContext {
        let cooldown = playerSave.currentSave.corruptionAltarCooldownRemaining
        if origin.labyrinthNodeID != nil {
            return .labyrinth(
                inventory: playerSave.inventory,
                corruptionAltarCooldownRemaining: cooldown
            )
        }
        guard let stage = origin.stage else {
            return .excludingCorruptionAltar
        }
        return .journey(
            chapterNumber: stage.chapterNumber,
            inventory: playerSave.inventory,
            corruptionAltarCooldownRemaining: cooldown
        )
    }

    /// Applies the single (or first) choice for the active mystery encounter.
    @discardableResult
    func resolveActiveMysteryChoice(choiceID: String? = nil) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.canResolveChoice else { return false }

        return persistMysteryResolution(mysterySession, logging: "Failed to apply mystery effects") { save, rng in
            mysterySession.resolveChoice(
                choiceID: choiceID,
                save: &save,
                using: &rng,
                completeProgress: Self.completeMysteryProgress
            )
        }
    }

    /// Corrupts the selected inventory item at the Corruption Altar.
    @discardableResult
    func corruptActiveMysteryItem(itemID: String) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.showsCorruptItemChoice else { return false }

        return persistMysteryResolution(mysterySession, logging: "Failed to corrupt mystery item") { save, rng in
            mysterySession.corruptSelectedItem(
                itemID: itemID,
                save: &save,
                using: &rng,
                completeProgress: Self.completeMysteryProgress
            )
        }
    }

    /// Runs one mystery save mutation; on persist failure marks the session and
    /// returns false, otherwise applies and surfaces the outcome.
    private func persistMysteryResolution(
        _ mysterySession: MysteryEncounterSession,
        logging: String,
        mutate: (inout PlayerSave, inout SystemRandomNumberGenerator) -> MysteryChoiceOutcome
    ) -> Bool {
        var outcome = MysteryChoiceOutcome.failed
        guard playerSave.persistBatch(logging: logging, { save in
            var randomNumberGenerator = SystemRandomNumberGenerator()
            outcome = mutate(&save, &randomNumberGenerator)
        }) else {
            mysterySession.markPersistFailed("Couldn't save progress. Stay here and try again.")
            return false
        }

        return applyMysteryOutcome(outcome, session: mysterySession)
    }

    func cancelActiveMysteryCorruptSelection() {
        guard let mysterySession = activeMysteryEncounter, mysterySession.showsCorruptItemChoice else {
            return
        }
        mysterySession.returnToReading()
    }

    /// Dismisses the corruption reveal after the player acknowledges the outcome.
    @discardableResult
    func finishActiveMysteryCorruptionReveal() -> Bool {
        guard let mysterySession = activeMysteryEncounter, mysterySession.showsCorruptionReveal else {
            return false
        }
        sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
        activeMysteryEncounter = nil
        return true
    }

    /// Presents the reward/recruit beat and closes the session. Progress is
    /// completed inside the choice mutation, so finishing never persists; a
    /// failed save rolls the whole choice back before any beat plays.
    @discardableResult
    func finishActiveMysteryEncounter(dismiss: Bool = true) -> Bool {
        guard let mysterySession = activeMysteryEncounter else {
            return false
        }
        mysterySession.clearPersistFailure()
        if mysterySession.showsReward {
            // Progress was already completed inside resolveChoice.
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

    func dismissActiveMysteryEncounter() {
        activeMysteryEncounter = nil
    }

    @discardableResult
    internal func applyMysteryOutcome(
        _ outcome: MysteryChoiceOutcome,
        session mysterySession: MysteryEncounterSession
    ) -> Bool {
        switch outcome {
        case .failed:
            return false
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
        pinnedJourneyEventID: String?
    ) -> StageMapMessage? {
        guard !isRecruit else { return nil }

        if let labyrinthNodeID = origin.labyrinthNodeID, pinnedLabyrinthEventID == nil {
            return pinEvent(logging: "Failed to pin labyrinth mystery event") { save in
                MysteryEventPinApplier.pinLabyrinthEvent(
                    nodeID: labyrinthNodeID,
                    eventID: resolvedEventID,
                    save: &save
                )
            }
        }

        if let stage = origin.stage, pinnedJourneyEventID == nil, stage.mysteryEvent == nil {
            return pinEvent(logging: "Failed to pin journey mystery event") { save in
                MysteryEventPinApplier.pinJourneyEvent(
                    stageID: stage.id,
                    eventID: resolvedEventID,
                    save: &save
                )
            }
        }

        return nil
    }

    /// Persists one mystery-event pin; returns the shared failure message when
    /// the write fails or the applier reports no change.
    private func pinEvent(
        logging: String,
        pin: (inout PlayerSave) -> Bool
    ) -> StageMapMessage? {
        var didPinEvent = false
        let didPersist = playerSave.persistBatch(logging: logging) { save in
            didPinEvent = pin(&save)
        }
        return didPersist && didPinEvent ? nil : Self.mysteryPinFailureMessage
    }

    private static func completeMysteryProgress(
        _ session: MysteryEncounterSession,
        save: inout PlayerSave
    ) {
        StageCompletion.completeEncounter(
            stage: session.stage,
            labyrinthNodeID: session.labyrinthNodeID,
            hero: save.roster.activeHero,
            companion: save.roster.activeCompanion,
            in: GameContent.chapters,
            save: &save
        )
    }

    private static let mysteryPinFailureMessage = StageMapMessage(
        title: "Couldn't Save Progress",
        message: "This event was not saved. Stay here and try again."
    )
}
