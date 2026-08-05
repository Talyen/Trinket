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

extension EncounterPlayMode {
    @discardableResult
    func beginMysteryEncounter(
        origin: PlayEncounterOrigin,
        forcedEventID: String? = nil,
        completeProgress: MysteryProgressCompletion? = nil
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
            _ = resolveActiveMysteryChoice(choiceID: nil, completeProgress: completeProgress)
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
    public func resolveActiveMysteryChoice(choiceID: String? = nil) -> Bool {
        resolveActiveMysteryChoice(choiceID: choiceID, completeProgress: nil)
    }

    @discardableResult
    func resolveActiveMysteryChoice(
        choiceID: String?,
        completeProgress: MysteryProgressCompletion?
    ) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.canResolveChoice else { return false }

        let progressClosure = completeProgress ?? Self.completeMysteryProgress
        var outcome = MysteryChoiceOutcome.failed
        do {
            try playerSave.performBatchMutation { save in
                var randomNumberGenerator = SystemRandomNumberGenerator()
                outcome = mysterySession.resolveChoice(
                    choiceID: choiceID,
                    save: &save,
                    using: &randomNumberGenerator,
                    completeProgress: progressClosure
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
        noteMysteryMapFocus(for: outcome)
        return true
    }

    /// Corrupts the selected inventory item at the Corruption Altar.
    @discardableResult
    public func corruptActiveMysteryItem(itemID: String) -> Bool {
        corruptActiveMysteryItem(itemID: itemID, completeProgress: nil)
    }

    @discardableResult
    func corruptActiveMysteryItem(
        itemID: String,
        completeProgress: MysteryProgressCompletion?
    ) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.showsCorruptItemChoice else { return false }

        let progressClosure = completeProgress ?? Self.completeMysteryProgress
        var outcome = MysteryChoiceOutcome.failed
        do {
            try playerSave.performBatchMutation { save in
                var randomNumberGenerator = SystemRandomNumberGenerator()
                outcome = mysterySession.corruptSelectedItem(
                    itemID: itemID,
                    save: &save,
                    using: &randomNumberGenerator,
                    completeProgress: progressClosure
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

    public func cancelActiveMysteryCorruptSelection() {
        guard let mysterySession = activeMysteryEncounter, mysterySession.showsCorruptItemChoice else {
            return
        }
        mysterySession.returnToReading()
    }

    /// Dismisses the corruption reveal after the player acknowledges the outcome.
    @discardableResult
    public func finishActiveMysteryCorruptionReveal() -> Bool {
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
    public func finishActiveMysteryEncounter() -> Bool {
        finishActiveMysteryEncounter(completeProgress: nil)
    }

    @discardableResult
    func finishActiveMysteryEncounter(
        completeProgress: MysteryProgressCompletion?
    ) -> Bool {
        let result = finishActiveMysteryEncounterResult(completeProgress: completeProgress)
        if let journey = result.journey {
            noteMapScrollFocus?(journey.mapScrollFocusID())
        }
        return result.didFinish
    }

    func finishActiveMysteryEncounterResult(
        completeProgress: MysteryProgressCompletion? = nil
    ) -> MysteryEncounterFinishResult {
        guard let mysterySession = activeMysteryEncounter else {
            return MysteryEncounterFinishResult(didFinish: false, journey: nil)
        }
        mysterySession.clearPersistFailure()
        if mysterySession.showsReward {
            // Progress was already completed inside resolveChoice.
            // Dismiss only — never re-grant.
            sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
            activeMysteryEncounter = nil
            return MysteryEncounterFinishResult(didFinish: true, journey: nil)
        }
        let progressClosure = completeProgress ?? Self.completeMysteryProgress
        var resultingJourney: JourneyProgressState?
        do {
            try playerSave.performBatchMutation { save in
                resultingJourney = progressClosure(mysterySession, &save)
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

    public func dismissActiveMysteryEncounterWithoutCompleting() {
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
        case .reward:
            mysterySession.applyOutcome(outcome)
            return true
        case .reveal:
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

    private static func completeMysteryProgress(
        _ session: MysteryEncounterSession,
        save: inout PlayerSave
    ) -> JourneyProgressState? {
        switch session.origin {
        case let .journey(stage):
            return StageCompletion.completeEncounter(
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
            return nil
        }
    }

    private func noteMysteryMapFocus(for outcome: MysteryChoiceOutcome) {
        let journey: JourneyProgressState? = switch outcome {
        case let .dismiss(resultingJourney): resultingJourney
        case let .reward(_, resultingJourney): resultingJourney
        default: nil
        }
        if let journey {
            noteMapScrollFocus?(journey.mapScrollFocusID())
        }
    }
}
