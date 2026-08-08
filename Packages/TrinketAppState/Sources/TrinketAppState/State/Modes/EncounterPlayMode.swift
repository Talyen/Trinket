import Foundation
import Observation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketPersistence

/// Shared shop and mystery encounter flow for journey stages and labyrinth nodes.
@MainActor
@Observable
public final class EncounterPlayMode {
    public let playerSave: PlayerSaveStore
    public let battle: any BattleRuntime
    let options: OptionsStore
    let sfxPlayer: SFXPlayer

    public var activeMysteryEncounter: MysteryEncounterSession?
    public var activeShopEncounter: ShopEncounterSession?

    /// True when no shop, mystery, or battle is already in progress.
    var canBeginTransientEncounter: Bool {
        activeShopEncounter == nil
            && activeMysteryEncounter == nil
            && battle.lifecyclePhase != .active
    }

    init(
        playerSave: PlayerSaveStore,
        battle: any BattleRuntime,
        options: OptionsStore,
        sfxPlayer: SFXPlayer
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.options = options
        self.sfxPlayer = sfxPlayer
    }

    @discardableResult
    func beginShopEncounter(
        origin: PlayEncounterOrigin
    ) -> ShopEncounterOpenResult {
        guard canBeginTransientEncounter else { return .unavailable }

        switch ShopEncounterSession.open(
            origin: origin,
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent
        ) {
        case let .opened(shopSession):
            activeShopEncounter = shopSession
            return .opened(shopSession)
        case .autoCompleted:
            return .autoCompleted
        case .unavailable:
            return .unavailable
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
        guard playerSave.persistBatch(logging: "Failed to purchase shop offer", { save in
            purchaseResult = ShopPurchaseApplier.purchase(
                offer: offer,
                visitToken: shopSession.visitToken,
                stageID: shopSession.stage.id,
                save: &save
            )
        }) else {
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

    func clearActiveShopEncounter() {
        activeShopEncounter = nil
    }

    /// Completes an active shop encounter only after persistence succeeds.
    @discardableResult
    public func finishActiveShopEncounter() -> Bool {
        guard let shopSession = activeShopEncounter else { return false }

        shopSession.clearLeaveFailure()
        guard playerSave.persistBatch(logging: "Failed to leave shop", { save in
            StageCompletion.completeEncounter(
                stage: shopSession.stage,
                labyrinthNodeID: shopSession.labyrinthNodeID,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                in: GameContent.chapters,
                save: &save
            )
        }) else {
            shopSession.markLeaveFailed("Couldn't save progress. Stay here and try Leave Shop again.")
            return false
        }
        clearActiveShopEncounter()
        return true
    }

    public func dismissActiveShopEncounterWithoutCompleting() {
        activeShopEncounter = nil
    }
}
