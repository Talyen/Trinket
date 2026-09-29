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
        let homesteadReward: HomesteadMysteryReward?
        let item: StoredInventoryItem

        init(_ offer: MysteryOffer) {
            choiceID = offer.choiceID
            bonus = offer.bonus
            homesteadReward = offer.homesteadReward
            item = StoredInventoryItem(offer.item)
        }

        /// Nil when the offer's item is homeless (unknown base): the option
        /// is dropped while surviving offers resolve. Invalid bonuses still
        /// throw so a tampered payload cannot mint rewards.
        func resolve() throws -> MysteryOffer? {
            guard bonus.amount >= 0 else { throw MysteryOfferError.invalidSnapshot }
            if case let .goldAndExperience(gold, experience, nominalGold, fullOverflowExperience) = bonus {
                guard gold >= 0, experience >= 0, nominalGold >= gold,
                      fullOverflowExperience >= experience else { throw MysteryOfferError.invalidSnapshot }
            }
            guard let item = item.resolved() else { return nil }
            if let reward = homesteadReward {
                guard reward.resource == .gold || reward.resource == .gems, reward.amount >= 0,
                      (0 ... 100).contains(reward.percent) else { throw MysteryOfferError.invalidSnapshot }
            }
            return MysteryOffer(choiceID: choiceID, item: item, bonus: bonus, homesteadReward: homesteadReward)
        }
    }
}

enum MysteryOfferError: Error {
    case invalidSnapshot
    case unavailableEncounter
}
