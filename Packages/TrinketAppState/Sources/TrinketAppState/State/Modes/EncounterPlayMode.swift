import Foundation
import Observation
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

/// Shared shop and mystery encounter flow for journey stages and labyrinth nodes.
@MainActor
@Observable
public final class EncounterPlayMode {
    private weak var sessionRef: PlaySession?

    public var activeMysteryEncounter: MysteryEncounterSession?
    public var activeShopEncounter: ShopEncounterSession?

    func attach(to session: PlaySession) {
        sessionRef = session
    }

    private var session: PlaySession {
        guard let sessionRef else {
            preconditionFailure("EncounterPlayMode used before attach")
        }
        return sessionRef
    }

    @discardableResult
    func beginShopEncounter(
        for stage: Stage? = nil,
        labyrinthNodeID: String? = nil
    ) -> StageMapMessage? {
        guard activeShopEncounter == nil else { return nil }
        guard activeMysteryEncounter == nil else { return nil }
        guard session.battle.activeBattle == nil else { return nil }

        switch ShopEncounterSession.open(
            stage: stage,
            labyrinthNodeID: labyrinthNodeID,
            astralChanceBonusPercent: session.playerSave.homestead.effects.astralChanceBonusPercent
        ) {
        case let .opened(shopSession):
            activeShopEncounter = shopSession
            return nil
        case .autoCompleted:
            if let labyrinthNodeID {
                return session.labyrinth.completeNodeOrPersistFailure(nodeID: labyrinthNodeID)
            }
            guard let stage else { return nil }
            appStateLogger.error(
                "Shop stage \(stage.id, privacy: .public) produced no offers; completing stage."
            )
            if let failure = session.journey.completeStageOrPersistFailure(stage) {
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
    public func purchaseActiveShopOffer(offerID: String) -> Bool {
        guard let shopSession = activeShopEncounter else { return false }
        guard !shopSession.isPurchasing else { return false }
        guard let offer = shopSession.offers.first(where: { $0.id == offerID }) else { return false }
        guard !shopSession.isSoldOut(offerID) else {
            shopSession.markPurchaseFailed(message: "That item is already sold.")
            session.sfxPlayer.play(SFXID.uiDeny, volume: session.options.effectsVolume)
            return false
        }

        shopSession.markPurchaseStarted()
        var purchaseResult: ShopPurchaseResult?
        do {
            try session.playerSave.performBatchMutation { save in
                purchaseResult = ShopPurchaseApplier.purchase(
                    offer: offer,
                    visitToken: shopSession.visitToken,
                    stageID: shopSession.stage.id,
                    save: &save
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to purchase shop offer: \(error.localizedDescription, privacy: .public)"
            )
            shopSession.markPurchaseFailed(message: "Purchase failed. Try again.")
            return false
        }

        switch purchaseResult {
        case .success:
            shopSession.markPurchaseFinished(offerID: offerID)
            session.sfxPlayer.play(SFXID.uiBuySell, volume: session.options.effectsVolume)
            return true
        case .insufficientGold, .alreadyOwned:
            shopSession.markPurchaseFailed(
                message: purchaseResult?.failureMessage ?? "Purchase failed."
            )
            session.sfxPlayer.play(SFXID.uiDeny, volume: session.options.effectsVolume)
            return false
        case .none:
            shopSession.markPurchaseFailed(message: "Purchase failed.")
            session.sfxPlayer.play(SFXID.uiDeny, volume: session.options.effectsVolume)
            return false
        }
    }

    /// Completes the shop stage/node only after persistence succeeds so a failed leave
    /// does not drop the session while progress stays uncleared.
    @discardableResult
    public func finishActiveShopEncounter() -> Bool {
        guard let shopSession = activeShopEncounter else { return false }
        shopSession.clearLeaveFailure()
        var resultingJourney: JourneyProgressState?
        do {
            try session.playerSave.performBatchMutation { save in
                resultingJourney = StageCompletion.completeEncounter(
                    stage: shopSession.stage,
                    labyrinthNodeID: shopSession.labyrinthNodeID,
                    hero: save.roster.activeHero,
                    companion: save.roster.activeCompanion,
                    in: GameContent.chapters,
                    save: &save
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to leave shop encounter: \(error.localizedDescription, privacy: .public)"
            )
            shopSession.markLeaveFailed("Couldn't save progress. Stay here and try Leave Shop again.")
            return false
        }
        if let resultingJourney {
            session.noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: resultingJourney))
        }
        activeShopEncounter = nil
        return true
    }

    public func dismissActiveShopEncounterWithoutCompleting() {
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
        guard session.battle.activeBattle == nil else { return nil }

        let pickContext = mysteryEventPickContext(for: stage, labyrinthNodeID: labyrinthNodeID)
        let pinnedLabyrinthEventID = labyrinthNodeID.flatMap {
            session.playerSave.labyrinth.nodes[$0]?.mysteryEventID
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
                try session.playerSave.performBatchMutation { save in
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
        session.sfxPlayer.play(SFXID.mysteryEvent, volume: session.options.effectsVolume)
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
                in: session.playerSave.inventory
            ).isEmpty,
            corruptionAltarCooldownRemaining: session.playerSave.currentSave.corruptionAltarCooldownRemaining
        )
    }

    /// Applies the single (or first) choice for the active mystery encounter.
    @discardableResult
    public func resolveActiveMysteryChoice(choiceID: String? = nil) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.canResolveChoice else { return false }

        var outcome = MysteryChoiceOutcome.failed
        do {
            try session.playerSave.performBatchMutation { save in
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
    public func selectActiveMysteryItem(itemID: String) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }

        var outcome = MysteryChoiceOutcome.failed
        do {
            try session.playerSave.performBatchMutation { save in
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
    public func corruptActiveMysteryItem(itemID: String) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.showsCorruptItemChoice else { return false }

        var outcome = MysteryChoiceOutcome.failed
        do {
            try session.playerSave.performBatchMutation { save in
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
        session.sfxPlayer.play(SFXID.victory, volume: session.options.effectsVolume)
        activeMysteryEncounter = nil
        return true
    }

    /// Completes the mystery stage/node only after persistence succeeds so a failed finish
    /// cannot clear the session while leaving progress uncleared (replay double-grants).
    @discardableResult
    public func finishActiveMysteryEncounter() -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        mysterySession.clearPersistFailure()
        if mysterySession.showsReward {
            // Progress was already completed inside resolveChoice / selectItem.
            // Dismiss only — never re-grant.
            session.sfxPlayer.play(SFXID.victory, volume: session.options.effectsVolume)
            activeMysteryEncounter = nil
            return true
        }
        var resultingJourney: JourneyProgressState?
        do {
            try session.playerSave.performBatchMutation { save in
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
            session.noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: resultingJourney))
        }
        session.sfxPlayer.play(SFXID.victory, volume: session.options.effectsVolume)
        activeMysteryEncounter = nil
        return true
    }

    public func dismissActiveMysteryEncounterWithoutCompleting() {
        activeMysteryEncounter = nil
    }

    @discardableResult
    private func applyMysteryOutcome(
        _ outcome: MysteryChoiceOutcome,
        session mysterySession: MysteryEncounterSession
    ) -> Bool {
        switch outcome {
        case .failed:
            return false
        case let .dismiss(journey):
            if let journey {
                session.noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: journey))
            }
            activeMysteryEncounter = nil
            return true
        case let .reward(_, journey):
            if let journey {
                session.noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: journey))
            }
            mysterySession.applyOutcome(outcome)
            return true
        case .reveal, .chooseItem:
            mysterySession.applyOutcome(outcome)
            return true
        case .selectCorruptItem:
            mysterySession.applyOutcome(outcome, inventory: session.playerSave.inventory)
            return true
        case .corruptionReveal:
            mysterySession.applyOutcome(outcome)
            return true
        }
    }
}
