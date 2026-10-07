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
    private enum ActiveEncounter {
        case mystery(MysteryEncounterSession)
        case shop(ShopEncounterSession)
    }

    public let playerSave: PlayerSaveStore
    public let battle: any BattleRuntime
    let options: OptionsStore
    let sfxPlayer: SFXPlayer
    var mysteryRandom: any RandomNumberGenerator = SystemRandomNumberGenerator()
    var currentDate: () -> Date = { Date() }

    private var activeEncounter: ActiveEncounter?

    public var activeMysteryEncounter: MysteryEncounterSession? {
        get {
            guard case let .mystery(session) = activeEncounter else { return nil }
            return session
        }
        set {
            if let newValue {
                activeEncounter = .mystery(newValue)
            } else if case .mystery = activeEncounter {
                activeEncounter = nil
            }
        }
    }

    public var activeShopEncounter: ShopEncounterSession? {
        get {
            guard case let .shop(session) = activeEncounter else { return nil }
            return session
        }
        set {
            if let newValue {
                activeEncounter = .shop(newValue)
            } else if case .shop = activeEncounter {
                activeEncounter = nil
            }
        }
    }

    var canBeginTransientEncounter: Bool {
        activeEncounter == nil && battle.lifecyclePhase != .active
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
    func beginShopEncounter(origin: PlayEncounterOrigin) -> ShopEncounterOpenResult {
        if let restriction = playerSave.encounterAccessRestriction(for: origin) {
            return .failed(restriction)
        }
        guard canBeginTransientEncounter else { return .unavailable }

        let encounter = origin.identity(in: playerSave.currentSave)
        switch playerSave.prepareShop(encounter: encounter) {
        case let .committed(stock):
            guard !stock.offers.isEmpty else { return .autoCompleted }
            let session = ShopEncounterSession(origin: origin, encounter: encounter, offers: stock.offers)
            activeShopEncounter = session
            return .opened(session)
        case .rejected:
            return .failed(StageMapMessage(title: "Shop Unavailable", message: "The shop could not be opened. Your progress is preserved."))
        case .persistFailed:
            // Transient write failure: beginShopOrAutoComplete schedules a
            // silent retry; the session opens late via observation instead of
            // surfacing an error for a passing blip.
            return .unavailable
        }
    }

    @discardableResult
    public func purchaseActiveShopOffer(offerID: String) -> ShopPurchaseOutcome {
        guard let shopSession = activeShopEncounter else { return .rejected }
        guard !shopSession.isPurchasing else { return .rejected }
        shopSession.markPurchaseStarted()
        switch playerSave.purchaseShopOffer(offerID: offerID, encounter: shopSession.encounter) {
        case .committed:
            shopSession.markPurchaseFinished()
            sfxPlayer.play(SFXID.uiBuySell, volume: options.effectsVolume)
            return .committed
        case .rejected:
            shopSession.markPurchaseFinished()
            sfxPlayer.play(SFXID.uiDeny, volume: options.effectsVolume)
            return .rejected
        case .persistFailed:
            // The mutation rolled back and the store retries silently, so this
            // attempt is accepted rather than failed; the board is already
            // disabled while `isRetryingSaveAction`.
            shopSession.markPurchaseFinished()
            playerSave.retrySaveAction(key: SaveRetryKey.shopPurchase(offerID)) { [weak self] in
                guard let self, activeShopEncounter === shopSession else { return }
                _ = purchaseActiveShopOffer(offerID: offerID)
            }
            return .retrying
        }
    }

    @discardableResult
    func beginShopOrAutoComplete(origin: PlayEncounterOrigin) -> StageMapMessage? {
        switch beginShopEncounter(origin: origin) {
        case .autoCompleted:
            return Self.emptyShopClosedMessage(identifier: origin.identity(in: playerSave.currentSave).stageID)
        case .opened:
            return nil
        case .unavailable:
            if playerSave.lastPersistenceError == .writeFailed {
                playerSave.retrySaveAction(key: SaveRetryKey.shopOpen) { [weak self] in
                    _ = self?.beginShopOrAutoComplete(origin: origin)
                }
            }
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

        switch playerSave.finishShop(encounter: shopSession.encounter) {
        case .committed, .rejected:
            clearActiveShopEncounter()
            return true
        case .persistFailed:
            playerSave.retrySaveAction(key: SaveRetryKey.shopLeave) { [weak self] in
                guard let self, activeShopEncounter === shopSession else { return }
                _ = finishActiveShopEncounter()
            }
            return false
        }
    }

    static func emptyShopClosedMessage(identifier: String) -> StageMapMessage {
        appStateLogger.error(
            "Shop \(identifier, privacy: .public) produced no offers; completing encounter.",
        )
        return StageMapMessage(
            title: "Shop Closed",
            message: "The merchant has nothing left to sell. You continue on.",
        )
    }
}
