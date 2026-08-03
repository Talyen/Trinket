import Foundation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

struct MysteryEncounterFinishResult {
    let didFinish: Bool
    let journey: JourneyProgressState?
}

public extension EncounterPlayMode {
    @discardableResult
    internal func beginMysteryEncounter(
        origin: PlayEncounterOrigin,
        forcedEventID: String? = nil,
        completeProgress: @escaping MysteryProgressCompletion
    ) -> StageMapMessage? {
        guard activeMysteryEncounter == nil else { return nil }
        guard activeShopEncounter == nil else { return nil }
        guard battle.lifecyclePhase != .active else { return nil }

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
            pickContext: pickContext,
            pinnedLabyrinthEventID: pinnedLabyrinthEventID,
            pinnedJourneyEventID: pinnedJourneyEventID
        )

        if let labyrinthNodeID = origin.labyrinthNodeID,
           pinnedLabyrinthEventID == nil,
           !opened.session.event.isRecruit {
            do {
                try playerSave.performBatchMutation { save in
                    guard var node = save.labyrinth.nodes[labyrinthNodeID] else { return }
                    node.mysteryEventID = opened.resolvedEventID
                    save.labyrinth.nodes[labyrinthNodeID] = node
                }
            } catch {
                appStateLogger.error(
                    "Failed to pin labyrinth mystery event: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        if let stage = origin.stage,
           pinnedJourneyEventID == nil,
           !opened.session.event.isRecruit,
           stage.mysteryEvent == nil {
            do {
                try playerSave.performBatchMutation { save in
                    save.journey.pinnedMysteryEventIDs[stage.id] = opened.resolvedEventID
                }
            } catch {
                appStateLogger.error(
                    "Failed to pin journey mystery event: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        activeMysteryEncounter = opened.session
        sfxPlayer.play(SFXID.mysteryEvent, volume: options.effectsVolume)
        if opened.session.event.isRecruit {
            _ = resolveActiveMysteryChoice(completeProgress: completeProgress)
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
    internal func resolveActiveMysteryChoice(
        choiceID: String? = nil,
        completeProgress: @escaping MysteryProgressCompletion
    ) -> MysteryChoiceOutcome? {
        guard let mysterySession = activeMysteryEncounter else { return nil }
        guard mysterySession.canResolveChoice else { return nil }

        var outcome = MysteryChoiceOutcome.failed
        do {
            try playerSave.performBatchMutation { save in
                var randomNumberGenerator = SystemRandomNumberGenerator()
                outcome = mysterySession.resolveChoice(
                    choiceID: choiceID,
                    save: &save,
                    using: &randomNumberGenerator,
                    completeProgress: completeProgress
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to apply mystery effects: \(error.localizedDescription, privacy: .public)"
            )
            mysterySession.markPersistFailed("Couldn't save progress. Stay here and try again.")
            return nil
        }

        guard applyMysteryOutcome(outcome, session: mysterySession) else { return nil }
        return outcome
    }

    /// Grants the chosen mystery item and completes the stage/node in one transaction.
    @discardableResult
    internal func selectActiveMysteryItem(
        itemID: String,
        completeProgress: @escaping MysteryProgressCompletion
    ) -> MysteryChoiceOutcome? {
        guard let mysterySession = activeMysteryEncounter else { return nil }

        var outcome = MysteryChoiceOutcome.failed
        do {
            try playerSave.performBatchMutation { save in
                outcome = mysterySession.selectItem(
                    itemID: itemID,
                    save: &save,
                    completeProgress: completeProgress
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to grant mystery item: \(error.localizedDescription, privacy: .public)"
            )
            mysterySession.markPersistFailed("Couldn't save progress. Stay here and try again.")
            return nil
        }

        guard applyMysteryOutcome(outcome, session: mysterySession) else { return nil }
        return outcome
    }

    /// Corrupts the selected inventory item at the Corruption Altar.
    @discardableResult
    internal func corruptActiveMysteryItem(
        itemID: String,
        completeProgress: @escaping MysteryProgressCompletion
    ) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.showsCorruptItemChoice else { return false }

        var outcome = MysteryChoiceOutcome.failed
        do {
            try playerSave.performBatchMutation { save in
                var randomNumberGenerator = SystemRandomNumberGenerator()
                outcome = mysterySession.corruptSelectedItem(
                    itemID: itemID,
                    save: &save,
                    using: &randomNumberGenerator,
                    completeProgress: completeProgress
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to corrupt mystery item: \(error.localizedDescription, privacy: .public)"
            )
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
    @discardableResult
    internal func finishActiveMysteryEncounter(
        completeProgress: @escaping MysteryProgressCompletion
    ) -> MysteryEncounterFinishResult {
        guard let mysterySession = activeMysteryEncounter else {
            return MysteryEncounterFinishResult(didFinish: false, journey: nil)
        }
        mysterySession.clearPersistFailure()
        if mysterySession.showsReward {
            // Progress was already completed inside resolveChoice / selectItem.
            // Dismiss only — never re-grant.
            sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
            activeMysteryEncounter = nil
            return MysteryEncounterFinishResult(didFinish: true, journey: nil)
        }
        var resultingJourney: JourneyProgressState?
        do {
            try playerSave.performBatchMutation { save in
                resultingJourney = completeProgress(mysterySession, &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to finish mystery encounter: \(error.localizedDescription, privacy: .public)"
            )
            mysterySession.markPersistFailed(
                "Couldn't save progress. Stay here and try Recruit again."
            )
            return MysteryEncounterFinishResult(didFinish: false, journey: nil)
        }
        sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
        activeMysteryEncounter = nil
        return MysteryEncounterFinishResult(didFinish: true, journey: resultingJourney)
    }

    func dismissActiveMysteryEncounterWithoutCompleting() {
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
            return true
        case .reveal, .chooseItem:
            mysterySession.applyOutcome(outcome)
            return true
        case .selectCorruptItem:
            mysterySession.applyOutcome(outcome, inventory: playerSave.inventory)
            return true
        case .corruptionReveal:
            mysterySession.applyOutcome(outcome)
            return true
        }
    }
}
