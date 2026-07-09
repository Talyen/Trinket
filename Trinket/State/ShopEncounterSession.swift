import Foundation
import Observation
import TrinketContent
import TrinketPersistence

@MainActor
@Observable
final class ShopEncounterSession: Identifiable {
    var id: String {
        stage.id
    }

    let stage: Stage
    let greeting: String
    let offers: [ShopOffer]
    /// Unique per open so inventory instance ids never collide across dismiss/re-open.
    let visitToken: String
    private(set) var purchasedOfferIDs: Set<String> = []
    private(set) var purchaseCount = 0
    private(set) var lastPurchasedItemName: String?
    private(set) var lastPurchaseError: String?
    private(set) var isPurchasing = false

    init(
        stage: Stage,
        offers: [ShopOffer],
        visitToken: String = UUID().uuidString,
        greeting: String = "Welcome, traveler. Take a look at what I've got."
    ) {
        self.stage = stage
        self.offers = offers
        self.visitToken = visitToken
        self.greeting = greeting
    }

    func isSoldOut(_ offerID: String) -> Bool {
        purchasedOfferIDs.contains(offerID)
    }

    func markPurchaseStarted() {
        isPurchasing = true
        lastPurchaseError = nil
    }

    func markPurchaseFinished(offerID: String, itemName: String) {
        isPurchasing = false
        purchasedOfferIDs.insert(offerID)
        purchaseCount += 1
        lastPurchasedItemName = itemName
        lastPurchaseError = nil
    }

    func markPurchaseFailed(message: String) {
        isPurchasing = false
        lastPurchaseError = message
    }
}
