import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts

enum ShopEncounterOpenResult {
    case opened(ShopEncounterSession)
    case autoCompleted
    case unavailable
    case failed(StageMapMessage)
}

@MainActor
@Observable
public final class ShopEncounterSession: Identifiable {
    nonisolated public var id: String {
        stage.id
    }

    public let stage: Stage
    public let origin: PlayEncounterOrigin
    public let encounter: EncounterIdentity
    public var labyrinthNodeID: String? {
        origin.labyrinthNodeID
    }

    public let greeting: String
    public let offers: [ShopOffer]
    public private(set) var lastPurchaseError: String?
    public private(set) var persistFailureMessage: String?
    public private(set) var isPurchasing = false

    public init(
        origin: PlayEncounterOrigin,
        encounter: EncounterIdentity,
        offers: [ShopOffer],
        greeting: String = "Welcome, traveler. Take a look at what I've got.",
    ) {
        self.origin = origin
        self.encounter = encounter
        stage = origin.resolvedStage(labyrinthEncounter: .shop)
        self.offers = offers
        self.greeting = greeting
    }

    func markPurchaseStarted() {
        isPurchasing = true
        lastPurchaseError = nil
    }

    func markPurchaseFinished() {
        isPurchasing = false
        lastPurchaseError = nil
    }

    func markPurchaseFailed(message: String) {
        isPurchasing = false
        lastPurchaseError = message
    }

    func markPersistFailed(_ message: String) {
        persistFailureMessage = message
    }

    func clearPersistFailure() {
        persistFailureMessage = nil
    }
}
