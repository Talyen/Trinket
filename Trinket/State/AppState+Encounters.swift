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

        let resolvedStage: Stage
        if let labyrinthNodeID {
            resolvedStage = Self.syntheticLabyrinthStage(
                nodeID: labyrinthNodeID,
                encounter: .shop
            )
        } else if let stage, case .shop = stage.encounter {
            resolvedStage = stage
        } else {
            return nil
        }

        var randomNumberGenerator = SeededRandomNumberGenerator(
            seed: ShopOfferGenerator.seed(forStageID: resolvedStage.id)
        )
        let offers = ShopOfferGenerator.generateOffers(
            stageID: resolvedStage.id,
            astralChanceBonusPercent: homestead.effects.astralChanceBonusPercent,
            using: &randomNumberGenerator
        )
        guard !offers.isEmpty else {
            if let labyrinthNodeID {
                return completeLabyrinthNodeOrPersistFailure(nodeID: labyrinthNodeID)
            }
            appStateLogger.error(
                "Shop stage \(resolvedStage.id, privacy: .public) produced no offers; completing stage."
            )
            if let failure = completeStageOrPersistFailure(resolvedStage) {
                return failure
            }
            return StageMapMessage(
                title: "Shop Closed",
                message: "The merchant has nothing left to sell. You continue on."
            )
        }

        activeShopEncounter = ShopEncounterSession(
            stage: resolvedStage,
            offers: offers,
            labyrinthNodeID: labyrinthNodeID
        )
        return nil
    }

    @discardableResult
    func purchaseActiveShopOffer(offerID: String) -> Bool {
        guard let session = activeShopEncounter else { return false }
        guard !session.isPurchasing else { return false }
        guard let offer = session.offers.first(where: { $0.id == offerID }) else { return false }
        guard !session.isSoldOut(offerID) else {
            session.markPurchaseFailed(message: "That item is already sold.")
            sfxPlayer.play(SFXID.uiDeny, volume: options.effectsVolume)
            return false
        }

        session.markPurchaseStarted()
        var purchasedItem: InventoryItem?
        var failureMessage: String?
        do {
            try playerSave.performBatchMutation { save in
                let result = ShopPurchaseApplier.purchase(
                    offer: offer,
                    visitToken: session.visitToken,
                    stageID: session.stage.id,
                    save: &save
                )
                switch result {
                case let .success(item):
                    purchasedItem = item
                case .insufficientGold:
                    failureMessage = "Not enough Gold."
                case .alreadyOwned:
                    failureMessage = "That item is already sold."
                }
            }
        } catch {
            appStateLogger.error(
                "Failed to purchase shop offer: \(error.localizedDescription, privacy: .public)"
            )
            session.markPurchaseFailed(message: "Purchase failed. Try again.")
            return false
        }

        if let purchasedItem {
            session.markPurchaseFinished(offerID: offerID, itemName: purchasedItem.displayName)
            sfxPlayer.play(SFXID.uiBuySell, volume: options.effectsVolume)
            return true
        }

        session.markPurchaseFailed(message: failureMessage ?? "Purchase failed.")
        sfxPlayer.play(SFXID.uiDeny, volume: options.effectsVolume)
        return false
    }

    /// Completes the shop stage/node only after persistence succeeds so a failed leave
    /// does not drop the session while progress stays uncleared.
    @discardableResult
    func finishActiveShopEncounter() -> Bool {
        guard let session = activeShopEncounter else { return false }
        session.clearLeaveFailure()
        guard finishEncounterProgress(
            stage: session.stage,
            labyrinthNodeID: session.labyrinthNodeID
        ) else {
            session.markLeaveFailed("Couldn't save progress. Stay here and try Leave Shop again.")
            return false
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

        let event: MysteryEvent
        let sessionStage: Stage
        if let labyrinthNodeID {
            var randomNumberGenerator = SeededRandomNumberGenerator(
                seed: GameContent.stableSeed(for: "labyrinth-mystery-\(labyrinthNodeID)")
            )
            guard let picked = GameContent.resolveMysteryEncounterEvent(
                authored: nil,
                unlockedHeroIDs: roster.unlockedHeroIDs,
                unlockedCompanionIDs: roster.unlockedCompanionIDs,
                using: &randomNumberGenerator
            ) else {
                return completeLabyrinthNodeOrPersistFailure(nodeID: labyrinthNodeID)
            }
            event = picked
            sessionStage = Self.syntheticLabyrinthStage(
                nodeID: labyrinthNodeID,
                encounter: .mysteryEvent(eventID: event.id)
            )
        } else if let stage {
            let authoredEvent = forcedEventID.flatMap { GameContent.mysteryEvent(matching: $0) }
                ?? stage.mysteryEvent
            var pickRNG = SystemRandomNumberGenerator()
            guard let picked = GameContent.resolveMysteryEncounterEvent(
                authored: authoredEvent,
                unlockedHeroIDs: roster.unlockedHeroIDs,
                unlockedCompanionIDs: roster.unlockedCompanionIDs,
                using: &pickRNG
            ) else {
                return completeStageOrPersistFailure(stage)
            }
            event = picked
            sessionStage = stage
        } else {
            return nil
        }

        activeMysteryEncounter = MysteryEncounterSession(
            stage: sessionStage,
            event: event,
            combatant: GameContent.combatant(forMysteryEvent: event),
            labyrinthNodeID: labyrinthNodeID
        )
        sfxPlayer.play(SFXID.mysteryEvent, volume: options.effectsVolume)
        return nil
    }

    /// Applies the single (or first) choice for the active mystery encounter.
    /// Recruit unlocks transition to the reveal phase; choose-item choices present
    /// candidates; other outcomes complete the stage in the same persist transaction
    /// so effects cannot land without completion.
    @discardableResult
    func resolveActiveMysteryChoice(choiceID: String? = nil) -> Bool {
        guard let session = activeMysteryEncounter else { return false }
        guard !session.isResolvingChoice else { return false }
        session.markChoiceStarted()

        let choice = session.event.choices.first { $0.id == choiceID }
            ?? session.event.choices.first
        guard let choice else {
            session.markResolvedWithoutReveal()
            return false
        }

        var applyResult = MysteryEffectApplyResult()
        var resultingJourney: JourneyProgressState?
        do {
            try playerSave.performBatchMutation { save in
                var randomNumberGenerator = SystemRandomNumberGenerator()
                applyResult = MysteryEffectApplier.apply(
                    choice.effects,
                    stageID: session.stage.id,
                    choiceID: choice.id,
                    hero: save.roster.activeHero,
                    save: &save,
                    using: &randomNumberGenerator
                )
                if !applyResult.unlockedCombatantIDs.isEmpty {
                    // Journey recruits delay completion for the reveal ceremony; authored
                    // reopen safety auto-completes if already unlocked. Labyrinth mystery
                    // events are re-rolled from the unlocked roster, so complete the node
                    // with the unlock to prevent kill/relaunch double-recruits.
                    if session.labyrinthNodeID != nil {
                        resultingJourney = completeMysteryProgress(session: session, save: &save)
                    }
                    return
                }
                // Choose-item presents candidates next; grant + complete on selection.
                guard applyResult.chooseItemCandidates.isEmpty else { return }
                resultingJourney = completeMysteryProgress(session: session, save: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to apply mystery effects: \(error.localizedDescription, privacy: .public)"
            )
            session.markPersistFailed("Couldn't save progress. Stay here and try again.")
            return false
        }

        if let unlockedID = applyResult.unlockedCombatantIDs.first {
            session.presentReveal(unlockedCombatantID: unlockedID)
            return true
        }

        if !applyResult.chooseItemCandidates.isEmpty {
            session.presentItemChoice(candidates: applyResult.chooseItemCandidates)
            return true
        }

        dismissMysteryAfterProgress(resultingJourney: resultingJourney)
        return true
    }

    /// Grants the chosen mystery item and completes the stage/node in one transaction.
    @discardableResult
    func selectActiveMysteryItem(itemID: String) -> Bool {
        guard let session = activeMysteryEncounter else { return false }
        guard session.showsItemChoice else { return false }
        guard !session.isResolvingChoice else { return false }
        guard let item = session.itemCandidates.first(where: { $0.id == itemID }) else {
            return false
        }

        session.markChoiceStarted()
        var resultingJourney: JourneyProgressState?
        do {
            try playerSave.performBatchMutation { save in
                MysteryEffectApplier.grantChosenItem(item, save: &save)
                resultingJourney = completeMysteryProgress(session: session, save: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to grant mystery item: \(error.localizedDescription, privacy: .public)"
            )
            session.markPersistFailed("Couldn't save progress. Stay here and try again.")
            return false
        }

        dismissMysteryAfterProgress(resultingJourney: resultingJourney)
        return true
    }

    /// Completes the mystery stage/node only after persistence succeeds so a failed finish
    /// cannot clear the session while leaving progress uncleared (replay double-grants).
    @discardableResult
    func finishActiveMysteryEncounter() -> Bool {
        guard let session = activeMysteryEncounter else { return false }
        session.clearPersistFailure()
        guard finishEncounterProgress(
            stage: session.stage,
            labyrinthNodeID: session.labyrinthNodeID
        ) else {
            session.markPersistFailed(
                "Couldn't save progress. Stay here and try Recruit again."
            )
            return false
        }
        activeMysteryEncounter = nil
        return true
    }

    func dismissActiveMysteryEncounterWithoutCompleting() {
        activeMysteryEncounter = nil
    }

    @discardableResult
    private func finishEncounterProgress(stage: Stage, labyrinthNodeID: String?) -> Bool {
        if let labyrinthNodeID {
            return completeLabyrinthNode(nodeID: labyrinthNodeID)
        }
        guard let resultingJourney = persistStageCompletions(
            [stage],
            hero: roster.activeHero,
            companion: roster.activeCompanion
        ) else {
            return false
        }
        noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: resultingJourney))
        return true
    }

    /// Completes the active mystery's stage or Labyrinth node inside an open save mutation.
    @discardableResult
    private func completeMysteryProgress(
        session: MysteryEncounterSession,
        save: inout PlayerSave
    ) -> JourneyProgressState? {
        if let labyrinthNodeID = session.labyrinthNodeID {
            LabyrinthCompletion.complete(
                nodeID: labyrinthNodeID,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                save: &save
            )
            return nil
        }
        StageCompletion.complete(
            session.stage,
            hero: save.roster.activeHero,
            companion: save.roster.activeCompanion,
            in: GameContent.chapters,
            save: &save
        )
        return save.journey
    }

    private func dismissMysteryAfterProgress(resultingJourney: JourneyProgressState?) {
        if let resultingJourney {
            noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: resultingJourney))
        }
        activeMysteryEncounter = nil
    }

    private static func syntheticLabyrinthStage(
        nodeID: String,
        encounter: StageEncounter
    ) -> Stage {
        Stage(
            id: nodeID,
            chapterID: "labyrinth",
            chapterNumber: 0,
            stageNumber: 0,
            flavorText: "A path in The Labyrinth.",
            encounter: encounter,
            rewards: .empty
        )
    }
}
