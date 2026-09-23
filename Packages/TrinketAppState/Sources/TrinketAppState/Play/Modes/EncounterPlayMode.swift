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
            // Transient write failure: beginShopOrAutoComplete schedules a
            // silent retry; the session opens late via observation instead of
            // surfacing an error for a passing blip.
            return .unavailable
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
            shopSession.markPurchaseFinished()
            playerSave.retrySaveAction(key: SaveRetryKey.shopPurchase(offerID)) { [weak self] in
                guard let self, activeShopEncounter === shopSession else { return }
                _ = purchaseActiveShopOffer(offerID: offerID)
            }
            return false
        }
    }

    @discardableResult
    func beginShopOrAutoComplete(
        origin: PlayEncounterOrigin,
        identifier: String,
        onAutoComplete: @escaping () -> StageMapMessage?,
    ) -> StageMapMessage? {
        switch beginShopEncounter(origin: origin) {
        case .autoCompleted:
            if let failure = onAutoComplete() {
                return failure
            }
            return Self.emptyShopClosedMessage(identifier: identifier)
        case .opened:
            return nil
        case .unavailable:
            if playerSave.lastPersistenceError == .writeFailed {
                playerSave.retrySaveAction(key: SaveRetryKey.shopOpen) { [weak self] in
                    _ = self?.beginShopOrAutoComplete(
                        origin: origin,
                        identifier: identifier,
                        onAutoComplete: onAutoComplete,
                    )
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

        guard playerSave.persistBatch(logging: "Failed to leave shop", { save in
            if case let .voyage(runID, nodeID) = shopSession.encounter.location {
                guard shopSession.encounter.isPlayable(in: save) else { return }
                _ = VoyageCompletion.completeNode(runID: runID, nodeID: nodeID, save: &save)
                return
            }
            StageCompletion.completeEncounter(
                stage: shopSession.stage,
                labyrinthNodeID: shopSession.labyrinthNodeID,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                in: GameContent.chapters,
                save: &save,
            )
        }) else {
            playerSave.retrySaveAction(key: SaveRetryKey.shopLeave) { [weak self] in
                guard let self, activeShopEncounter === shopSession else { return }
                _ = finishActiveShopEncounter()
            }
            return false
        }
        clearActiveShopEncounter()
        return true
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
