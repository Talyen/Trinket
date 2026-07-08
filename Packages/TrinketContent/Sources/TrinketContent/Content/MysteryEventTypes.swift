import Foundation
import TrinketCore

public enum MysteryEffect: Hashable, Sendable {
    case gainGold(Int)
    case gainMaterial(HomesteadResource, Int)
    case gainExperience(Int)
    /// Procedural item: rarity is rolled 80% basic / 20% astral at grant time.
    case gainGeneratedItem(baseTypeID: String, guaranteedAffixIDs: [String] = [])
    case gainRandomItem
    case chooseItem
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
}

public struct MysteryEvent: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let narrative: String
    public let artID: String?
    public let choices: [MysteryChoice]

    public init(id: String, title: String, narrative: String, artID: String?, choices: [MysteryChoice]) {
        self.id = id
        self.title = title
        self.narrative = narrative
        self.artID = artID
        self.choices = choices
    }
}

public enum MysteryItemRarity {
    /// 80% basic, 20% astral.
    public static func roll<RNG: RandomNumberGenerator>(using randomNumberGenerator: inout RNG) -> Rarity {
        Int.random(in: 1 ... 100, using: &randomNumberGenerator) <= 80 ? .basic : .astral
    }
}
