import Foundation
import TrinketCore

public struct MysteryItemPool: Hashable, Sendable {
    public let baseTypeID: String
    public let trinketIDs: Set<String>
    public let uniqueIDs: Set<String>
    public let guaranteedAffixIDs: [String]

    public init(
        baseTypeID: String,
        trinketIDs: Set<String> = [],
        uniqueIDs: Set<String> = [],
        guaranteedAffixIDs: [String] = [],
    ) {
        self.baseTypeID = baseTypeID
        self.trinketIDs = trinketIDs
        self.uniqueIDs = uniqueIDs
        self.guaranteedAffixIDs = guaranteedAffixIDs
    }
}

public enum MysteryRewardBonus: Codable, Hashable, Sendable {
    case gold(Int)
    case material(HomesteadResource, Int)
    case experience(Int)

    public var amount: Int {
        switch self {
        case let .gold(amount), let .material(_, amount), let .experience(amount): amount
        }
    }
}

public struct MysteryOffer: Hashable, Sendable {
    public let choiceID: String
    public let item: InventoryItem
    public let bonus: MysteryRewardBonus

    public init(choiceID: String, item: InventoryItem, bonus: MysteryRewardBonus) {
        self.choiceID = choiceID
        self.item = item
        self.bonus = bonus
    }
}
