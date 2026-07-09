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
    /// When set, Leave completes a Labyrinth node instead of a journey stage.
    let labyrinthNodeID: String?
    let greeting: String
    let offers: [ShopOffer]
    private(set) var purchaseCount = 0
    private(set) var lastPurchasedItemName: String?
    private(set) var isPurchasing = false

    init(
        stage: Stage,
        offers: [ShopOffer],
        greeting: String = "Welcome, traveler. Take a look at what I've got.",
        labyrinthNodeID: String? = nil
    ) {
        self.stage = stage
        self.offers = offers
        self.greeting = greeting
        self.labyrinthNodeID = labyrinthNodeID
    }

    convenience init(
        labyrinthNodeID: String,
        offers: [ShopOffer],
        greeting: String = "Welcome, traveler. Take a look at what I've got."
    ) {
        self.init(
            stage: LabyrinthEncounterSupport.syntheticStage(
                nodeID: labyrinthNodeID,
                encounter: .shop
            ),
            offers: offers,
            greeting: greeting,
            labyrinthNodeID: labyrinthNodeID
        )
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
