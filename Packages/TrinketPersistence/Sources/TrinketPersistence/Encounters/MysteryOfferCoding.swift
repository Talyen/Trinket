import Foundation
import TrinketContent
import TrinketCore

struct MysteryOfferSnapshot: Codable {
    let version: Int
    let eventID: String
    let offers: [StoredOffer]

    init(eventID: String, offers: [MysteryOffer]) {
        version = 2
        self.eventID = eventID
        self.offers = offers.map(StoredOffer.init)
    }

    func resolvedOffers() throws -> [MysteryOffer] {
        guard version == 2 else { throw MysteryOfferError.invalidSnapshot }
        return try offers.map { try $0.resolve() }
    }

    struct StoredOffer: Codable {
        let choiceID: String
        let bonus: MysteryRewardBonus
        let item: StoredInventoryItem

        init(_ offer: MysteryOffer) {
            choiceID = offer.choiceID
            bonus = offer.bonus
            item = StoredInventoryItem(offer.item)
        }

        func resolve() throws -> MysteryOffer {
            guard bonus.amount >= 0 else { throw MysteryOfferError.invalidSnapshot }
            return try MysteryOffer(choiceID: choiceID, item: item.resolve(), bonus: bonus)
        }
    }
}

enum MysteryOfferError: Error {
    case invalidSnapshot
    case unavailableEncounter
}
