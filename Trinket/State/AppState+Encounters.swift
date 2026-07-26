import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    @discardableResult
    func beginShopEncounter(
        for stage: Stage? = nil,
        labyrinthNodeID: String? = nil
    ) -> StageMapMessage? {
        guard activeShopEncounter == nil else { return nil }
        guard activeMysteryEncounter == nil else { return nil }
        guard battle.activeBattle == nil else { return nil }

        switch ShopEncounterSession.open(
            stage: stage,
            labyrinthNodeID: labyrinthNodeID,
            astralChanceBonusPercent: homestead.effects.astralChanceBonusPercent
        ) {
        case let .opened(session):
            activeShopEncounter = session
            return nil
        case .autoCompleted:
            if let labyrinthNodeID {
                return completeLabyrinthNodeOrPersistFailure(nodeID: labyrinthNodeID)
            }
            guard let stage else { return nil }
            appStateLogger.error(
                "Shop stage \(stage.id, privacy: .public) produced no offers; completing stage."
            )
            if let failure = completeStageOrPersistFailure(stage) {
                return failure
            }
            return StageMapMessage(
                title: "Shop Closed",
                message: "The merchant has nothing left to sell. You continue on."
            )
        case .unavailable:
            return nil
        }
    }

    @discardableResult
    func purchaseActiveShopOffer(offerID: String) -> Bool {
        guard let session = activeShopEncounter else { return false }
        guard !session.isPurchasing else { return false }
        guard session.offers.contains(where: { $0.id == offerID }) else { return false }
        guard !session.isSoldOut(offerID) else {
            session.markPurchaseFailed(message: "That item is already sold.")
            sfxPlayer.play(SFXID.uiDeny, volume: options.effectsVolume)
            return false
        }

        session.markPurchaseStarted()
        var purchaseResult: ShopPurchaseResult?
        do {
            try playerSave.performBatchMutation { save in
                purchaseResult = session.purchaseIntoSave(offerID: offerID, save: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to purchase shop offer: \(error.localizedDescription, privacy: .public)"
            )
            session.markPurchaseFailed(message: "Purchase failed. Try again.")
            return false
        }

        switch purchaseResult {
        case .success:
            session.markPurchaseFinished(offerID: offerID)
            sfxPlayer.play(SFXID.uiBuySell, volume: options.effectsVolume)
            return true
        case .insufficientGold, .alreadyOwned:
            session.markPurchaseFailed(
                message: purchaseResult?.failureMessage ?? "Purchase failed."
            )
            sfxPlayer.play(SFXID.uiDeny, volume: options.effectsVolume)
            return false
        case .none:
            session.markPurchaseFailed(message: "Purchase failed.")
            sfxPlayer.play(SFXID.uiDeny, volume: options.effectsVolume)
            return false
        }
    }

    /// Completes the shop stage/node only after persistence succeeds so a failed leave
    /// does not drop the session while progress stays uncleared.
    @discardableResult
    func finishActiveShopEncounter() -> Bool {
        guard let session = activeShopEncounter else { return false }
        session.clearLeaveFailure()
        var resultingJourney: JourneyProgressState?
        do {
            try playerSave.performBatchMutation { save in
                resultingJourney = session.completeProgress(
                    hero: save.roster.activeHero,
                    companion: save.roster.activeCompanion,
                    save: &save
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to leave shop encounter: \(error.localizedDescription, privacy: .public)"
            )
            session.markLeaveFailed("Couldn't save progress. Stay here and try Leave Shop again.")
            return false
        }
        if let resultingJourney {
            noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: resultingJourney))
        }
        activeShopEncounter = nil
        return true
    }

    func dismissActiveShopEncounterWithoutCompleting() {
        activeShopEncounter = nil
    }

    @discardableResult
    func beginMysteryEncounter(
        for stage: Stage? = nil,
        labyrinthNodeID: String? = nil,
        forcedEventID: String? = nil
    ) -> StageMapMessage? {
        guard activeMysteryEncounter == nil else { return nil }
        guard activeShopEncounter == nil else { return nil }
        guard battle.activeBattle == nil else { return nil }

        guard let session = MysteryEncounterSession.open(
            stage: stage,
            labyrinthNodeID: labyrinthNodeID,
            forcedEventID: forcedEventID
        ) else {
            return nil
        }

        activeMysteryEncounter = session
        sfxPlayer.play(SFXID.mysteryEvent, volume: options.effectsVolume)
        if session.event.isRecruit {
            _ = resolveActiveMysteryChoice()
        }
        return nil
    }

    /// Applies the single (or first) choice for the active mystery encounter.
    /// Recruit unlocks present the unlocked reward; choose-item choices present
    /// candidates; other outcomes complete the stage in the same persist transaction
    /// so effects cannot land without completion.
    @discardableResult
    func resolveActiveMysteryChoice(choiceID: String? = nil) -> Bool {
        guard let session = activeMysteryEncounter else { return false }
        guard session.canResolveChoice else { return false }

        var outcome = MysteryChoiceOutcome.failed
        do {
            try playerSave.performBatchMutation { save in
                var randomNumberGenerator = SystemRandomNumberGenerator()
                outcome = session.resolveChoice(
                    choiceID: choiceID,
                    save: &save,
                    using: &randomNumberGenerator
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to apply mystery effects: \(error.localizedDescription, privacy: .public)"
            )
            session.markPersistFailed("Couldn't save progress. Stay here and try again.")
            return false
        }

        return applyMysteryOutcome(outcome, session: session)
    }

    /// Grants the chosen mystery item and completes the stage/node in one transaction.
    @discardableResult
    func selectActiveMysteryItem(itemID: String) -> Bool {
        guard let session = activeMysteryEncounter else { return false }

        var outcome = MysteryChoiceOutcome.failed
        do {
            try playerSave.performBatchMutation { save in
                outcome = session.selectItem(itemID: itemID, save: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to grant mystery item: \(error.localizedDescription, privacy: .public)"
            )
            session.markPersistFailed("Couldn't save progress. Stay here and try again.")
            return false
        }

        return applyMysteryOutcome(outcome, session: session)
    }

    /// Completes the mystery stage/node only after persistence succeeds so a failed finish
    /// cannot clear the session while leaving progress uncleared (replay double-grants).
    @discardableResult
    func finishActiveMysteryEncounter() -> Bool {
        guard let session = activeMysteryEncounter else { return false }
        session.clearPersistFailure()
        if session.showsReward {
            // Progress was already completed inside resolveChoice / selectItem.
            // Dismiss only — never re-grant.
            sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
            activeMysteryEncounter = nil
            return true
        }
        var resultingJourney: JourneyProgressState?
        do {
            try playerSave.performBatchMutation { save in
                resultingJourney = session.completeProgress(save: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to finish mystery encounter: \(error.localizedDescription, privacy: .public)"
            )
            session.markPersistFailed(
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
    private func applyMysteryOutcome(
        _ outcome: MysteryChoiceOutcome,
        session: MysteryEncounterSession
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
            session.applyOutcome(outcome)
            return true
        case .reveal, .chooseItem:
            session.applyOutcome(outcome)
            return true
        }
    }
}
