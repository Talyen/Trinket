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
    let playerSave: PlayerSaveStore
    let battle: BattleSession
    let options: OptionsStore
    let sfxPlayer: SFXPlayer
    let noteMapScrollFocus: (String) -> Void
    private let completionPorts: EncounterCompletionPorts

    public var activeMysteryEncounter: MysteryEncounterSession?
    public var activeShopEncounter: ShopEncounterSession?

    init(
        playerSave: PlayerSaveStore,
        battle: BattleSession,
        options: OptionsStore,
        sfxPlayer: SFXPlayer,
        noteMapScrollFocus: @escaping (String) -> Void,
        completionPorts: EncounterCompletionPorts
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.options = options
        self.sfxPlayer = sfxPlayer
        self.noteMapScrollFocus = noteMapScrollFocus
        self.completionPorts = completionPorts
    }

    private var boundCompleteJourneyStage: (Stage) -> StageMapMessage? {
        guard let completeJourneyStage = completionPorts.completeJourneyStage else {
            preconditionFailure("EncounterPlayMode used before PlayModeGraph wired completion ports")
        }
        return completeJourneyStage
    }

    private var boundCompleteLabyrinthNode: (String) -> StageMapMessage? {
        guard let completeLabyrinthNode = completionPorts.completeLabyrinthNode else {
            preconditionFailure("EncounterPlayMode used before PlayModeGraph wired completion ports")
        }
        return completeLabyrinthNode
    }

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
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent
        ) {
        case let .opened(shopSession):
            activeShopEncounter = shopSession
            return nil
        case .autoCompleted:
            if let labyrinthNodeID {
                return boundCompleteLabyrinthNode(labyrinthNodeID)
            }
            guard let stage else { return nil }
            appStateLogger.error(
                "Shop stage \(stage.id, privacy: .public) produced no offers; completing stage."
            )
            if let failure = boundCompleteJourneyStage(stage) {
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
            sfxPlayer.play(SFXID.uiDeny, volume: options.effectsVolume)
            return false
        }

        shopSession.markPurchaseStarted()
        var purchaseResult: ShopPurchaseResult?
        do {
            try playerSave.performBatchMutation { save in
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
            sfxPlayer.play(SFXID.uiBuySell, volume: options.effectsVolume)
            return true
        case .insufficientGold, .alreadyOwned:
            shopSession.markPurchaseFailed(
                message: purchaseResult?.failureMessage ?? "Purchase failed."
            )
            sfxPlayer.play(SFXID.uiDeny, volume: options.effectsVolume)
            return false
        case .none:
            shopSession.markPurchaseFailed(message: "Purchase failed.")
            sfxPlayer.play(SFXID.uiDeny, volume: options.effectsVolume)
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
            try playerSave.performBatchMutation { save in
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
            noteMapScrollFocus(JourneyMapPresentation.scrollFocusID(for: resultingJourney))
        }
        activeShopEncounter = nil
        return true
    }

    public func dismissActiveShopEncounterWithoutCompleting() {
        activeShopEncounter = nil
    }
}

/// MainActor box filled by `PlayModeGraph` before any encounter completion call.
@MainActor
final class EncounterCompletionPorts {
    var completeJourneyStage: ((Stage) -> StageMapMessage?)?
    var completeLabyrinthNode: ((String) -> StageMapMessage?)?
}
