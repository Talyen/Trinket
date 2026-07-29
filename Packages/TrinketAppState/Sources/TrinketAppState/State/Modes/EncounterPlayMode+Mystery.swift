import Foundation
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

public extension EncounterPlayMode {
    @discardableResult
    internal func beginMysteryEncounter(
        for stage: Stage? = nil,
        labyrinthNodeID: String? = nil,
        forcedEventID: String? = nil
    ) -> StageMapMessage? {
        guard activeMysteryEncounter == nil else { return nil }
        guard activeShopEncounter == nil else { return nil }
        guard battle.activeBattle == nil else { return nil }

        let pickContext = mysteryEventPickContext(for: stage, labyrinthNodeID: labyrinthNodeID)
        let pinnedLabyrinthEventID = labyrinthNodeID.flatMap {
            playerSave.labyrinth.nodes[$0]?.mysteryEventID
        }

        guard let opened = MysteryEncounterSession.open(
            stage: stage,
            labyrinthNodeID: labyrinthNodeID,
            forcedEventID: forcedEventID,
            pickContext: pickContext,
            pinnedLabyrinthEventID: pinnedLabyrinthEventID
        ) else {
            return nil
        }

        if let labyrinthNodeID,
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

        activeMysteryEncounter = opened.session
        sfxPlayer.play(SFXID.mysteryEvent, volume: options.effectsVolume)
        if opened.session.event.isRecruit {
            _ = resolveActiveMysteryChoice()
        }
        return nil
    }

    private func mysteryEventPickContext(
        for stage: Stage?,
        labyrinthNodeID: String?
    ) -> MysteryEventPickContext {
        let allowsCorruptionAltar: Bool = {
            if labyrinthNodeID != nil {
                return true
            }
            guard let stage else { return false }
            return stage.chapterNumber >= 2
        }()
        return MysteryEventPickContext(
            allowsCorruptionAltar: allowsCorruptionAltar,
            hasEligibleCorruptTarget: !ItemCorruption.eligibleTargets(
                in: playerSave.inventory
            ).isEmpty,
            corruptionAltarCooldownRemaining: playerSave.currentSave.corruptionAltarCooldownRemaining
        )
    }

    /// Applies the single (or first) choice for the active mystery encounter.
    @discardableResult
    func resolveActiveMysteryChoice(choiceID: String? = nil) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.canResolveChoice else { return false }

        var outcome = MysteryChoiceOutcome.failed
        do {
            try playerSave.performBatchMutation { save in
                var randomNumberGenerator = SystemRandomNumberGenerator()
                outcome = mysterySession.resolveChoice(
                    choiceID: choiceID,
                    save: &save,
                    using: &randomNumberGenerator
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to apply mystery effects: \(error.localizedDescription, privacy: .public)"
            )
            mysterySession.markPersistFailed("Couldn't save progress. Stay here and try again.")
            return false
        }

        return applyMysteryOutcome(outcome, session: mysterySession)
    }

    /// Grants the chosen mystery item and completes the stage/node in one transaction.
    @discardableResult
    func selectActiveMysteryItem(itemID: String) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }

        var outcome = MysteryChoiceOutcome.failed
        do {
            try playerSave.performBatchMutation { save in
                outcome = mysterySession.selectItem(itemID: itemID, save: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to grant mystery item: \(error.localizedDescription, privacy: .public)"
            )
            mysterySession.markPersistFailed("Couldn't save progress. Stay here and try again.")
            return false
        }

        return applyMysteryOutcome(outcome, session: mysterySession)
    }

    /// Corrupts the selected inventory item at the Corruption Altar.
    @discardableResult
    func corruptActiveMysteryItem(itemID: String) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.showsCorruptItemChoice else { return false }

        var outcome = MysteryChoiceOutcome.failed
        do {
            try playerSave.performBatchMutation { save in
                var randomNumberGenerator = SystemRandomNumberGenerator()
                outcome = mysterySession.corruptSelectedItem(
                    itemID: itemID,
                    save: &save,
                    using: &randomNumberGenerator
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
    func finishActiveMysteryEncounter() -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        mysterySession.clearPersistFailure()
        if mysterySession.showsReward {
            // Progress was already completed inside resolveChoice / selectItem.
            // Dismiss only — never re-grant.
            sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
            activeMysteryEncounter = nil
            return true
        }
        var resultingJourney: JourneyProgressState?
        do {
            try playerSave.performBatchMutation { save in
                resultingJourney = mysterySession.completeProgress(save: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to finish mystery encounter: \(error.localizedDescription, privacy: .public)"
            )
            mysterySession.markPersistFailed(
                "Couldn't save progress. Stay here and try Recruit again."
            )
            return false
        }
        if let resultingJourney {
            noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: resultingJourney))
        }
        sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
        activeMysteryEncounter = nil
        return true
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
        case let .dismiss(journey):
            if let journey {
                noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: journey))
            }
            activeMysteryEncounter = nil
            return true
        case let .reward(_, journey):
            if let journey {
                noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: journey))
            }
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
