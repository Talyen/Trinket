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
            using: &randomNumberGenerator
        )
        guard !offers.isEmpty else {
            if let labyrinthNodeID {
                completeLabyrinthNode(nodeID: labyrinthNodeID)
                return nil
            }
            appStateLogger.error(
                "Shop stage \(resolvedStage.id, privacy: .public) produced no offers; completing stage."
            )
            completeStage(resolvedStage, hero: roster.activeHero, pet: roster.activePet)
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

    func finishActiveShopEncounter() {
        guard let session = activeShopEncounter else { return }
        activeShopEncounter = nil
        finishEncounterProgress(stage: session.stage, labyrinthNodeID: session.labyrinthNodeID)
    }

    func dismissActiveShopEncounterWithoutCompleting() {
        activeShopEncounter = nil
    }

    @discardableResult
    func beginMysteryEncounter(
        for stage: Stage? = nil,
        labyrinthNodeID: String? = nil
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
            guard let picked = pickMysteryEvent(
                authored: nil,
                using: &randomNumberGenerator
            ) else {
                completeLabyrinthNode(nodeID: labyrinthNodeID)
                return nil
            }
            event = picked
            sessionStage = Self.syntheticLabyrinthStage(
                nodeID: labyrinthNodeID,
                encounter: .mysteryEvent(eventID: event.id)
            )
        } else if let stage {
            // Journey keeps separate RNGs for pool pick vs recruit substitute (prior contract).
            var pickRNG = SystemRandomNumberGenerator()
            var picked = stage.mysteryEvent ?? GameContent.pickEligibleMysteryEvent(
                unlockedHeroIDs: roster.current.unlockedHeroIDs,
                unlockedPetIDs: roster.current.unlockedPetIDs,
                using: &pickRNG
            )
            var substituteRNG = SystemRandomNumberGenerator()
            guard resolveRecruitSubstitution(event: &picked, using: &substituteRNG) else {
                completeStage(stage, hero: roster.activeHero, pet: roster.activePet)
                return nil
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
    /// Recruit unlocks transition to the reveal phase; other outcomes complete the stage.
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
            }
        } catch {
            appStateLogger.error(
                "Failed to apply mystery effects: \(error.localizedDescription, privacy: .public)"
            )
            session.markResolvedWithoutReveal()
            return false
        }

        if let unlockedID = applyResult.unlockedCombatantIDs.first
            ?? session.event.unlockCombatantID.flatMap({ id in
                roster.current.isCombatantUnlocked(id: id) ? id : nil
            }) {
            session.presentReveal(unlockedCombatantID: unlockedID)
            return true
        }

        finishActiveMysteryEncounter()
        return true
    }

    func finishActiveMysteryEncounter() {
        guard let session = activeMysteryEncounter else { return }
        activeMysteryEncounter = nil
        finishEncounterProgress(stage: session.stage, labyrinthNodeID: session.labyrinthNodeID)
    }

    func dismissActiveMysteryEncounterWithoutCompleting() {
        activeMysteryEncounter = nil
    }

    private func finishEncounterProgress(stage: Stage, labyrinthNodeID: String?) {
        if let labyrinthNodeID {
            completeLabyrinthNode(nodeID: labyrinthNodeID)
        } else {
            completeStage(stage, hero: roster.activeHero, pet: roster.activePet)
        }
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

    private func pickMysteryEvent<RNG: RandomNumberGenerator>(
        authored: MysteryEvent?,
        using randomNumberGenerator: inout RNG
    ) -> MysteryEvent? {
        var event = authored ?? GameContent.pickEligibleMysteryEvent(
            unlockedHeroIDs: roster.current.unlockedHeroIDs,
            unlockedPetIDs: roster.current.unlockedPetIDs,
            using: &randomNumberGenerator
        )
        guard resolveRecruitSubstitution(event: &event, using: &randomNumberGenerator) else {
            return nil
        }
        return event
    }

    /// Returns `false` when the recruit is already unlocked and no substitute remains.
    private func resolveRecruitSubstitution<RNG: RandomNumberGenerator>(
        event: inout MysteryEvent,
        using randomNumberGenerator: inout RNG
    ) -> Bool {
        guard let combatantID = event.unlockCombatantID,
              roster.current.isCombatantUnlocked(id: combatantID)
        else {
            return true
        }
        let eligible = RecruitMysteryEventPool.eligible(
            unlockedHeroIDs: roster.current.unlockedHeroIDs,
            unlockedPetIDs: roster.current.unlockedPetIDs
        ).filter { $0.id != event.id }
        guard let substitute = eligible.randomElement(using: &randomNumberGenerator) else {
            return false
        }
        event = substitute
        return true
    }
}
