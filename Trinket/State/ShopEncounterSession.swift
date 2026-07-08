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
    private(set) var purchaseCount = 0
    private(set) var lastPurchasedItemName: String?
    private(set) var isPurchasing = false

    init(
        stage: Stage,
        offers: [ShopOffer],
        greeting: String = "Welcome, traveler. Take a look at what I've got."
    ) {
        self.stage = stage
        self.offers = offers
        self.greeting = greeting
    }

    func markPurchaseStarted() {
        isPurchasing = true
    }

    func markPurchaseFinished(itemName: String?) {
        isPurchasing = false
        guard let itemName else { return }
        purchaseCount += 1
        lastPurchasedItemName = itemName
    }

    func markPurchaseFailed() {
        isPurchasing = false
    }
}
