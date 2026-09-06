import Foundation
import TrinketCore

public enum MysteryEffect: Hashable, Sendable {
    case gainGold(Int)
    case gainMaterial(HomesteadResource)
    case gainExperience
    case gainItem(MysteryItemPool)
    case unlockCombatant(String)
    case corruptItem
    case leave
}

public struct MysteryChoice: Hashable, Sendable {
    public let id: String
    public let label: String
    public let effects: [MysteryEffect]

    public init(id: String, label: String, effects: [MysteryEffect]) {
        self.id = id
        self.label = label
        self.effects = effects
    }

    public var itemPool: MysteryItemPool? {
        effects.compactMap { effect in
            if case let .gainItem(pool) = effect {
                return pool
            }
            return nil
        }.first
    }
}

public struct MysteryEvent: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let narrative: String
    public let artID: String?
    public let unlockCombatantID: String?
    public let choices: [MysteryChoice]

    public var isRecruit: Bool {
        unlockCombatantID != nil
    }

    public func narrative(for offers: [MysteryOffer]) -> String {
        choices.enumerated().reduce(narrative) { text, entry in
            let item = offers.first { $0.choiceID == entry.element.id }?.item
            let base = item?.baseType
                ?? entry.element.itemPool.flatMap { GameContent.itemBaseType(matching: $0.baseTypeID) }
            let name = item?.displayName ?? base?.name ?? "treasure"
            let phrase: String
            if item?.isTrinket == true || item?.rarity == .unique {
                phrase = name
            } else if base?.slot == .armor {
                phrase = "a suit of \(name)"
            } else {
                let article = "aeiou".contains(name.prefix(1).lowercased()) ? "an" : "a"
                phrase = "\(article) \(name)"
            }
            let marker = "{\(entry.offset == 0 ? "A" : "B")}"
            let sentenceName = phrase.prefix(1).uppercased() + phrase.dropFirst()
            var result = text.replacingOccurrences(of: ". \(marker)", with: ". \(sentenceName)")
            if result.hasPrefix(marker) {
                result = sentenceName + result.dropFirst(marker.count)
            }
            return result.replacingOccurrences(of: marker, with: phrase)
        }
    }

    public init(
        id: String,
        title: String,
        narrative: String,
        artID: String?,
        unlockCombatantID: String? = nil,
        choices: [MysteryChoice],
    ) {
        self.id = id
        self.title = title
        self.narrative = narrative
        self.artID = artID
        self.unlockCombatantID = unlockCombatantID
        self.choices = choices
    }
}

public enum MysteryItemRarity {
    public static func roll(
        astralChanceBonusPercent: Int = 0,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemDropTier {
        ItemRarityRoll.roll(
            bossContent: false,
            astralChanceBonusPercent: astralChanceBonusPercent,
            allowsUnique: true,
            using: &randomNumberGenerator,
        )
    }
}
