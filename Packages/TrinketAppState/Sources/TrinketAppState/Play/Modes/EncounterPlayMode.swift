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
    @ObservationIgnored var isOpeningTransientEncounter = false

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
        !isOpeningTransientEncounter && activeEncounter == nil && battle.lifecyclePhase != .active
    }

    func canPublishTransientEncounter(_ encounter: EncounterIdentity) -> Bool {
        isCurrent(encounter) && activeEncounter == nil && battle.lifecyclePhase != .active
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
        isOpeningTransientEncounter = true
        defer { isOpeningTransientEncounter = false }

        let encounter = origin.identity(in: playerSave.currentSave)
        switch playerSave.prepareShop(encounter: encounter) {
        case let .committed(stock):
            guard canPublishTransientEncounter(encounter) else { return .unavailable }
            guard !stock.offers.isEmpty else { return .autoCompleted }
            let session = ShopEncounterSession(origin: origin, encounter: encounter, offers: stock.offers)
            activeShopEncounter = session
            guard owns(session) else {
                if activeShopEncounter === session {
                    activeShopEncounter = nil
                }
                return .unavailable
            }
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
    public func purchaseShopOffer(session shopSession: ShopEncounterSession, offerID: String) -> ShopPurchaseOutcome {
        guard owns(shopSession) else { return .rejected }
        return playerSave.performSaveAction(key: SaveRetryKey.shopPurchase(offerID)) { [weak self] _ -> ShopPurchaseOutcome in
            guard let self else { return .rejected }
            guard owns(shopSession) else { return .rejected }
            guard !shopSession.isPurchasing else { return .rejected }
            shopSession.markPurchaseStarted()
            guard owns(shopSession) else {
                shopSession.markPurchaseFinished()
                return .rejected
            }
            switch playerSave.purchaseShopOffer(offerID: offerID, encounter: shopSession.encounter) {
            case .committed:
                shopSession.markPurchaseFinished()
                guard owns(shopSession) else { return .committed }
                shopSession.publishPurchase(offerID: offerID)
                sfxPlayer.play(SFXID.uiBuySell, volume: options.effectsVolume)
                return .committed
            case .rejected:
                shopSession.markPurchaseFinished()
                guard owns(shopSession) else { return .rejected }
                sfxPlayer.play(SFXID.uiDeny, volume: options.effectsVolume)
                return .rejected
            case .persistFailed:
                // The mutation rolled back and the store retries silently, so this
                // attempt is accepted rather than failed; the board is already
                // disabled while `isRetryingSaveAction`.
                shopSession.markPurchaseFinished()
                return .retrying
            }
        }
    }

    @discardableResult
    func beginShopOrAutoComplete(origin: PlayEncounterOrigin) -> StageMapMessage? {
        playerSave.performSaveAction(key: SaveRetryKey.shopOpen) { [weak self] _ -> StageMapMessage? in
            guard let self else { return nil }
            switch beginShopEncounter(origin: origin) {
            case .autoCompleted:
                return Self.emptyShopClosedMessage(identifier: origin.identity(in: playerSave.currentSave).stageID)
            case .opened:
                return nil
            case .unavailable:
                return nil
            case let .failed(message):
                return message
            }
        }
    }

    @discardableResult
    public func finishShopEncounter(session shopSession: ShopEncounterSession) -> Bool {
        guard owns(shopSession) else { return false }
        return playerSave.performSaveAction(key: SaveRetryKey.shopLeave) { [weak self] _ in
            guard let self else { return false }
            guard owns(shopSession) else { return false }

            switch playerSave.finishShop(encounter: shopSession.encounter) {
            case .committed, .rejected:
                if owns(shopSession) {
                    activeShopEncounter = nil
                }
                return true
            case .persistFailed:
                return false
            }
        }
    }

    /// A screen's commands belong to its exact session and save lifetime. Matching
    /// encounter/offer IDs alone cannot authorize callbacks from a retiring cover.
    func owns(_ session: ShopEncounterSession) -> Bool {
        activeShopEncounter === session && isCurrent(session.encounter)
    }

    func owns(_ session: MysteryEncounterSession) -> Bool {
        activeMysteryEncounter === session && isCurrent(session.encounter)
    }

    private func isCurrent(_ encounter: EncounterIdentity) -> Bool {
        encounter.isCurrent(in: playerSave.currentSave)
    }

    static func emptyShopClosedMessage(identifier: String) -> StageMapMessage {
        appStateLogger.error(
            "Shop \(identifier, privacy: .public) produced no offers; completing encounter.",
        )
        return StageMapMessage(
            title: "Shop Closed",
            message: "The merchant has nothing left to sell\nYou continue on",
        )
    }
}
