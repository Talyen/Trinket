import Foundation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

public extension EncounterPlayMode {
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

        var outcome = MysteryChoiceOutcome.failed
        guard playerSave.persistBatch(logging: "Failed to apply mystery effects", { save in
            var randomNumberGenerator = SystemRandomNumberGenerator()
            outcome = mysterySession.resolveChoice(
                choiceID: choiceID,
                save: &save,
                using: &randomNumberGenerator,
                completeProgress: Self.completeMysteryProgress
            )
        }) else {
            mysterySession.markPersistFailed("Couldn't save progress. Stay here and try again.")
            return false
        }

        guard applyMysteryOutcome(outcome, session: mysterySession) else { return false }
        return true
    }

    /// Corrupts the selected inventory item at the Corruption Altar.
    @discardableResult
    func corruptActiveMysteryItem(itemID: String) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.showsCorruptItemChoice else { return false }

        var outcome = MysteryChoiceOutcome.failed
        guard playerSave.persistBatch(logging: "Failed to corrupt mystery item", { save in
            var randomNumberGenerator = SystemRandomNumberGenerator()
            outcome = mysterySession.corruptSelectedItem(
                itemID: itemID,
                save: &save,
                using: &randomNumberGenerator,
                completeProgress: Self.completeMysteryProgress
            )
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

    /// Completes the mystery stage/node only after persistence succeeds so a failed finish
    /// cannot clear the session while leaving progress uncleared (replay double-grants).
    /// Pass `dismiss: false` to persist a recruit reveal and keep the session for the seal beat.
    @discardableResult
    func finishActiveMysteryEncounter(dismiss: Bool = true) -> Bool {
        guard let mysterySession = activeMysteryEncounter else {
            return false
        }
        mysterySession.clearPersistFailure()
        if mysterySession.showsReward {
            // Progress was already completed inside resolveChoice.
            // Dismiss only — never re-grant.
            sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
            if dismiss {
                activeMysteryEncounter = nil
            }
            return true
        }
        guard mysterySession.showsReveal else {
            return false
        }
        guard playerSave.persistBatch(logging: "Failed to finish mystery encounter", { save in
            Self.completeMysteryProgress(mysterySession, save: &save)
        }) else {
            mysterySession.markPersistFailed(
                "Couldn't save progress. Stay here and try Recruit again."
            )
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
    func applyMysteryOutcome(
        _ outcome: MysteryChoiceOutcome,
        session mysterySession: MysteryEncounterSession
    ) -> Bool {
        switch outcome {
        case .failed:
            return false
        case .dismiss:
            activeMysteryEncounter = nil
            return true
        case .reward, .reveal, .corruptionReveal:
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
            let didPin = playerSave.persistBatch(logging: "Failed to pin labyrinth mystery event") { save in
                guard var node = save.labyrinth.nodes[labyrinthNodeID] else { return }
                node.mysteryEventID = resolvedEventID
                save.labyrinth.nodes[labyrinthNodeID] = node
            }
            if !didPin {
                return Self.mysteryPinFailureMessage
            }
        }

        if let stage = origin.stage, pinnedJourneyEventID == nil, stage.mysteryEvent == nil {
            let didPin = playerSave.persistBatch(logging: "Failed to pin journey mystery event") { save in
                save.journey.pinnedMysteryEventIDs[stage.id] = resolvedEventID
            }
            if !didPin {
                return Self.mysteryPinFailureMessage
            }
        }

        return nil
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
