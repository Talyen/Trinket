import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
@Observable
public final class EncounterPlayMode {
    public let playerSave: PlayerSaveStore
    public let battle: any BattleRuntime
    let options: OptionsStore
    let sfxPlayer: SFXPlayer

    public var activeMysteryEncounter: MysteryEncounterSession?
    public var activeShopEncounter: ShopEncounterSession?

    var canBeginTransientEncounter: Bool {
        activeShopEncounter == nil
            && activeMysteryEncounter == nil
            && battle.lifecyclePhase != .active
    }

    init(
        playerSave: PlayerSaveStore,
        battle: any BattleRuntime,
        options: OptionsStore,
        sfxPlayer: SFXPlayer,
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.options = options
        self.sfxPlayer = sfxPlayer
    }

    @discardableResult
    func beginShopEncounter(
        origin: PlayEncounterOrigin,
    ) -> ShopEncounterOpenResult {
        guard playerSave.encounterAccessRestriction(for: origin) == nil,
              canBeginTransientEncounter else { return .unavailable }

        let encounter = origin.identity(in: playerSave.currentSave)
        switch playerSave.persistTransaction(logging: "Failed to prepare shop stock", { save in
            ShopStockPersistence.prepare(encounter: encounter, save: &save)
        }) {
        case let .committed(stock):
            guard !stock.offers.isEmpty else { return .autoCompleted }
            let session = ShopEncounterSession(origin: origin, encounter: encounter, offers: stock.offers)
            activeShopEncounter = session
            return .opened(session)
        case .rejected:
            return .failed(StageMapMessage(title: "Shop Unavailable", message: "The shop could not be opened. Your progress is preserved."))
        case .persistFailed:
            return .failed(StageMapMessage(title: "Couldn't Save Shop", message: "The shop was not saved. Try opening it again."))
        }
    }

    @discardableResult
    public func purchaseActiveShopOffer(offerID: String) -> Bool {
        guard let shopSession = activeShopEncounter else { return false }
        guard !shopSession.isPurchasing else { return false }
        shopSession.markPurchaseStarted()
        switch playerSave.persistTransaction(logging: "Failed to purchase shop offer", { save in
            ShopPurchaseApplier.purchase(offerID: offerID, encounter: shopSession.encounter, save: &save)
        }) {
        case .committed:
            shopSession.markPurchaseFinished()
            sfxPlayer.play(SFXID.uiBuySell, volume: options.effectsVolume)
            return true
        case let .rejected(reason):
            shopSession.markPurchaseFailed(message: reason.message)
            sfxPlayer.play(SFXID.uiDeny, volume: options.effectsVolume)
            return false
        case .persistFailed:
            shopSession.markPurchaseFailed(message: "Purchase failed. Try again.")
            return false
        }
    }

    @discardableResult
    func beginShopOrAutoComplete(
        origin: PlayEncounterOrigin,
        identifier: String,
        onAutoComplete: () -> StageMapMessage?,
    ) -> StageMapMessage? {
        switch beginShopEncounter(origin: origin) {
        case .autoCompleted:
            if let failure = onAutoComplete() {
                return failure
            }
            return emptyShopClosedMessage(identifier: identifier)
        case .opened, .unavailable:
            return nil
        case let .failed(message):
            return message
        }
    }

    func clearActiveShopEncounter() {
        activeShopEncounter = nil
    }

    @discardableResult
    public func finishActiveShopEncounter() -> Bool {
        guard let shopSession = activeShopEncounter else { return false }

        shopSession.clearPersistFailure()
        guard playerSave.persistBatch(logging: "Failed to leave shop", { save in
            StageCompletion.completeEncounter(
                stage: shopSession.stage,
                labyrinthNodeID: shopSession.labyrinthNodeID,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                in: GameContent.chapters,
                save: &save,
            )
        }) else {
            shopSession.markPersistFailed("Couldn't save progress. Stay here and try Leave Shop again.")
            return false
        }
        clearActiveShopEncounter()
        return true
    }

    static let emptyShopClosedMessage = StageMapMessage(
        title: "Shop Closed",
        message: "The merchant has nothing left to sell. You continue on.",
    )

    func emptyShopClosedMessage(identifier: String) -> StageMapMessage {
        appStateLogger.error(
            "Shop \(identifier, privacy: .public) produced no offers; completing encounter.",
        )
        return Self.emptyShopClosedMessage
    }
}
