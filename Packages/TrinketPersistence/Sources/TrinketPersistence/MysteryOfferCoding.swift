import Foundation
import TrinketContent
import TrinketCore

struct MysteryOfferSnapshot: Codable {
    let version: Int
    let eventID: String
    let offers: [StoredOffer]

    init(eventID: String, offers: [MysteryOffer]) {
        version = 1
        self.eventID = eventID
        self.offers = offers.map(StoredOffer.init)
    }

    func resolvedOffers() throws -> [MysteryOffer] {
        guard version == 1 else { throw MysteryOfferError.invalidSnapshot }
        return try offers.map { try $0.resolve() }
    }

    struct StoredOffer: Codable {
        let choiceID: String
        let bonus: MysteryRewardBonus
        let itemID: String
        let templateID: String
        let baseTypeID: String
        let rarity: Rarity
        let displayName: String
        let isCorrupted: Bool
        let affixes: [StoredAffix]
        let powers: [ItemAffixPower]?

        init(_ offer: MysteryOffer) {
            choiceID = offer.choiceID
            bonus = offer.bonus
            let item = offer.item
            itemID = item.id
            templateID = item.templateID
            baseTypeID = item.baseType.id
            rarity = item.rarity
            displayName = item.displayName
            isCorrupted = item.isCorrupted
            affixes = item.affixes.map(StoredAffix.init)
            powers = item.affixPowers
        }

        func resolve() throws -> MysteryOffer {
            guard let base = GameContent.itemBaseType(matching: baseTypeID), bonus.amount >= 0 else {
                throw MysteryOfferError.invalidSnapshot
            }
            return MysteryOffer(
                choiceID: choiceID,
                item: InventoryItem(
                    id: itemID,
                    templateID: templateID,
                    baseType: base,
                    rarity: rarity,
                    displayName: displayName,
                    affixes: affixes.map(\.resolved),
                    isCorrupted: isCorrupted,
                    affixPowers: powers,
                ),
                bonus: bonus,
            )
        }
    }

    struct StoredAffix: Codable {
        let id: String
        let title: String
        let description: String
        let keywords: Set<Keyword>
        let isCorrupted: Bool

        init(_ affix: ItemAffix) {
            id = affix.id
            title = affix.title
            description = affix.description
            keywords = affix.keywords
            isCorrupted = affix.isCorrupted
        }

        var resolved: ItemAffix {
            ItemAffix(id: id, title: title, description: description, keywords: keywords, isCorrupted: isCorrupted)
        }
    }
}

enum MysteryOfferError: Error {
    case invalidSnapshot
    case unavailableEncounter
}
