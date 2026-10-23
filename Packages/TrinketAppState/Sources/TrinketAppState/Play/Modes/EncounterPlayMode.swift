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
    func beginShopEncounter(origin: PlayEncounterOrigin) -> SaveActionAttempt<ShopEncounterOpenResult> {
        if let restriction = playerSave.encounterAccessRestriction(for: origin) {
            return SaveActionAttempt(.failed(restriction))
        }
        guard canBeginTransientEncounter else { return SaveActionAttempt(.unavailable) }
        isOpeningTransientEncounter = true
        defer { isOpeningTransientEncounter = false }

        let encounter = origin.identity(in: playerSave.currentSave)
        switch playerSave.prepareShop(encounter: encounter) {
        case let .committed(stock):
            guard canPublishTransientEncounter(encounter) else { return SaveActionAttempt(.unavailable) }
            guard !stock.offers.isEmpty else { return SaveActionAttempt(.autoCompleted) }
            let session = ShopEncounterSession(origin: origin, encounter: encounter, offers: stock.offers)
            activeShopEncounter = session
            guard owns(session) else {
                if activeShopEncounter === session {
                    activeShopEncounter = nil
                }
                return SaveActionAttempt(.unavailable)
            }
            return SaveActionAttempt(.opened(session))
        case .rejected:
            return SaveActionAttempt(.failed(StageMapMessage(
                title: "Shop Unavailable",
                message: "The shop could not be opened. Your progress is preserved.",
            )))
        case let .persistFailed(error):
            // Transient write failure: beginShopOrAutoComplete schedules a
            // silent retry; the session opens late via observation instead of
            // surfacing an error for a passing blip.
            return SaveActionAttempt(.unavailable, failure: error)
        }
    }

    @discardableResult
    public func purchaseShopOffer(session shopSession: ShopEncounterSession, offerID: String) -> ShopPurchaseOutcome {
        guard owns(shopSession) else { return .rejected }
        return playerSave
            .performSaveAction(key: SaveRetryKey.shopPurchase(offerID)) { [weak self] _ -> SaveActionAttempt<ShopPurchaseOutcome> in
                guard let self else { return SaveActionAttempt(.rejected) }
                guard owns(shopSession) else { return SaveActionAttempt(.rejected) }
                guard !shopSession.isPurchasing else { return SaveActionAttempt(.rejected) }
                shopSession.markPurchaseStarted()
                guard owns(shopSession) else {
                    shopSession.markPurchaseFinished()
                    return SaveActionAttempt(.rejected)
                }
                switch playerSave.purchaseShopOffer(offerID: offerID, encounter: shopSession.encounter) {
                case .committed:
                    shopSession.markPurchaseFinished()
                    guard owns(shopSession) else { return SaveActionAttempt(.committed) }
                    shopSession.publishPurchase(offerID: offerID)
                    sfxPlayer.play(SFXID.uiBuySell, volume: options.effectsVolume)
                    return SaveActionAttempt(.committed)
                case .rejected:
                    shopSession.markPurchaseFinished()
                    guard owns(shopSession) else { return SaveActionAttempt(.rejected) }
                    sfxPlayer.play(SFXID.uiDeny, volume: options.effectsVolume)
                    return SaveActionAttempt(.rejected)
                case let .persistFailed(error):
                    // The mutation rolled back and the store retries silently, so this
                    // attempt is accepted rather than failed; the board is already
                    // disabled while `isRetryingSaveAction`.
                    shopSession.markPurchaseFinished()
                    return SaveActionAttempt(.retrying, failure: error)
                }
            }
    }

    @discardableResult
    func beginShopOrAutoComplete(origin: PlayEncounterOrigin) -> StageMapMessage? {
        playerSave.performSaveAction(key: SaveRetryKey.shopOpen) { [weak self] _ -> SaveActionAttempt<StageMapMessage?> in
            guard let self else { return SaveActionAttempt(nil) }
            return beginShopEncounter(origin: origin).map { result in
                switch result {
                case .autoCompleted:
                    Self.emptyShopClosedMessage(identifier: origin.identity(in: playerSave.currentSave).stageID)
                case .opened, .unavailable:
                    nil
                case let .failed(message):
                    message
                }
            }
        }
    }

    @discardableResult
    public func finishShopEncounter(session shopSession: ShopEncounterSession) -> Bool {
        guard owns(shopSession) else { return false }
        return playerSave.performSaveAction(key: SaveRetryKey.shopLeave) { [weak self] _ in
            guard let self else { return SaveActionAttempt(false) }
            guard owns(shopSession) else { return SaveActionAttempt(false) }

            switch playerSave.finishShop(encounter: shopSession.encounter) {
            case .committed, .rejected:
                if owns(shopSession) {
                    activeShopEncounter = nil
                }
                return SaveActionAttempt(true)
            case let .persistFailed(error):
                return SaveActionAttempt(false, failure: error)
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
