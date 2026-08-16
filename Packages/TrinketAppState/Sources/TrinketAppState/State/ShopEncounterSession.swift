import Foundation
import Observation
import TrinketContent
import TrinketCore

public enum ShopEncounterOpenResult {
    case opened(ShopEncounterSession)
    /// Shelf empty — caller should auto-complete the stage/node.
    case autoCompleted
    case unavailable
}

@MainActor
@Observable
public final class ShopEncounterSession: Identifiable {
    // swiftformat:disable:next modifierOrder -- SwiftLint requires isolation before access.
    nonisolated public var id: String {
        stage.id
    }

    public let stage: Stage
    public let origin: PlayEncounterOrigin
    /// When set, Leave completes a Labyrinth node instead of a journey stage.
    public var labyrinthNodeID: String? {
        origin.labyrinthNodeID
    }

    public let greeting: String
    public let offers: [ShopOffer]
    /// Unique per open so inventory instance ids never collide across dismiss/re-open.
    public let visitToken: String
    public private(set) var purchasedOfferIDs: Set<String> = []
    public private(set) var purchaseCount = 0
    public private(set) var lastPurchaseError: String?
    public private(set) var leaveFailureMessage: String?
    public private(set) var isPurchasing = false

    public init(
        origin: PlayEncounterOrigin,
        offers: [ShopOffer],
        visitToken: String = UUID().uuidString,
        greeting: String = "Welcome, traveler. Take a look at what I've got."
    ) {
        self.origin = origin
        stage = origin.resolvedStage(labyrinthEncounter: .shop)
        self.offers = offers
        self.visitToken = visitToken
        self.greeting = greeting
    }

    /// Builds a shop session for a journey stage or Labyrinth shop node.
    static func open(
        origin: PlayEncounterOrigin,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String>,
        astralChanceBonusPercent: Int
    ) -> ShopEncounterOpenResult {
        if case let .journey(stage) = origin {
            guard case .shop = stage.encounter else { return .unavailable }
        }
        let resolvedStage = origin.resolvedStage(labyrinthEncounter: .shop)

        var randomNumberGenerator = SeededRandomNumberGenerator(
            seed: ShopOfferGenerator.seed(worldSeed: worldSeed, forStageID: resolvedStage.id)
        )
        let offers = ShopOfferGenerator.generateOffers(
            stageID: resolvedStage.id,
            ownedTrinketIDs: ownedTrinketIDs,
            astralChanceBonusPercent: astralChanceBonusPercent,
            using: &randomNumberGenerator
        )
        guard !offers.isEmpty else {
            return .autoCompleted
        }
        return .opened(ShopEncounterSession(
            origin: origin,
            offers: offers
        ))
    }

    public func isSoldOut(_ offerID: String) -> Bool {
        purchasedOfferIDs.contains(offerID)
    }

    func markPurchaseStarted() {
        isPurchasing = true
        lastPurchaseError = nil
    }

    func markPurchaseFinished(offerID: String) {
        isPurchasing = false
        purchasedOfferIDs.insert(offerID)
        purchaseCount += 1
        lastPurchaseError = nil
    }

    func markPurchaseFailed(message: String) {
        isPurchasing = false
        lastPurchaseError = message
    }

    func markLeaveFailed(_ message: String) {
        leaveFailureMessage = message
    }

    func clearLeaveFailure() {
        leaveFailureMessage = nil
    }
}
