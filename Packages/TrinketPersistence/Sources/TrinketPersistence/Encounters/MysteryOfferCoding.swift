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
        return try offers.compactMap { try $0.resolve() }
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

        /// Nil when the offer's item is homeless (unknown base): the option
        /// is dropped while surviving offers resolve. Invalid bonuses still
        /// throw so a tampered payload cannot mint rewards.
        func resolve() throws -> MysteryOffer? {
            guard bonus.amount >= 0 else { throw MysteryOfferError.invalidSnapshot }
            guard let item = item.resolved() else { return nil }
            return MysteryOffer(choiceID: choiceID, item: item, bonus: bonus)
        }
    }
}

enum MysteryOfferError: Error {
    case invalidSnapshot
    case unavailableEncounter
}
