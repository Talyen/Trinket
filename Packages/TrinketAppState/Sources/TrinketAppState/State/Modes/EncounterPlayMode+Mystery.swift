import Foundation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

public extension EncounterPlayMode {
    @discardableResult
    internal func beginMysteryEncounter(
        origin: PlayEncounterOrigin,
        forcedEventID: String? = nil
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
            _ = resolveActiveMysteryChoice(choiceID: nil)
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
        do {
            try playerSave.performBatchMutation { save in
                var randomNumberGenerator = SystemRandomNumberGenerator()
                outcome = mysterySession.resolveChoice(
                    choiceID: choiceID,
                    save: &save,
                    using: &randomNumberGenerator,
                    completeProgress: Self.completeMysteryProgress
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to apply mystery effects: \(error.localizedDescription, privacy: .public)"
            )
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
        do {
            try playerSave.performBatchMutation { save in
                var randomNumberGenerator = SystemRandomNumberGenerator()
                outcome = mysterySession.corruptSelectedItem(
                    itemID: itemID,
                    save: &save,
                    using: &randomNumberGenerator,
                    completeProgress: Self.completeMysteryProgress
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
        guard let mysterySession = activeMysteryEncounter else {
            return false
        }
        mysterySession.clearPersistFailure()
        if mysterySession.showsReward {
            // Progress was already completed inside resolveChoice.
            // Dismiss only — never re-grant.
            sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
            activeMysteryEncounter = nil
            return true
        }
        do {
            try playerSave.performBatchMutation { save in
                Self.completeMysteryProgress(mysterySession, save: &save)
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

    private static func completeMysteryProgress(
        _ session: MysteryEncounterSession,
        save: inout PlayerSave
    ) {
        switch session.origin {
        case let .journey(stage):
            StageCompletion.completeEncounter(
                stage: stage,
                labyrinthNodeID: nil,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                in: GameContent.chapters,
                save: &save
            )
        case let .labyrinth(nodeID):
            LabyrinthCompletion.complete(
                nodeID: nodeID,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                save: &save
            )
        }
    }
}
